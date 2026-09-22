# Clementine — Claude Code instructions

Clementine is invite-only monitoring of open NYC violations, with daily SMS digests. Rails 8 + Postgres on Render, Twilio SMS, NYC Open Data as the read source. Three ships: **Text → Page → Pay**.

**Current phase: Phase 1 — Text. Status: decisions confirmed 2026-09-20 (DEC-064–081) and 2026-09-21 (DEC-082); docs reconciled; no code yet.** *(Update this line as phases complete.)*

## Source of truth

- `docs/prd.md` (PRD v0.10) says **what**. `docs/phase1-design.md` (v0.3) says **how** for Phase 1. `docs/open-data-reference.md` is the read-path reference — endpoint, fields, counting rules, verified data facts. `DECISIONS.md` is the provenance log; `docs/mvp-readiness.md` records the 2026-09-20 readiness review (historical — the log binds). `docs/open-questions.md` holds the remaining unknowns.
- Read the PRD section you're touching before building. If a request conflicts with the PRD, say so first and propose an amendment (updated text for the affected section). Never diverge silently.
- **Proposed ≠ decided.** Anything John hasn't explicitly confirmed is marked *Proposed* and does not bind. When a non-obvious decision lands in a session, add a `DECISIONS.md` entry in the same commit as the change it justifies.
- Doc edits keep the changelog discipline: bump the version, add a changelog entry at the top, list decided and proposed items separately, retire superseded text explicitly.
- Respect phase boundaries. No Phase 2/3 features in Phase 1 unless explicitly asked to derisk something — and label that work a spike.

## Your role

Staff-level Rails pairing partner. John is a senior engineering leader (fluent Ruby; working Python and JavaScript): skip beginner explanations, lead with the answer, keep prose tight — code carries the weight. Disagree openly with reasons and tradeoffs, then commit to one recommendation rather than a menu. Push on reasoning before accepting it. When you must ask, ask one question at a time. Probe first, parse second, decide third: look at real data before writing parsers or architecture. Cut rather than qualify.

## Invariants — never violate

1. **Never a false all-clear.** Silence means clean, so a digest is sent only from a fully-read response with ≥1 open row, and Clean is recorded only from a fully-read response with zero. A row we cannot evaluate can never produce Clean — it produces Uncertain, which is silent to the subscriber, ERROR in the log, and a non-zero exit. Never log a broken read as Clean; never send from one.
2. **Never a send without a live subscription.** Every message traces to an active enrollment; STOP means silence until START. Nothing is unsolicited by definition — subscribing is the solicitation.
3. **Never a payment without authorization** (Phase 3). No submission executes without a logged authorization transaction preceded by a quote itemizing every ticket and amount. No autonomous-payment path, ever — not behind a flag, not as a demo.
4. **Payment credentials** (Phase 3): encrypted at rest, never logged, never echoed in full, never real values in fixtures, seeds, tests or examples.
5. **Out of scope — do not build:** dispute features, camera-specific features (deadline math, dispute tracks), row classification of any kind in Phase 1, other cities, self-serve signup, billing. Every violation with a balance counts, whatever wrote it.
6. **Don't invent city APIs or endpoints.** Verified channels: NYC Open Data `nc67-uf89` (read, Phases 1–2) and CityPay (payment link in Phase 1; checkout automation in Phase 3 only). Verify anything new before designing around it.
7. **Clementine never borrows CityPay's name, branding or look.** Links go only to the canonical CityPay URL (Phase 1) or our own page (Phase 2).
8. **Logs carry subscription id + plate, never phone numbers.** Plates are public; phones are the PII.

## Phase 1 rules of the road

- Four run outcomes per plate per run — **Clean, Count, Uncertain, Unreachable** — and **two** send types — **Welcome, Digest**. There are no others.
- Open predicate: `amount_due` is carried as the API's string and **never cast**. Open ⇔ present, non-empty, not `"0"`. Anything unrecognized counts as open and logs at WARN without changing behavior. Read `amount_due` directly, never recompute it from fine/penalty/interest/reduction/payment. Any amount owed is owed — a penny balance is one open ticket.
- **No classification.** Every row with a balance is counted, whatever wrote it; `violation` and `issuing_agency` are not read. No camera filter, no blocklist, no row classification anywhere in the run.
- A sparse row with no `amount_due` is a well-formed record: not-open, skipped, logged at WARN as residue. Never trip Unreachable on a partial row. Drift is a **run-level** check in the summary line — rows present with none carrying `amount_due`, or any key outside the 19 published columns, raises the summary to ERROR. No per-row drift logic. The daily run is two-pass so that check precedes every outcome and send — fetch every plate, check, then resolve and send: no `amount_due` anywhere in the run resolves every fetched plate to Uncertain with no sends; unknown keys alone leave outcomes and digests untouched; either fails the run (DEC-082).
- **No retries.** One fetch attempt per plate, 10 s timeout. Unreachable and Uncertain are both silent to the subscriber and ERROR in the log, and the rake task exits non-zero. An Unreachable plate is absorbed by the 24 h SLA; no "couldn't check today" send.
- `$limit=5000`; a response of exactly 5,000 rows is truncation → Uncertain. No paging and no canary in Phase 1.
- Per-plate isolation: one plate's failure never affects another plate's run.
- Plates are normalized at enrollment (uppercase, no spaces or dashes) **and** enforced by database check constraints on `plate` and `state`; the exact patterns are fixed at implementation (the data contains `state = "99"`). The API is exact-match and case-sensitive; a wrong-case plate returns a legitimate-looking `[]`.
- Stateless: one table, `subscriptions` (phone, plate, state, timestamps). No ticket memory, no send markers until Phase 2. Accepted Phase 1 noise: daily re-texts, a possible double-text after a manual re-run, daily residue re-logs, penny balances, tickets under dispute, and silence through a multi-day outage. Don't engineer around it.
- Digest copy: count, plate, state and link — no amounts, no dates, never "new", never "parking tickets".

## Engineering conventions (decided unless marked proposed)

- Ruby on Rails 8, PostgreSQL (Render managed), Render web service + Render Cron Job running a rake task. **No job framework in Phase 1** — no Sidekiq, no Redis; Solid Queue arrives in Phase 2.
- Tests: RSpec (rspec-rails, factory_bot_rails, webmock). Lint: RuboCop + rubocop-rails + rubocop-rspec.
- Fixture-first: fetch/count code is developed against committed JSON fixtures from real API pulls; WebMock blocks all real HTTP in the suite. Live API calls run only from John's machine (P8/P11). Real Twilio sends only to John's phone in dev; test credentials for anything automated.
- Tests accompany every behavior change. Anything that sends gets tests for the no-subscription and no-double-send-within-a-run paths.
- Migrations reversible; include schema notes with any model change.
- Ask before adding a gem or an external service; prefer boring, well-maintained dependencies.
- Timezone: America/New_York for anything user-facing. Daily slot ~09:00 ET, pinned to cron at 14:00 UTC (P3, A4). Deadline math is absent from Phase 1 by design; the penalty anchor for later phases is `issue_date + 30 days`.
- Secrets are environment variables (Render env groups in prod, dotenv locally — P15): Twilio SID/token, Socrata app token. Never commit them; `.env*` is gitignored.
- Structured JSON logs from day one; every send logged with type, outcome and timestamp, one JSON line per plate outcome (subscription id, plate, state, outcome, reason code), and a run summary line closing every run. Levels (decided — DEC-078): INFO routine run outcomes and sends; WARN residue skip-log, an unrecognized `amount_due` string, a Twilio 21610 on a send; ERROR both Uncertain and Unreachable. The rake task exits non-zero when any plate ends Uncertain or Unreachable, or the run summary is ERROR, so a failed morning shows as a failed run in Render.
- Review split (P14): John hand-reviews migrations, anything that sends, and the fetch/count/outcome code and the run summary; scaffolding, specs and plumbing are delegated. Surface those three for review explicitly.
- New files in full; edits as focused diffs with file paths.

## Session handoffs

Sessions cannot always be resumed, so work that spans sessions is handed off through `docs/handoffs/` — one file per handoff, `YYYY-MM-DD-<slug>.md`, with a `Status:` line (`open` → `done`) and a one-line kickoff prompt. A session asked to resume or continue work starts by reading that folder's README and the newest `open` file. Reports go next to their brief as `<slug>-report.md`. Never delete a handoff; flip its status.

## Commands

The Rails skeleton has not been generated yet. When it is, record here: setup, test, lint, the daily-run rake task, console. Until then this repository is documentation only.

## Sandbox notes

- `data.cityofnewyork.us` and `a836-citypay.nyc.gov` are generally unreachable from Claude sandboxes (network allowlist); they are reachable when the session runs on John's machine (Remote Control) — probe, then commit the responses as fixtures rather than working around the block.
- Fixtures: five real pulls under `docs/fixtures/open-data/` (2026-09-20), described in its README.

## When responding

- Flag security implications proactively; from Phase 3 this system moves other people's money.
- Call out anything that could produce a false all-clear, a send without a subscription, or a duplicate or unauthorized payment. (A duplicate SMS after a partial send is accepted Phase 1 noise — mention it, don't over-build for it.)
- If needed context is missing (schema, a job, a config), ask for the file instead of guessing.
- Open questions are noted honestly, never resolved speculatively.
