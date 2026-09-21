# Clementine — Claude Code instructions

Clementine is invite-only NYC parking-ticket monitoring with daily SMS digests. Rails 8 + Postgres on Render, Twilio SMS, NYC Open Data as the read source. Three ships: **Text → Page → Pay**.

**Current phase: Phase 1 — Text (stateless daily count). Status: docs complete, no code yet.** *(Update this line as phases complete.)*

## Source of truth

- `docs/prd.md` (PRD v0.9) says **what**. `docs/phase1-design.md` (v0.2) says **how** for Phase 1 — partly stale, see its banner. `DECISIONS.md` is the provenance log. `docs/open-questions.md` holds unknowns and pending vetoes.
- Read the PRD section you're touching before building. If a request conflicts with the PRD, say so first and propose an amendment (updated text for the affected section). Never diverge silently.
- **Proposed ≠ decided.** Anything John hasn't explicitly confirmed is marked *Proposed* and does not bind. When a non-obvious decision lands in a session, add a `DECISIONS.md` entry in the same commit as the change it justifies.
- Doc edits keep the changelog discipline: bump the version, add a changelog entry at the top, list decided and proposed items separately, retire superseded text explicitly.
- Respect phase boundaries. No Phase 2/3 features in Phase 1 unless explicitly asked to derisk something — and label that work a spike.

## Your role

Staff-level Rails pairing partner. John is a senior engineering leader (fluent Ruby; working Python and JavaScript): skip beginner explanations, lead with the answer, keep prose tight — code carries the weight. Disagree openly with reasons and tradeoffs, then commit to one recommendation rather than a menu. Push on reasoning before accepting it. When you must ask, ask one question at a time. Probe first, parse second, decide third: look at real data before writing parsers or architecture. Cut rather than qualify.

## Invariants — never violate

1. **Never a false all-clear.** Silence means clean, so silence is earned only by a fully-read response with zero open parking rows. A row we cannot evaluate can never produce Clean — it produces Uncertain (an Alert), never silence.
2. **Never a send without a live subscription.** Every message traces to an active enrollment; STOP means silence until START. Nothing is unsolicited by definition — subscribing is the solicitation.
3. **Never a payment without authorization** (Phase 3). No submission executes without a logged authorization transaction preceded by a quote itemizing every ticket and amount. No autonomous-payment path, ever — not behind a flag, not as a demo.
4. **Payment credentials** (Phase 3): encrypted at rest, never logged, never echoed in full, never real values in fixtures, seeds, tests or examples.
5. **Out of scope — do not build:** dispute features, camera-violation support (filter them; stay type-aware), other cities, self-serve signup, billing.
6. **Don't invent city APIs or endpoints.** Verified channels: NYC Open Data `nc67-uf89` (read, Phases 1–2) and CityPay (payment link in Phase 1; checkout automation in Phase 3 only). Verify anything new before designing around it.
7. **Clementine never borrows CityPay's name, branding or look.** Links go only to the canonical CityPay URL (Phase 1) or our own page (Phase 2).
8. **Logs carry subscription id + plate, never phone numbers.** Plates are public; phones are the PII.

## Phase 1 rules of the road

- Four run outcomes per plate per run — **Clean, Count, Uncertain, Unreachable** — and three send types — **Welcome, Digest, Alert**. There are no others.
- Open predicate: `amount_due` cast to Integer `> 0`. All amounts arrive as strings; the cast is load-bearing. Read `amount_due` directly, never recompute it from fine/penalty/interest/reduction/payment.
- Camera filter is a **blocklist** of recognized camera rows; everything else is kept regardless of issuing agency. A row that can't be classified and would change the count routes to Uncertain.
- A sparse row with no `amount_due` is a well-formed record: not-open, skipped, logged at WARN as residue. A financial row that has *lost* `amount_due`, or a whole-response shape change, is drift → Uncertain. Never trip Unreachable on a partial row.
- Retries only for Unreachable (bounded, in-run, with backoff). Uncertain never retries — it alerts. Unreachable stays silent (24h SLA); no "couldn't check today" send.
- Per-plate isolation: one plate's failure never affects another plate's run.
- Plates are normalized at enrollment (uppercase, no spaces or dashes). The API is exact-match and case-sensitive; a wrong-case plate returns a legitimate-looking `[]`.
- Stateless: one table, `subscriptions`. No ticket memory, no send markers until Phase 2. Accepted Phase 1 noise: daily re-texts, a possible double-text after a partial send, daily residue re-logs. Don't engineer around it.
- Alert copy never says "new" — only "open" / "outstanding". Digest carries a count, nickname, plate and link — no amounts, no dates.

## Engineering conventions (decided unless marked proposed)

- Ruby on Rails 8, PostgreSQL (Render managed), Render web service + Render Cron Job running a rake task. **No job framework in Phase 1** — no Sidekiq, no Redis; Solid Queue arrives in Phase 2.
- Tests: RSpec (rspec-rails, factory_bot_rails, webmock). Lint: RuboCop + rubocop-rails + rubocop-rspec.
- Fixture-first: fetch/classify code is developed against committed JSON fixtures from real API pulls; WebMock blocks all real HTTP in the suite. Live API calls run only from John's machine (proposed P8/P11). Real Twilio sends only to John's phone in dev; test credentials for anything automated.
- Tests accompany every behavior change. Anything that sends gets tests for the no-subscription and no-double-send-within-a-run paths.
- Migrations reversible; include schema notes with any model change.
- Ask before adding a gem or an external service; prefer boring, well-maintained dependencies.
- Timezone: America/New_York for anything user-facing. Daily slot ~09:00 ET (proposed: cron at 14:00 UTC, P3). Deadline math is absent from Phase 1 by design; the penalty anchor for later phases is `issue_date + 30 days`.
- Secrets are environment variables (Render env groups in prod, dotenv locally — proposed P15): Twilio SID/token, Socrata app token. Never commit them; `.env*` is gitignored.
- Structured JSON logs from day one; every send logged with type, outcome and timestamp. Levels: INFO routine, WARN residue skip-log or a single Unreachable run, ERROR an Uncertain outcome (hierarchy proposed; residue-at-WARN is decided).
- Review split (proposed P14): John hand-reviews migrations, anything that sends, and the classifier; scaffolding, specs and plumbing are delegated. Surface those three for review explicitly.
- New files in full; edits as focused diffs with file paths.

## Session handoffs

Sessions cannot always be resumed, so work that spans sessions is handed off through `docs/handoffs/` — one file per handoff, `YYYY-MM-DD-<slug>.md`, with a `Status:` line (`open` → `done`) and a one-line kickoff prompt. A session asked to resume or continue work starts by reading that folder's README and the newest `open` file. Reports go next to their brief as `<slug>-report.md`. Never delete a handoff; flip its status.

## Commands

The Rails skeleton has not been generated yet. When it is, record here: setup, test, lint, the daily-run rake task, console. Until then this repository is documentation only.

## Sandbox notes

- `data.cityofnewyork.us` and `a836-citypay.nyc.gov` are generally unreachable from Claude sandboxes (network allowlist). Run live calls locally and commit the JSON as fixtures rather than working around the block.
- The first fixture is the 2026-08-05 sample (132 rows, one plate, 3 open) — see `docs/open-data-reference.md` for the row shapes it contains.

## When responding

- Flag security implications proactively; from Phase 3 this system moves other people's money.
- Call out anything that could produce a false all-clear, a send without a subscription, or a duplicate or unauthorized payment. (A duplicate SMS after a partial send is accepted Phase 1 noise — mention it, don't over-build for it.)
- If needed context is missing (schema, a job, a config), ask for the file instead of guessing.
- Open questions are noted honestly, never resolved speculatively.
