from typing import List, Optional

from fastapi import FastAPI
from pydantic import BaseModel, model_validator

from .escalation_filter import check as check_escalation
from .generation import draft_reply, last_incoming_text, load_dotenv_if_present
from .retrieve_style import retrieve as retrieve_style_examples

app = FastAPI(title="분신 AI service")


@app.on_event("startup")
def startup():
    load_dotenv_if_present()


@app.get("/health")
def health():
    return {"status": "ok"}


class DraftRequest(BaseModel):
    context_lines: List[str]
    style_examples: Optional[List[str]] = None
    history: Optional[List[str]] = None
    k: int = 6
    model: str = "gemini-2.5-flash"

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

    status, text = draft_reply(style_examples, req.context_lines, model=req.model)
    return DraftResponse(status=status, text=text)
