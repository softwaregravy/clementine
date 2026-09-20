# Open questions, unknowns and next actions

Consolidated 2026-09-19 at the move to GitHub. Nothing here blocks *starting* Phase 1; several items gate specific pieces of it. Keep this file current: when an item closes, record the resolution in `DECISIONS.md` and delete it here.

## A. Awaiting John's explicit confirmation or veto

1. **Design doc proposed batch P1–P20** — veto-by-exception, pending since 2026-08-05. The ones that matter before code: P3 (cron at 14:00 UTC), P4 (welcome sends synchronously from the console), P8/P9 (fixture-first test surface — now JSON fixtures, not HTML), P10 (GitHub Actions), P13 (private, trunk-based), P15 (secrets as env vars). Full list in `DECISIONS.md` DEC-055.
2. **PRD amendments A2, A3, A4** — §8 still says "Solid Queue or Sidekiq"; §5 still defers the number type to the design doc; §6 still says "~09:00 ET" without the UTC pin. (A1 landed in substance in v0.9.)
3. **Log-level hierarchy** INFO / WARN / ERROR (PRD v0.9 §7) — proposed/derived; residue-at-WARN is confirmed.
4. **Phase 2/3 proposals carried since v0.4** — quote supersession; unauthorized-submission definition; Phase 2 ship order (tokenized page before OTP); SIM-swap posture. Confirm when those phases spec up.

## B. Design doc reconciliation (pending pass → design v0.3)

`docs/phase1-design.md` v0.2 predates the Open Data pivot (PRD v0.6) and the four-outcome model (v0.9). Known deltas, to fold in one pass:

- **§0 "inherited fixed" list:** "two send types" → three; "parse-fail-loud / never-empty-from-broken" → the Clean / Count / Uncertain / Unreachable model; etiquette "stop-on-captcha" → Phase 3 only; "probe before parser" → fixture-first against real API JSON.
- **§7 (Q7.1 fetch mechanism; Q7.4 camera discrimination from probe HTML)** — moot: plain HTTPS JSON, no browser before Phase 3; camera discrimination is by API fields (`violation`, `issuing_agency`).
- **P8/P9:** fixtures are JSON API responses (start with the 2026-08-05 132-row sample); the test surface adds the outcome model, sparse-row disposition, the residue skip-log, and per-plate isolation.
- **P15 secret inventory:** add the Socrata app token.
- **P16 config constants:** "CityPay URL" → Open Data endpoint + dataset id + the CityPay payment link.
- **D5 retry model:** retries scoped to Unreachable only; Uncertain never retries.
- **Named contingency (Chrome memory / cron-service sizing)** — moot until Phase 3.

## C. Known unknowns — data

1. **Exact camera blocklist predicate.** Observed so far: `violation = "PHTO SCHOOL ZN SPEED VIOLATION"` with `issuing_agency = "DEPARTMENT OF TRANSPORTATION"` (2026-08-05 sample); `violation = "BUS LANE VIOLATION"`, also DOT (live query, 2026-09-19). The red-light string has not been observed (expected `FAILURE TO STOP AT RED LIGHT` — unverified). Decide: match on the `violation` string, on `issuing_agency = DOT`, or require both; and how to route rows matching neither cleanly (→ Uncertain if they would affect the count, per PRD §6).
2. **Judgment / interest-stage rows** — unobserved in the sample (no row with `interest_amount > 0`). Confirm `amount_due` still carries the net balance once a ticket is in judgment.
3. **Result-set size / pagination.** SODA 2.1's default `$limit` is 1,000 rows, and the dataset returns full history per plate. A plate with more than 1,000 historical rows would be silently truncated — an open row past the cut would be a false clean. The fetch must set an explicit `$limit` and treat a page of exactly `$limit` rows as incomplete (page on, or resolve to Uncertain). *Surfaced 2026-09-19; not yet decided.*
4. **SODA3 and the app token.** Socrata's platform now defaults new endpoints to SODA3, which requires an app token or authentication; the SODA 2.1 endpoint (`/resource/nc67-uf89.json`) remains supported and answered an anonymous query on 2026-09-19. The PRD already attaches an app token; confirm the header (`X-App-Token`) at build and list SODA 2.1 deprecation as a §10 risk.
5. **Additional dataset columns** (license_type, precinct, county, violation_status, judgment_entry_date, violation_time, …) — not exercised beyond the fields the sample analysis used. Verify against the dataset's column list before relying on any of them.
6. **CityPay deep link.** The digest links to CityPay's plate-search page; the by-plate search is a POST, so there may be no URL that pre-fills the plate. Verify whether one exists; otherwise the link is the landing page and the user enters the plate.

## D. Known unknowns — Phase 3 recon (see `docs/citypay-reference.md`)

1. reCAPTCHA Enterprise v3 token acquisition (real browser executing the site JS vs. other routes) — deliberately undecided.
2. Zero-violation (clean-plate) response markup — never captured.
3. Checkout POST(s) and the confirmation page — capture the same way the search was captured.
4. Phase 3 scope re-examination (DEC-010) before that phase specs up.

## E. Operational and logistics

1. **A2P 10DLC registration** — start in Twilio (sole-proprietor path). Longest lead time; opens M1. Status unknown as of this file. Inputs: use case, the three sample messages (`docs/messaging.md`), opt-in description, HELP copy.
2. **Final message copy** for Welcome / Digest / Alert — drafts in `docs/messaging.md`; final copy lands at registration.
3. **Sample API response** (`Sample_Results.json`: 132 rows for John's plate, pulled 2026-08-05) — not in this repo yet. Commit it as the first fixture (`spec/fixtures/open_data/` once Rails exists; `docs/fixtures/` until then). Plates and summons numbers are public data per PRD §7; the file carries no phone numbers.
4. **`citypay_probe.rb`** (Ferrum probe from 2026-07-29) — optional; Phase 3 recon only. Keep under `script/` if it's still around.
5. **Trademark search** before anything public-facing; `clementine.nyc` if a domain is ever needed.
6. **CI/CD** — P1/P10 are proposed; nothing exists until the Rails skeleton does.

## F. Next actions, in order

1. Start 10DLC registration (E1).
2. Veto pass on A1–A3 in one sitting: confirm or strike.
3. Design-doc reconciliation pass (B) → `docs/phase1-design.md` v0.3.
4. `rails new` (Rails 8, Postgres, RSpec, RuboCop); merge `.gitignore`; fill in the Commands section of `CLAUDE.md`; commit the sample fixture.
5. Build Phase 1 per PRD §6 and milestone M1 (§12).
