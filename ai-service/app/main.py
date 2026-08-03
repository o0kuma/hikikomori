from contextlib import asynccontextmanager
from typing import List, Optional

from fastapi import FastAPI
from pydantic import BaseModel, model_validator

from .escalation_filter import check as check_escalation
from .generation import draft_reply, last_incoming_text, load_dotenv_if_present
from .retrieve_style import retrieve as retrieve_style_examples
from .summarize import summarize_messages


@asynccontextmanager
async def lifespan(app: FastAPI):
    load_dotenv_if_present()
    yield


app = FastAPI(title="와카뷰 AI service", lifespan=lifespan)


@app.get("/health")
def health():
    return {"status": "ok"}


class DraftRequest(BaseModel):
    context_lines: List[str]
    style_examples: Optional[List[str]] = None
    history: Optional[List[str]] = None
    k: int = 6
    model: str = "gemini-2.5-flash"
    relationship_tier: Optional[str] = None
    relationship_note: Optional[str] = None

    @model_validator(mode="after")
    def check_exactly_one_style_source(self):
        if bool(self.style_examples) == bool(self.history):
            raise ValueError("provide exactly one of style_examples or history")
        return self


class DraftResponse(BaseModel):
    status: str
    text: str


class EscalationCheckRequest(BaseModel):
    text: str


class EscalationCheckResponse(BaseModel):
    escalate: bool
    reason: str = ""


@app.post("/escalate/check", response_model=EscalationCheckResponse)
def escalate_check(req: EscalationCheckRequest):
    """Standalone hard gate, decoupled from draft generation (AGENTS.md
    absolute safety invariants). core-backend calls this directly before
    persisting any twin-authored (auto-sent) message, so the gate applies
    even to sends that never went through /draft."""
    result = check_escalation(req.text)
    return EscalationCheckResponse(escalate=result.escalate, reason=result.reason)


@app.post("/draft", response_model=DraftResponse)
def draft(req: DraftRequest):
    if req.style_examples is not None:
        style_examples = req.style_examples
    else:
        style_examples = retrieve_style_examples(
            req.history, last_incoming_text(req.context_lines), k=req.k
        )

    status, text = draft_reply(
        style_examples,
        req.context_lines,
        model=req.model,
        relationship_tier=req.relationship_tier,
        relationship_note=req.relationship_note,
    )
    return DraftResponse(status=status, text=text)


class SummarizeRequest(BaseModel):
    my_display_name: str
    context_lines: List[str]
    model: str = "gemini-2.5-flash"


class SummarizeResponse(BaseModel):
    status: str
    summary: str


@app.post("/summarize", response_model=SummarizeResponse)
def summarize(req: SummarizeRequest):
    """단톡 따라잡기 (roadmap.md §2.7-A) -- read-only catch-up summary, no
    escalation/identity gating since nothing generated here is ever sent."""
    status, text = summarize_messages(req.my_display_name, req.context_lines, model=req.model)
    return SummarizeResponse(status=status, summary=text)
