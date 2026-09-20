> **⚠️ Partly stale — reconciliation pending (banner added at the GitHub handoff, 2026-09-19).**
> This doc was cut on 2026-08-05 against PRD v0.5 and **predates two later decisions**: the Open Data API read path (PRD v0.6, DEC-032/033) and the four-outcome model with the Alert send type (PRD v0.9, DEC-041). The structural decisions D1–D7 stand. The probe-gated §7 is moot (no browser before Phase 3; camera discrimination is by API fields), the "inherited fixed" list in §0 is out of date, and P8/P9/P15/P16 need the API-era wording. The full delta list is in `docs/open-questions.md` §B; the pass produces v0.3. The proposed batch P1–P20 and amendments A2–A4 are still awaiting John's veto pass (A1 landed in substance in PRD v0.9). Body below is verbatim v0.2.

# Clementine — Phase 1 Design Doc v0.2
*Companion to PRD v0.5. The PRD says what; this doc decides how.*

**Owner:** John · **Status:** Decided except probe-gated items; proposed batch awaiting veto pass · **Last updated:** 2026-08-05

## Changelog

- **v0.2** (2026-08-05): Decision session. Seven structural decisions closed (D1–D7), consequences recorded, twenty low-stakes items batched as **Proposed** for veto-by-exception (P1–P20), four PRD amendments pending sign-off (A1–A4). Remaining opens are probe-gated only.
- **v0.1** (2026-08-04): Template created; all questions open. New criterion on record: technologies chosen for Claude execution strength; AWS named as destination *(revised in v0.2 — see D3)*.

---

## 0. Relationship to the PRD

- PRD §8's reopened stack line **largely re-closes as written**: Rails, Postgres, Render all survive. Two edits emerge (A1, A2 below).
- **Inherited fixed, not relitigated:** daily cadence; two send types with v0.5 copy contracts; no-tickets-no-text; parse-fail-loud / never-empty-from-broken; stateless single `subscriptions` table; camera filter; etiquette (one request per plate per day, stop-on-captcha); Twilio with native STOP/HELP; carrier registration opens M1; probe before parser.
- **Amended by this doc** (moved out of the inherited-fixed list, pending PRD sign-off): the retry line (A1) and the send-slot precision (A4).

## 1. Decision criteria — closed

Ranking confirmed in practice (Q1.1 closed): Claude execution strength; John's review fluency; platform continuity; cost at family scale. No conflicts arose — reviewer fluency and continuity carried every close call.

**Criterion #3 rewritten (Q1.2 closed, D3):** AWS is not a destination. It is a service catalog, called à la carte from Render only when a requirement names a specific service — KMS at Phase 3, possibly S3 for backups. There is no planned migration. Ever.

## 2–6. Structural decisions

- **D1 — Language: Ruby** (Q2.1). Q2.3 moot: `citypay_probe.rb` runs as-is; nothing to port.
- **D2 — Rails 8 from day 1** (Q2.2/Q3.1). Phase 2 needs it regardless; the console is the admin surface; convention density is an agent asset. Routes in Phase 1 (Q3.2 closed): Rails' built-in `/up` health check. Nothing else.
- **D3 — Hosting: Render for the app's life** (Q4.1/Q1.2). Render footprint: **web service + cron job + managed Postgres**, single region. Q4.2 moot.
- **D4 — Database: Postgres** (Q5.1/Q5.2), Render managed, smallest tier. SQLite one-box considered and declined: it couples the app to a disk and spends its savings exactly where Phase 3's audit log and vault live.
- **D5 — Jobs: Render Cron Job + rake task. No job framework in Phase 1** (Q6). Settles PRD §8's "Solid Queue or Sidekiq": neither — Sidekiq drags in Redis; Solid Queue arrives at Phase 2, where poll-on-login, manual refresh, and health alerting make it load-bearing. Retry model: **in-run retries (~an hour, with backoff); if all fail, skip today, log loudly, tomorrow covers it** — justified by the PRD's own 24h-SLA argument (→ A1). Per-plate rescue inside the run: one plate's failure never skips the others.
- **D6 — Twilio number: A2P 10DLC, local NYC number**, sole-proprietor path as working assumption (Q8.1). Rationale on record: our digest pattern-matches the ticket-phishing genre; a local number saved as a contact, plus the welcome message, is the antidote. **This starts the M1 clock — registration is the first real-world action.**
- **D7 — Tests: RSpec** (Q9.1), reviewer-fluency criterion. Scaffolding: rspec-rails, factory_bot_rails, webmock.

## 7. CityPay fetch & parse — probe-gated

The only open questions in the doc. Both wait on John running `citypay_probe.rb` against his own plate and sharing artifacts.

- **Q7.1 (open):** fetch mechanism — plain HTTP session (Faraday + Nokogiri, per narrowed Q7.2) vs Ferrum. Decided by probe evidence, not preference.
- **Q7.4 (open):** camera-violation discrimination — field vs heuristic. Placeholder until probe HTML exists.
- **Named contingency:** if the probe proves a browser is required, Chrome's memory appetite reopens cron-service sizing. Decided then, not before.

## 8. Twilio specifics — closed with D6 + proposals

- **P5:** one Messaging Service wraps the number; custom HELP copy is configured there, written by John during campaign registration (where the sample messages already live). Closes Q8.2/Q8.3 ownership.
- **P6:** unrecognized inbound is ignored — no auto-replies beyond Twilio-native STOP/HELP/START.
- **P7:** no delivery status callbacks in Phase 1. PRD §9's metric is "Twilio-reported" verbatim; the Twilio console is the delivery ledger until Phase 2's `notifications` table exists.

## 9. Testing, CI & the AI workflow — proposed batch

- **P8 (Q7.3):** **fixture-first parser** — probe HTML committed as spec fixtures; the parser is developed and reviewed against fixtures, never live. WebMock blocks all real HTTP in the suite.
- **P9 (Q9.2):** Phase 1 test surface: parser-on-fixtures (core), both message templates, the camera filter, per-plate failure isolation, retry-then-skip behavior. Live CityPay never appears in CI.
- **P10 (Q9.3):** GitHub Actions on every push — rspec + rubocop. Deploys wait for green (pairs with P1 below).
- **P11 (Q9.4 + Q10.4):** live-fire policy — real CityPay only via the probe script, manually, against John's own plate; real Twilio sends only to John's phone in dev; Twilio test credentials for anything automated.
- **P12 (Q9.5):** `CLAUDE.md` carries: stack + commands; pointers to PRD and this doc; standing rules — parser after evidence, fixture-first, never-empty-from-broken, no live CityPay in tests, decided-vs-proposed discipline, PII log posture (P19).
- **P13 (Q9.6):** private GitHub repo, trunk-based, CI on every push. No PR ceremony for a sole developer.
- **P14 (Q9.8):** review split — John hand-reviews migrations, anything that sends, and the parser; scaffolding, specs, and plumbing are delegated wholesale.
- *(Q9.7 closed by consequence of D1/D7: RuboCop + rubocop-rails + rubocop-rspec.)*

## 10. Config, secrets & environments — proposed batch

- **P15 (Q10.1):** secrets are **environment variables** — Render env groups in prod, dotenv locally. One secrets system, and it's the platform's. Phase 1's entire secret inventory: Twilio SID + token (DB URL is Render-injected).
- **P16 (Q10.2):** non-secret config — send slot, retry spacing, CityPay URL — lives as code constants. Cut the config surface.
- **P17 (Q10.3):** environments: dev + prod. No staging at family scale.

## 11. Observability — proposed batch

- **P18 (Q11.1):** structured JSON logs from day 1 (lograge or equivalent); every send logged with type, outcome, and timestamp — the send log must answer *what went to whom, when*, including stopped-subscriber visibility.
- **P19 (Q11.2):** logs identify **subscription id + plate, never phone numbers** (plates are public; phones are the PII). Render log stream, default retention; a drain is adopted only when something needs it.
- **P20 (Q11.3):** no error tracker in Phase 1 — PRD §7 says logs only, and this doc honors it. Revisit at Phase 2 alerting.

## Deployment & scheduling details — proposed

- **P1 (Q4.3):** GitHub → Render auto-deploy on `main`, gated on CI green.
- **P2 (Q4.4):** Render US East (Virginia).
- **P3:** cron fires at **14:00 UTC** — 09:00 EST / 10:00 EDT. The wobble lands late, never before 9am (→ A4).
- **P4:** the welcome message sends **synchronously from the console** at enrollment — there is no worker to queue it on. A one-second blocking Twilio call at family scale.

## Pending PRD amendments — awaiting John's sign-off, land as PRD v0.6

- **A1 (§6 Phase 1, Retries):** "a few attempts spaced across the day" → "retries within the run (~an hour, with backoff); if all fail, today's digest is skipped (logged) and tomorrow's covers it." Rationale: the 24h SLA the PRD already invokes; enables the no-framework Phase 1 (D5).
- **A2 (§8, Stack):** "Solid Queue or Sidekiq" → "no job framework in Phase 1 (Render Cron + rake task); Solid Queue at Phase 2." Rails, Postgres, Render, single region: unchanged. Add: RSpec.
- **A3 (§5/§12, Carrier registration):** record the number-type decision — A2P 10DLC, local NYC number, sole-proprietor path — so M1's opening action is unambiguous.
- **A4 (§6 Phase 1, Digest):** "~09:00 ET" interpreted as fixed 14:00 UTC; seasonal drift to 10:00 EDT accepted within the tilde.

## Out of scope for this doc

Phase 2 page/OTP architecture; Phase 3 vault, checkout automation, SendGrid; any parser code before probe evidence.

## Next actions

1. **John:** veto pass on P1–P20 and sign-off on A1–A4.
2. **John:** start 10DLC sole-prop registration in Twilio (M1's clock — days-to-weeks lead).
3. **John:** run `citypay_probe.rb` against his own plate; share artifacts → closes Q7.1/Q7.4, unblocks the parser.
4. **Then:** repo bootstrap per this doc (Rails 8, RSpec, CI, CLAUDE.md) — Phase 1 build begins.
