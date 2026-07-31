# Project Instructions — hikikomori / 분신 (가칭)

This repository is an AI-twin messenger ("나를 대신해 남과 대화하는 AI 분신") with
Phase 1 app code (`core-backend/`, `ai-service/`, `mobile/`) plus planning docs.

Canonical product decisions live under `docs/`. Prefer linking to them over
copying content into prompts or new files.

## Document authority

When documents disagree, follow this order:

1. [`docs/decision-log.md`](docs/decision-log.md) — working assumptions for Q1~Q7
2. [`docs/vision.md`](docs/vision.md) / [`docs/PRD.md`](docs/PRD.md) / [`docs/tech-design.md`](docs/tech-design.md)
3. [`docs/roadmap.md`](docs/roadmap.md) / [`docs/risk-log.md`](docs/risk-log.md)
4. [`docs/PLANNING.md`](docs/PLANNING.md) — process guide
5. [`docs/idea-meeting-2026-06-29.html`](docs/idea-meeting-2026-06-29.html) — historical meeting source only

Notes:

- Q1~Q7 in `decision-log.md` are **확정** (Phase 1 C, 2026-07-30). PoC-dependent
  sub-questions (default autonomy level, whitelist defaults, final branding)
  stay open — do not invent those. To reverse a Q, update `decision-log.md` and
  derived docs in the same change.
- Prefer `decision-log.md` (and the synced summary in `PLANNING.md` §2) for
  current working answers.
- Working delivery order is **자체 앱 클로즈드 베타 first → OS 레이어 later**
  (`decision-log.md` Q7). Do not reverse that sequence.

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

PoC execution (real participant recruiting for PoC #1/#3, Q3 interviews) is
deferred to the **very last** Phase 1 step — after Flutter client + remaining
server infra are done. Do not start human PoC early and do not invent defaults
for Phase 1 §3. See `docs/roadmap.md` Phase 1 §3/§4.

The tech stack for Phase 1 is decided — see `docs/tech-design.md` §8
(Flutter/Dart client, Go core backend + Python AI service, PostgreSQL,
WebSocket relay, drift+SQLCipher on-device). Do not re-litigate or invent a
different stack; build within this one unless a decision-log-style update
changes it.

### Phase 1 앱 빌드 작업 규칙

- Before starting any Phase 1 app-build task, check `docs/roadmap.md`'s
  "Phase 1 상세 작업 분해" checklist for what's already done and what's next.
- After Phase 1 A~C, use [`docs/deploy-checklist.md`](docs/deploy-checklist.md)
  (N1→N5) for smoke, Docker deploy, stabilize, FCM/Android QA, then human PoC.
  Keep that file and `roadmap.md` in sync when status changes.
- Follow the "권장 착수 순서" there — don't skip ahead in the numbered order
  without a reason, and note the reason in the checklist if you do.
- When a task is finished, check it off in that same checklist. When you
  discover a new sub-task, add it there rather than tracking it elsewhere.
- Items under Phase 1 §3 ("PoC 결과가 있어야 정할 수 있는 것") stay unresolved
  until real PoC data comes in — don't guess a default to unblock yourself;
  leave a placeholder and move on to other checklist items instead. Do not
  start §3 early even if PoC data happens to arrive mid-way — finish all of
  §4's items 1-5 (the rest of the build order) first, then come back to §3.

Do not invent frameworks, folder layouts, or CI conventions beyond what
`docs/tech-design.md` §8 and `docs/roadmap.md` already specify.

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
