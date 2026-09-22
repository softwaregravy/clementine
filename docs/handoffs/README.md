# Session handoffs

Claude Code sessions cannot always be resumed, and nothing outside the repo survives one. So any work that spans sessions is handed off through this folder: a file that a fresh session can read and act on with no other context.

## Convention

- **One file per handoff,** named `YYYY-MM-DD-<slug>.md`. The date is when it was written, not when it should run.
- **Header block** on line 3: `**Status:** open | done` · `**For:**` the kind of session it expects (editorial task, staff-level review, build) · `**Kickoff:**` the exact one-line prompt to type into a new session · what it **writes its report to**.
- **Kickoff is always the same shape:** `Read docs/handoffs/<file> and follow it.` Nothing to paste.
- **Reports** go next to the brief as `<slug>-report.md`, written by the executing session, committed with the work. The report is for the *next* session; the chat reply is for John.
- **Status flips, files stay.** When a handoff is consumed, the executing session sets `Status: done` and commits. Never delete a handoff — the sequence is part of the project's provenance, alongside `DECISIONS.md`.
- **Briefs decide nothing.** A brief maps decisions already in `DECISIONS.md` onto work. Where a brief would need a decision that doesn't exist, the executing session leaves `<!-- TODO(john): … -->` and reports it rather than deciding.
- **Guardrails are explicit,** because a smaller model executing a brief will drift without them: an edit-only file list, an off-limits list, a verification step it must run and paste, and a report format.

## Resuming

To pick up where the last session left off: read this README, then the newest file with `Status: open`. Resume prompts (as opposed to task briefs) are named `…-resume.md` and carry the operating context the resuming session needs that the repo doesn't record — who John is in that thread, what channel he's on, what the last session learned the hard way.

## Index

| File | Status | What |
|---|---|---|
| `2026-09-20-cascade.md` | done | Editorial: bring PRD, CLAUDE.md, README, messaging, Open Data reference, design doc and open-questions into line with DEC-064–081. Report → `2026-09-20-cascade-report.md`. |
| `2026-09-20-resume.md` | done | Staff-level: verify the cascade, surface TODOs and grep survivors to John, merge to `main` on his word, then start the Rails skeleton. |
| `2026-09-21-build-skeleton.md` | open | Build: generate the Rails skeleton — `rails new`, RSpec/RuboCop/CI plumbing, fixtures moved to `spec/fixtures/open_data/`, `CLAUDE.md` Commands filled. Gated on John's Twilio-sequencing answer. Report → `2026-09-21-build-skeleton-report.md`. |

Keep this table current: add a row when you write a handoff, flip the status when you consume one.
