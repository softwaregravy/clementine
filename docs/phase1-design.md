# Clementine — Phase 1 Design Doc v0.3
*Companion to PRD v0.10. The PRD says what; this doc decides how.*

**Owner:** John · **Status:** Decided; proposed batch confirmed 2026-09-20 · **Last updated:** 2026-09-21

## Changelog

- **v0.3** (2026-09-20): Reconciliation pass. Folds in the Open Data read path (PRD v0.6, DEC-032/033), the four-outcome model (PRD v0.9), and the readiness decisions of 2026-09-20 (PRD v0.10, DEC-064–081). The proposed batch **P1–P20 and amendments A2–A4 are confirmed** (DEC-078), with P9's test surface rewritten and P8/P11/P12/P16 given API-era wording; **A1 is superseded** by DEC-072 — Phase 1 has no retries. §7 turns from probe-gated CityPay parsing into the decided Open Data fetch and count; §0's inherited-fixed list is rebuilt; the stale banner is retired. **Review fix, 2026-09-21 (DEC-082):** the daily run is two-pass — fetch every plate, run the drift check, then resolve and send — so the run-level drift check precedes every outcome and send; the exit rule extends to a summary ERROR (D5, §7, P9). **Review fix, 2026-09-21 (DEC-083):** P13 amended — every change reaches `main` by pull request; the "no PR ceremony" clause is retired.
- **v0.2** (2026-08-05): Decision session. Seven structural decisions closed (D1–D7), consequences recorded, twenty low-stakes items batched as **Proposed** for veto-by-exception (P1–P20), four PRD amendments pending sign-off (A1–A4). Remaining opens are probe-gated only.
- **v0.1** (2026-08-04): Template created; all questions open. New criterion on record: technologies chosen for Claude execution strength; AWS named as destination *(revised in v0.2 — see D3)*.

---

## 0. Relationship to the PRD

- PRD §8's reopened stack line **largely re-closes as written**: Rails, Postgres, Render all survive. Two edits emerged (A1, A2); A2 landed in PRD v0.10, A1 was overtaken by DEC-072.
- **Inherited fixed, not relitigated:** daily cadence, fixed at 14:00 UTC; **two** send types — Welcome and Digest — with copy contracts in `docs/messaging.md`; no-tickets-no-text; four run outcomes per plate per run, with Uncertain and Unreachable both silent to the subscriber and ERROR to the maintainer; stateless single `subscriptions` table (phone, plate, state, timestamps); **no classification** — every row with a balance counts, whatever wrote it; etiquette (app token attached, back off on 429/5xx, tens of requests a day); Twilio with native STOP/HELP; carrier registration opens M1, and no Twilio account exists yet; fixture-first against real API JSON.
- **Amended by this doc** (moved out of the inherited-fixed list): the send-slot precision (A4, accepted — DEC-078). The retry line (A1) never landed: Phase 1 has no retries (DEC-072).

## 1. Decision criteria — closed

Ranking confirmed in practice (Q1.1 closed): Claude execution strength; John's review fluency; platform continuity; cost at family scale. No conflicts arose — reviewer fluency and continuity carried every close call.

**Criterion #3 rewritten (Q1.2 closed, D3):** AWS is not a destination. It is a service catalog, called à la carte from Render only when a requirement names a specific service — KMS at Phase 3, possibly S3 for backups. There is no planned migration. Ever.

## 2–6. Structural decisions

- **D1 — Language: Ruby** (Q2.1). Q2.3 moot: `citypay_probe.rb` runs as-is; nothing to port.
- **D2 — Rails 8 from day 1** (Q2.2/Q3.1). Phase 2 needs it regardless; the console is the admin surface; convention density is an agent asset. Routes in Phase 1 (Q3.2 closed): Rails' built-in `/up` health check. Nothing else.
- **D3 — Hosting: Render for the app's life** (Q4.1/Q1.2). Render footprint: **web service + cron job + managed Postgres**, single region. Q4.2 moot.
- **D4 — Database: Postgres** (Q5.1/Q5.2), Render managed, smallest tier. SQLite one-box considered and declined: it couples the app to a disk and spends its savings exactly where Phase 3's audit log and vault live.
- **D5 — Jobs: Render Cron Job + rake task. No job framework in Phase 1** (Q6). Settles PRD §8's "Solid Queue or Sidekiq": neither — Sidekiq drags in Redis; Solid Queue arrives at Phase 2, where poll-on-login, manual refresh, and health alerting make it load-bearing. **Retry model, revised 2026-09-20 (DEC-072): one attempt per plate, 10-second timeout, no retries.** An Unreachable plate is skipped for the day and logged at ERROR; the 24h SLA is the backstop, and Unreachable never produces a Clean, so no invariant is exposed. The rake task **exits non-zero** when any plate ends Uncertain or Unreachable, or the run summary is ERROR, so a failed morning shows as a failed run in Render's cron dashboard (DEC-071, DEC-082). This is deliberate MVP reliability debt — a transient blip costs a plate one day instead of two minutes. Retries return at Phase 2 with Solid Queue, and must return as a **two-pass batch** (fetch every plate, collect the failures, retry the failed set): retrying inline per plate costs 42 minutes × N plates, and a fifteen-plate outage would run the cron job past midnight. The Phase 1 run is already two-pass — fetch every plate, then resolve and send (DEC-082) — so the retry batch slots between the passes. Per-plate rescue inside the run: one plate's failure never skips the others. *(Supersedes A1.)*
- **D6 — Twilio number: A2P 10DLC, local NYC number**, sole-proprietor path as working assumption (Q8.1). Rationale on record: our digest pattern-matches the ticket-phishing genre; a local number saved as a contact, plus the welcome message, is the antidote. **This starts the M1 clock — registration is the first real-world action. Status 2026-09-20 (DEC-079): no Twilio account exists yet.** Account → local NYC number → brand and campaign registration is step zero; approval runs days to weeks and gates production sends but not the build, so it runs in parallel from now.
- **D7 — Tests: RSpec** (Q9.1), reviewer-fluency criterion. Scaffolding: rspec-rails, factory_bot_rails, webmock.

## 7. Open Data fetch & count — decided

The probe-gated questions this section carried are moot. Q7.1 (fetch mechanism) closed with DEC-033: Phase 1's read is a plain HTTPS JSON request and no browser exists before Phase 3. Q7.4 (camera discrimination) closed with DEC-065: Phase 1 classifies nothing. The named Chrome-memory contingency goes with them. Data facts — field types, row shapes, verified HTTP behavior — live in `docs/open-data-reference.md`; this is the design surface.

- **Endpoint and query:** `GET https://data.cityofnewyork.us/resource/nc67-uf89.json?plate=<PLATE>&state=<STATE>`, exact-match and case-sensitive, `X-App-Token` header attached. One request per distinct plate per run.
- **Limit and truncation:** `$limit=5000`; a page of exactly 5,000 rows is truncation → **Uncertain**. No paging code in Phase 1 (DEC-070).
- **Timeout and retries:** 10-second timeout, one attempt, no retries (DEC-072).
- **HTTP mapping:** timeout / connection failure / 5xx / 429 / a body that will not parse as JSON → **Unreachable**; any other 4xx or a 2xx body that parses but is not a JSON array → **Uncertain** (DEC-071).
- **Open predicate:** `amount_due` present, non-empty, not `"0"` — the API's string, never cast. Anything unrecognized counts as open and logs at WARN without changing behavior (DEC-064).
- **No classification:** `violation` and `issuing_agency` are not read; there is no filter and no blocklist (DEC-065).
- **Sparse rows:** no `amount_due` → not-open, skipped, WARN residue with the full raw row. Never trips Unreachable (DEC-039, DEC-044).
- **Run structure:** two passes (DEC-082). Pass one fetches every plate; the run-level drift check then runs over every fetched row; pass two applies the predicate, resolves each plate, sends, and writes the per-plate lines and the summary.
- **Drift:** run-level only — the summary line's `rows_with_amount_due` and `unknown_keys` counts, with the two ERROR conditions of DEC-069, computed between the passes. No row in the run carrying `amount_due` → every fetched plate **Uncertain** (reason `drift`), no sends. Unknown keys alone → outcomes and digests untouched, summary ERROR. Either fails the run. No per-row drift logic.
- **Per-plate isolation:** one plate's Uncertain or Unreachable never affects another's (DEC-046).

## 8. Twilio specifics — closed with D6, batch decided

- **P5:** one Messaging Service wraps the number; custom HELP copy is configured there, written by John during campaign registration (where the **two** sample messages already live — `docs/messaging.md`). Closes Q8.2/Q8.3 ownership. *(Decided — DEC-078.)*
- **P6:** unrecognized inbound is ignored — no auto-replies beyond Twilio-native STOP/HELP/START. *(Decided — DEC-078.)*
- **P7:** no delivery status callbacks in Phase 1. PRD §9's metric is "Twilio-reported" verbatim; the Twilio console is the delivery ledger until Phase 2's `notifications` table exists. *(Decided — DEC-078.)*
- **Stopped subscribers:** a STOP'd number surfaces as **Twilio error 21610** on the next send attempt. Catch it, log at **WARN**, carry on with the run; nothing flips in the table, because there is no `active` flag (DEC-025, DEC-076).

## 9. Testing, CI & the AI workflow — decided (DEC-078)

- **P8 (Q7.3):** **fixture-first** — the five real API pulls under `docs/fixtures/open-data/` are the spec fixtures (they move to `spec/fixtures/open_data/` when the Rails app exists); fetch and count code is developed and reviewed against them, never live. WebMock blocks all real HTTP in the suite. *(Decided — DEC-078.)*
- **P9 (Q9.2):** Phase 1 test surface, **rewritten 2026-09-20** (DEC-078):
  - the string open predicate — `"65"`, `"93.76"`, `" 75 "` open silently; `"0"`, `""` and an absent key not open; `"0.00"`, `"0.0"`, `"00"`, `"-25"`, `"abc"`, `"1e3"` open **and** WARN;
  - sparse rows → not-open, skipped, WARN residue;
  - the run-level drift conditions (DEC-082) — no `amount_due` anywhere in the run resolves every fetched plate to Uncertain with no sends; an unknown key alone leaves outcomes and sends untouched; both raise the summary to ERROR and fail the run;
  - the truncation sentinel — exactly 5,000 rows → Uncertain;
  - the HTTP split — timeout / 5xx / 429 / unparseable → Unreachable; other 4xx and a non-array 2xx body → Uncertain;
  - per-plate failure isolation;
  - both message templates;
  - the no-subscription and no-double-send-within-a-run paths on everything that sends;
  - the non-zero exit when any plate ends Uncertain or Unreachable, or the summary is ERROR.

  Live API and live Twilio never appear in CI.
- **P10 (Q9.3):** GitHub Actions on every push — rspec + rubocop. Deploys wait for green (pairs with P1 below). *(Decided — DEC-078.)*
- **P11 (Q9.4 + Q10.4):** live-fire policy — the real Open Data API only manually, from John's machine, against his own plate; real Twilio sends only to John's phone in dev; Twilio test credentials for anything automated. *(Decided — DEC-078.)*
- **P12 (Q9.5):** `CLAUDE.md` carries: stack + commands; pointers to the PRD, this doc and `docs/open-data-reference.md`; the invariants **as reworded on 2026-09-20**; standing rules — fixture-first, probe before parser, no live API or Twilio in tests, decided-vs-proposed discipline, PII log posture (P19). *(Decided — DEC-078.)*
- **P13 (Q9.6):** GitHub repo, trunk-based — short-lived branches off `main`, nothing long-lived — CI on every push. **Amended 2026-09-21 (DEC-083):** every change reaches `main` through a pull request John reviews on GitHub; no direct commits to `main`; the "no PR ceremony" clause is retired, because the pull request is the review surface P14 assumes. The repo is public — left so for now (John, 2026-09-21; DEC-083) — where this line once said private. *(Decided — DEC-078; amended DEC-083.)*
- **P14 (Q9.8):** review split — John hand-reviews migrations, anything that sends, and the fetch/count/outcome code with its run summary; scaffolding, specs, and plumbing are delegated wholesale. *(Decided — DEC-078.)*
- *(Q9.7 closed by consequence of D1/D7: RuboCop + rubocop-rails + rubocop-rspec.)*

## 10. Config, secrets & environments — decided (DEC-078)

- **P15 (Q10.1):** secrets are **environment variables** — Render env groups in prod, dotenv locally. One secrets system, and it's the platform's. Phase 1's entire secret inventory: **Twilio SID + token, and the Socrata app token** (the DB URL is Render-injected). *(Decided — DEC-078.)*
- **P16 (Q10.2):** non-secret config lives as code constants — the Open Data endpoint and dataset id, `$limit`, the fetch timeout, the cron slot, the CityPay payment link, and the **19 known column names** that the run summary's `unknown_keys` count is measured against (DEC-069, DEC-080). Cut the config surface. *(Decided — DEC-078.)*
- **P17 (Q10.3):** environments: dev + prod. No staging at family scale. *(Decided — DEC-078.)*

## 11. Observability — decided (DEC-078)

- **P18 (Q11.1):** structured JSON logs from day 1 (lograge or equivalent). **One line per plate outcome** — subscription id, plate, state, outcome, reason code — and a **run summary line** closing every run: outcomes, sends, duration, `rows`, `rows_with_amount_due`, `rows_without_amount_due`, `unknown_keys`, with the two ERROR conditions of DEC-069. Every send logged with type, outcome, and timestamp — the send log must answer *what went to whom, when*, including stopped-subscriber visibility. **Log levels, decided (DEC-078):** INFO routine run outcomes and sends; WARN residue skips, unrecognized `amount_due` strings, and a Twilio 21610; ERROR **both** Uncertain and Unreachable. Render's log stream is the record and John is the reader — there is no `run_events` table (DEC-073). *(Decided.)*
- **P19 (Q11.2):** logs identify **subscription id + plate, never phone numbers** (plates are public; phones are the PII). Render log stream, default retention; a drain is adopted only when something needs it. *(Decided — DEC-078.)*
- **P20 (Q11.3):** no error tracker in Phase 1 — PRD §7 says logs only, and this doc honors it. The ERROR log *is* the maintainer channel (DEC-071). Revisit at Phase 2 alerting. *(Decided — DEC-078.)*

## Deployment & scheduling details — decided (DEC-078)

- **P1 (Q4.3):** GitHub → Render auto-deploy on `main`, gated on CI green.
- **P2 (Q4.4):** Render US East (Virginia).
- **P3:** cron fires at **14:00 UTC** — 09:00 EST / 10:00 EDT. The wobble lands late, never before 9am (→ A4).
- **P4:** the welcome message sends **synchronously from the console** at enrollment — there is no worker to queue it on. A one-second blocking Twilio call at family scale.

## PRD amendments — resolved

- **A1 (§6 Phase 1, Retries):** **superseded by DEC-072** before it landed — Phase 1 has no retries at all. The in-run retry model returns at Phase 2, and as a two-pass batch (D5 above).
- **A2 (§8, Stack):** accepted (DEC-078), landed in PRD v0.10 — "no job framework in Phase 1 (Render Cron + rake task); Solid Queue at Phase 2." Rails, Postgres, Render, single region unchanged; RSpec added.
- **A3 (§5/§12, Carrier registration):** accepted (DEC-078), landed in PRD v0.10 — A2P 10DLC, local NYC number, sole-proprietor path, carrying DEC-079's no-account-yet status.
- **A4 (§6 Phase 1, Digest):** accepted (DEC-078), landed in PRD v0.10 — "~09:00 ET" is a fixed 14:00 UTC; seasonal drift to 10:00 EDT accepted within the tilde.

## Out of scope for this doc

Phase 2 page/OTP architecture; Phase 3 vault, checkout automation, SendGrid; any parser code before probe evidence.

## Next actions

1. **John:** create the Twilio account, buy a local New York number, start 10DLC sole-prop registration — step zero, days-to-weeks lead, running in parallel with everything below (DEC-079).
2. **Then:** repo bootstrap per this doc — `rails new` (Rails 8, Postgres, RSpec, RuboCop, GitHub Actions), fixtures moved to `spec/fixtures/open_data/`, `CLAUDE.md`'s Commands section filled in.
3. **Then:** build Phase 1 — subscriptions → fetch / count → welcome, digest; run summary and residue log.
