# Open questions, unknowns and next actions

Pruned 2026-09-20 after the Phase 1 readiness pass (`docs/mvp-readiness.md` Q1–Q12; resolutions in `DECISIONS.md` DEC-064 to DEC-081, corrected at the same-day confirmation pass; docs cascaded the same day). Nothing here blocks building Phase 1. Keep this file current: when an item closes, record the resolution in `DECISIONS.md` and delete it here.

## A. Awaiting John's explicit confirmation or veto

1. **Phase 2/3 proposals carried since PRD v0.4** — quote supersession; the unauthorized-submission definition; Phase 2 ship order (tokenized page before OTP); SIM-swap posture. Confirm when those phases spec up, not before.

*(The design-doc batch P1–P20, amendments A2–A4 and the log-level hierarchy closed on 2026-09-20 — DEC-078.)*

## B. Design doc reconciliation

Done: `docs/phase1-design.md` v0.3, 2026-09-20.

## C. Known unknowns — data

1. **SODA 2.1 deprecation and the app token.** Socrata defaults new endpoints to SODA3, which requires a token or authentication; the SODA 2.1 endpoint (`/resource/nc67-uf89.json`) remains supported and answered an anonymous query on 2026-09-20. Listed as a PRD §10 risk in v0.10; what remains open is confirming the `X-App-Token` header name at build. *(Carried from the 2026-09-19 list.)*
2. **Plate collisions across license types.** *(New, 2026-09-20.)* The query is `plate` + `state` and returns every `license_type` on those characters. John's 136 rows are all `PAS`, so nothing collides today, but NY plate characters can repeat across plate types, and a subscriber's count would then include a stranger's tickets. The direction is safe — it over-counts, never a false clean — and it matches the payment surface, since CityPay's by-plate form defaults `PLATE_TYPE` to "--ALL--". Unverified whether it happens at all. Watch for it in live-fire; if it appears, the fix is a `license_type` column on `subscriptions` and a filter.
3. **`violation_status` and disputed tickets.** *(Corrected 2026-09-20 — the first note called the column unusable; it is not.)* Populated on ~29M rows: `HEARING HELD-GUILTY` 11.3M, `HEARING HELD-GUILTY REDUCTION` 8.8M, `HEARING HELD-NOT GUILTY` 7.1M, `HEARING PENDING` 807K, plus appeal and admin statuses. Socrata omits null keys, which is why no committed fixture row carries it. **`HEARING PENDING` rows carry `amount_due > 0`**, so a ticket under dispute counts as open and is nagged daily in Phase 1 — consistent with no dispute support (DEC-003); Phase 2's dismiss is the relief. Not used in Phase 1.
4. **Small balances.** *(New, 2026-09-20 — John.)* 136 rows carry `0 < amount_due < 1` (e.g. `"0.01"` after a `49.99` payment on a `50` fine); 4,003 carry under `$5`. Most likely interest that accrued between a payment being made and posted (a mailed cheque, a slow medium), and the city may suppress trivial balances itself. Phase 1 treats any amount owed as owed (DEC-064). Later: find out what the city does with them and what Clementine should — a Phase 2 candidate.

## D. Known unknowns — Phase 3 recon (see `docs/citypay-reference.md`)

1. reCAPTCHA Enterprise v3 token acquisition (a real browser executing the site JS vs. other routes) — deliberately undecided.
2. Zero-violation (clean-plate) response markup — never captured.
3. Checkout POST(s) and the confirmation page — capture the same way the search was captured.
4. Phase 3 scope re-examination (DEC-010) before that phase specs up — now also carrying DEC-065's question: whether a camera violation may appear inside a payment quote.

## E. Operational and logistics

1. **Final message copy** for Welcome / Digest (the Alert is cut — DEC-077) — drafts in `docs/messaging.md`. The 2026-09-20 rewording has landed: "tickets" not "parking tickets" (DEC-065), no nickname slot (DEC-075). What remains is John's final wording, written at carrier registration.
2. **`citypay_probe.rb`** (Ferrum probe from 2026-07-29) — optional; Phase 3 recon only. Keep under `script/` if it is still around.
3. **Trademark search** before anything public-facing; `clementine.nyc` if a domain is ever needed.

## F. Next actions, in order

1. **John:** create the Twilio account, buy a local NYC number, start carrier registration (DEC-079) — longest lead time, runs in parallel with everything below.
2. ~~**Claude:** `rails new` (Rails 8, Postgres, RSpec, RuboCop, GitHub Actions); move fixtures to `spec/fixtures/open_data/`; fill in the Commands section of `CLAUDE.md`.~~ **Done 2026-09-22** — issue #2, DEC-084.
3. **Claude → John reviews:** the `subscriptions` migration and model (DEC-076), then the fetch and count against the five fixtures plus synthetic drift, truncation and non-array cases.
4. **Claude → John reviews:** the two send templates, the Twilio sender (21610 handling, no double-send within a run), the `clementine:daily_run` rake task with per-plate isolation and its non-zero exit, and structured logging per DEC-073 and DEC-078.
5. **Deploy:** Render web + cron + Postgres, env group; live-fire against John's plate and phone; enroll John; start the two-week exit-criteria clock.

*(The doc cascade — PRD v0.10, `CLAUDE.md`, `README.md`, `docs/messaging.md`, `docs/open-data-reference.md`, design v0.3 — completed 2026-09-20.)*
