"""Fixed honest-identity answers (AGENTS.md / PRD §3.1).

When the peer asks whether they are talking to the human or the twin, the
twin must answer as a twin with a stable phrase — not invent wording via LLM.
"""
from __future__ import annotations

import re
from dataclasses import dataclass

# Fixed product copy — tune only after PoC #3; do not invent alternate defaults.
IDENTITY_REPLY = (
    "지금은 분신이 답하고 있어. 본인이랑 바로 이야기하고 싶으면 그렇게 말해줘."
)

# Incoming peer questions that should trigger the fixed identity reply.
_IDENTITY_QUESTION = re.compile(
    r"("
    r"본인\s*(이야|인가요|이니|임\??|맞아|맞음)"
    r"|분신\s*(이야|인가요|이니|임\??|맞아|맞음)"
    r"|지금\s*(본인|분신)"
    r"|진짜\s*(야|임|인가요)"
    r"|너\s*(사람|본인|분신)"
    r")",
    re.IGNORECASE,
)


@dataclass
class IdentityHit:
    matched: bool
    reply: str = ""


def check_identity_question(text: str) -> IdentityHit:
    if not text or not text.strip():
        return IdentityHit(False)
    if _IDENTITY_QUESTION.search(text.strip()):
        return IdentityHit(True, IDENTITY_REPLY)
    return IdentityHit(False)
