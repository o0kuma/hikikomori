# Claude Code — hikikomori / 와카뷰

Follow the project instructions in [@AGENTS.md](./AGENTS.md).

Quick context:

- Phase 1 A~C are in place (`core-backend/`, `ai-service/`, `mobile/`).
  **Next execution track:** N1 smoke → N2 Docker (`msn.iykyka.com`) → N3 stabilize →
  N4 FCM/Android QA → **N5 / D human PoC last** — see
  [`docs/deploy-checklist.md`](./docs/deploy-checklist.md). Do not start human PoC
  early or invent Phase 1 §3 defaults.
- Working product name: **와카뷰** (가칭 확정).
- Source of decisions: `docs/decision-log.md` (Q1~Q7 **확정**; PoC sub-questions open).
- v1 scope: self-app closed beta, L0~L2, 읽씹 종결 + 단톡 따라잡기, Android first.
- Hard bans for v1: L3/L4, OS-layer over third-party messengers, B2B.
- Never weaken escalation, twin badge, peer veto, or undo.
- **Git:** work and land on `main`; after each push to GitHub `origin`, also push
  `main` to Gitea `gitea` (`scripts/push-both.sh`). See `AGENTS.md`.

Before changing product or technical direction, read `AGENTS.md` and the
relevant files under `docs/`.
