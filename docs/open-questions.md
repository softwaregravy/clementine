# Open questions, unknowns and next actions

Pruned 2026-09-20 after the Phase 1 readiness pass (`docs/mvp-readiness.md` Q1–Q12; resolutions in `DECISIONS.md` DEC-064 to DEC-081, corrected at the same-day confirmation pass). Nothing here blocks building Phase 1. Keep this file current: when an item closes, record the resolution in `DECISIONS.md` and delete it here.

## A. Awaiting John's explicit confirmation or veto

1. **Phase 2/3 proposals carried since PRD v0.4** — quote supersession; the unauthorized-submission definition; Phase 2 ship order (tokenized page before OTP); SIM-swap posture. Confirm when those phases spec up, not before.

*(The design-doc batch P1–P20, amendments A2–A4 and the log-level hierarchy closed on 2026-09-20 — DEC-078.)*

## B. Design doc reconciliation (pending pass → design v0.3)

`docs/phase1-design.md` v0.2 predates the Open Data pivot (PRD v0.6), the four-outcome model (v0.9) **and the 2026-09-20 readiness pass**. Known deltas, to fold in one pass:

- **§0 "inherited fixed" list:** "two send types" → stays two (the Alert came and went — DEC-029, DEC-077); "parse-fail-loud / never-empty-from-broken" → the Clean / Count / Uncertain / Unreachable model; "camera filter" → **no classification at all** (DEC-065); etiquette "stop-on-captcha" → Phase 3 only; "probe before parser" → fixture-first against real API JSON.
- **§7 (Q7.1 fetch mechanism; Q7.4 camera discrimination from probe HTML)** — moot: plain HTTPS JSON, no browser before Phase 3, and no camera discrimination in Phase 1 at all.
- **D5 retry model:** "~an hour with backoff" → **one attempt, no retries** (DEC-072). Record the two-pass structure as the Phase 2 starting point, and the reason: per-plate inline retries cost 42 minutes × N plates.
- **P8/P9:** fixtures are JSON API responses (the five under `docs/fixtures/open-data/`). The test surface is rewritten by DEC-078 — string predicate, the run-level drift summary, truncation sentinel, HTTP split, per-plate isolation, and the no-subscription / no-double-send-within-a-run paths on everything that sends.
- **P15 secret inventory:** add the Socrata app token.
- **P16 config constants:** Open Data endpoint + dataset id + `$limit`, the archival key set (DEC-069), and the CityPay payment link.
- **No canary in Phase 1** (DEC-074); the banked probe is a Phase 2 observability item.
- **§6 outcomes and sends:** Uncertain is silent to the subscriber and ERROR to the maintainer, like Unreachable (DEC-071); no Alert send in Phase 1 (DEC-077).
- **New in §11:** the run-summary log line and reason codes (DEC-073).
- **Named contingency (Chrome memory / cron-service sizing)** — moot until Phase 3.

## C. Known unknowns — data

1. **SODA 2.1 deprecation and the app token.** Socrata defaults new endpoints to SODA3, which requires a token or authentication; the SODA 2.1 endpoint (`/resource/nc67-uf89.json`) remains supported and answered an anonymous query on 2026-09-20. Confirm the `X-App-Token` header name at build, and list SODA 2.1 deprecation as a PRD §10 risk. *(Carried from the 2026-09-19 list.)*
2. **Plate collisions across license types.** *(New, 2026-09-20.)* The query is `plate` + `state` and returns every `license_type` on those characters. John's 136 rows are all `PAS`, so nothing collides today, but NY plate characters can repeat across plate types, and a subscriber's count would then include a stranger's tickets. The direction is safe — it over-counts, never a false clean — and it matches the payment surface, since CityPay's by-plate form defaults `PLATE_TYPE` to "--ALL--". Unverified whether it happens at all. Watch for it in live-fire; if it appears, the fix is a `license_type` column on `subscriptions` and a filter.
3. **`violation_status` and disputed tickets.** *(Corrected 2026-09-20 — the first note called the column unusable; it is not.)* Populated on ~29M rows: `HEARING HELD-GUILTY` 11.3M, `HEARING HELD-GUILTY REDUCTION` 8.8M, `HEARING HELD-NOT GUILTY` 7.1M, `HEARING PENDING` 807K, plus appeal and admin statuses. Socrata omits null keys, which is why no committed fixture row carries it. **`HEARING PENDING` rows carry `amount_due > 0`**, so a ticket under dispute counts as open and is nagged daily in Phase 1 — consistent with no dispute support (DEC-003); Phase 2's dismiss is the relief. Not used in Phase 1.
4. **Small balances.** *(New, 2026-09-20 — John.)* 136 rows carry `0 < amount_due < 1` (e.g. `"0.01"` after a `49.99` payment on a `50` fine); 4,003 carry under `$5`. Most likely interest that accrued between a payment being made and posted (a mailed cheque, a slow medium), and the city may suppress trivial balances itself. Phase 1 treats any amount owed as owed (DEC-064). Later: find out what the city does with them and what Clementine should — a Phase 2 candidate.

## D. Known unknowns — Phase 3 recon (see `docs/citypay-reference.md`)

1. reCAPTCHA Enterprise v3 token acquisition (a real browser executing the site JS vs. other routes) — deliberately undecided.
2. Zero-violation (clean-plate) response markup — never captured.
3. Checkout POST(s) and the confirmation page — capture the same way the search was captured.
4. Phase 3 scope re-examination (DEC-010) before that phase specs up — now also carrying DEC-065's question: whether a camera violation may appear inside a payment quote.

## E. Operational and logistics

1. **Final message copy** for Welcome / Digest (the Alert is cut — DEC-077) — drafts in `docs/messaging.md`. They must take the 2026-09-20 rewording *before* carrier registration: "tickets" not "parking tickets" (DEC-065), and no nickname slot (DEC-075).
2. **`citypay_probe.rb`** (Ferrum probe from 2026-07-29) — optional; Phase 3 recon only. Keep under `script/` if it is still around.
3. **Trademark search** before anything public-facing; `clementine.nyc` if a domain is ever needed.

## F. Next actions, in order

1. **John:** create the Twilio account, buy a local NYC number, start carrier registration (DEC-079) — longest lead time, runs in parallel with everything below.
2. **Claude:** doc cascade — PRD v0.10, `CLAUDE.md`, `docs/messaging.md`, `docs/open-data-reference.md`, design doc v0.3 (§B above). One commit per doc.
3. **Claude:** `rails new` (Rails 8, Postgres, RSpec, RuboCop, GitHub Actions); move fixtures to `spec/fixtures/open_data/`; fill in the Commands section of `CLAUDE.md`.
4. **Claude → John reviews:** the `subscriptions` migration and model (DEC-076), then the fetch and count against the five fixtures plus synthetic drift, truncation and non-array cases.
5. **Claude → John reviews:** the two send templates, the Twilio sender (21610 handling, no double-send within a run), the `clementine:daily_run` rake task with per-plate isolation, and structured logging per DEC-073 and DEC-078.
6. **Deploy:** Render web + cron + Postgres, env group; live-fire against John's plate and phone; enroll John; start the two-week exit-criteria clock.
