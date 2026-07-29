# Project Instructions — hikikomori / 분신 (가칭)

This repository is currently a **planning-docs repo** for an AI-twin messenger
("나를 대신해 남과 대화하는 AI 분신"). There is no application code yet.

Canonical docs live under `docs/`. Prefer linking to them over copying content
into prompts or new files.

## Document authority

When documents disagree, follow this order:

1. [`docs/decision-log.md`](docs/decision-log.md) — working assumptions for Q1~Q7
2. [`docs/vision.md`](docs/vision.md) / [`docs/PRD.md`](docs/PRD.md) / [`docs/tech-design.md`](docs/tech-design.md)
3. [`docs/roadmap.md`](docs/roadmap.md) / [`docs/risk-log.md`](docs/risk-log.md)
4. [`docs/PLANNING.md`](docs/PLANNING.md) — process guide
5. [`docs/idea-meeting-2026-06-29.html`](docs/idea-meeting-2026-06-29.html) — historical meeting source only

Notes:

- Q1~Q7 in `decision-log.md` are **제안 (tentative)**, not final meeting
  decisions. Do not silently reverse them. If a change is required, update
  `decision-log.md` and all derived docs in the same change.
- `PLANNING.md` §2 may still show empty checkboxes (`☐`). That is stale
  template state — prefer `decision-log.md` for current working answers.
- Stale wording such as “OS 레이어 → 자체 앱” is wrong. The working order is
  **자체 앱 클로즈드 베타 first → OS 레이어 later** (`decision-log.md` Q7).

## Product identity (v1 working assumptions)

- Name (working): **분신**
- One-liner: ChatGPT talks *with* me; 분신 talks *as* me *to others*
- Target: consumer individuals first (not B2B)
- Delivery: self-owned messenger, closed beta
- Autonomy for v1: **L0~L2 only**
- MVP scenarios: **읽씹 종결** + **단톡 따라잡기**
- Platform: Android first

## Hard scope guards (do not expand without an explicit decision-log update)

Out of v1 scope:

- L3 full away-mode auto-reply
- L4 twin-to-twin negotiation / appointment auto-finalization
- OS-layer bridging over KakaoTalk / Instagram / etc.
- B2B / workspace products
- Server-side full conversation analytics that violate on-device-first

Do not design or implement Phase 2+ work before Phase 1 gates are validated
(`docs/roadmap.md`).

## Absolute safety invariants

These apply at every autonomy level and must not be weakened for convenience:

- Money, appointment confirmation, and emotional/sensitive topics always
  escalate to the human. When uncertain, escalate (fail-safe).
- Twin-authored messages must be visually distinct (badge / `sender_mode`).
- Honest identity answers: if asked “본인이야 분신이야?”, answer as twin.
- Peer veto: if the other person rejects the twin, disable auto-reply for that
  conversation immediately.
- Every automatic action needs post-hoc notification + one-tap undo.

## Privacy & architecture principles

- Tone/style learning: **on-device first**. Do not default to uploading raw chat
  history to servers.
- Autonomy / escalation engine: **client-side** so safety is not blocked by
  server latency or outage.
- Draft generation: on-device first, server LLM fallback with minimal context.
- Relay/storage server is allowed; it is not a license for full cloud analysis.

## Process rules

Follow `docs/PLANNING.md`: decide → narrow → validate → specify.

Current next priorities (do not invent a full stack first):

1. PoC #1 — on-device tone realism
2. PoC #3 — impersonation / trust acceptance (badge, veto UX)
3. Clickable prototype (badge + veto)
4. Small user interviews
5. Meeting review to promote Q1~Q7 from 제안 → 확정

Do not invent frameworks, folder layouts, or CI conventions until real code
exists. When code work starts, prefer Android-first changes aligned with
`docs/tech-design.md` and keep L0~L2 + safety invariants intact.

## Documentation conventions

- Planning docs are written in **Korean**.
- Keep decisions traceable with links to `decision-log.md` Q# and related files.
- Preserve `idea-meeting-2026-06-29.html` as historical source material; do not
  treat it as the live decision record.
- When status changes, keep `PLANNING.md` §8, `roadmap.md`, and `risk-log.md`
  in sync.
- Prefer updating existing docs over creating parallel overlapping docs.

## Communication with agents

- Read the relevant docs before proposing product/tech changes.
- Call out whether a suggestion is inside v1 scope or a future-phase idea.
- If requirements are ambiguous, ask before expanding scope.
