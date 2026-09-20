# MVP readiness review — Phase 1

**Date:** 2026-09-20 · **Reviewer:** Claude (session with John, remote) · **Inputs:** PRD v0.9, design v0.2, DECISIONS.md, open-questions.md, messaging.md, open-data-reference.md, plus live probes against `nc67-uf89` and CityPay run today from John's machine (responses saved under `docs/fixtures/open-data/`).

## Verdict

**Yes — Phase 1 is specified well enough to build.** One table, one rake task, three sends, four outcomes, an invariant that decides every edge case's direction. What remains is short, and today's probes closed most of the data unknowns. The blockers that survive are **one PRD bug** (Q1), **five predicate details** the classifier can't be written without (Q2–Q6), and **John's veto pass** (Q9). Everything else has a workable default.

Nothing below needs new research. It needs answers.

## What today's probes found

All against the live dataset (151,303,530 rows; metadata `rowsUpdatedAt` 2026-09-19). Aggregate group-bys take 30–50 s — probe-only, never in the daily run.

1. **`amount_due` is not always an integer.** Judgment-stage rows carry interest and land on cents: `"93.76"`, `"146.98"`, `"267.13"`. `Integer("93.76")` raises. PRD §6 / DEC-037's "cast to Integer" is wrong as written. (Fixture: `judgment-stage-rows-2026-09-20.json`.)
2. **Judgment rows behave as hoped (C2 closed):** `amount_due` is still the net balance, interest included (`50 + 25 + 18.76 = 93.76`). Paid-in-judgment rows read `"0"`. `judgment_entry_date` is populated on them; `violation_status` exists as a column.
3. **The camera set is enumerable (C1 closed).** Distinct camera-looking `violation` strings in the whole dataset, with counts:

   | `violation` | rows | issuer |
   |---|---|---|
   | `PHTO SCHOOL ZN SPEED VIOLATION` | 38.2M | DOT |
   | `FAILURE TO STOP AT RED LIGHT` | 6.3M | DOT |
   | `BUS LANE VIOLATION` | 4.8M | DOT |
   | `MOBILE BUS LANE VIOLATION` | 0.9M | DOT / TRANSIT AUTHORITY |
   | `MTA CAMERA VIOLATION - PARKING IN A BUS STOP` | 763K | TRANSIT AUTHORITY |
   | `MTA CAMERA VIOLATION - DOUBLE PARKING` | 759K | TRANSIT AUTHORITY |
   | `MTA CAMERA VIOLATION - PARKING IN A BIKE LANE` | 237 | TRANSIT AUTHORITY |
   | `WEIGH IN MOTION VIOLATION` | 7.6K | DOT |

   `NO STANDING-BUS LANE` (335K) is an officer-written parking ticket — keep it. **DOT also writes real parking tickets** (`NO STANDING-OFF-STREET LOT` 23K, `EXPIRED METER-COMM METER ZONE` 18K, `NO STANDING-SNOW EMERGENCY`), which confirms DEC-038: issuer is not a signal; only the `violation` string is.
4. **Open rows with no `violation` string exist** — POLICE DEPARTMENT-issued, `amount_due` `"35"`–`"267.13"`, otherwise fully populated (fixture: `open-rows-missing-violation-2026-09-20.json`). This is the PRD's "can't be classified camera-or-not" case, and it is real.
5. **Sparse rows are 6.4% of the dataset** (9,707,862 with null `amount_due`). On John's plate: 1 of 136, the 6-key archival shape (plate, state, summons, issue_date, image + one more), no financials, no `violation`. Residue re-logging will be routine, as the PRD accepts.
6. **John's plate today: 136 rows, 7 open** (was 132 / 3 on 2026-08-05), all `TRAFFIC`-issued parking. Two of the August three have gained penalties (`$65 → $75`, `$65 → $95`). Every amount on this plate is a whole dollar. *(John — that's four new open tickets since August and two accruing penalties. The product would have texted you.)*
7. **`$limit` above 1,000 works** (`$limit=5000` returned all 136 in 0.3 s).
8. **CityPay has no plate-prefill URL (C6 closed).** `…/citypay/Parking?PLATE_NUMBER=…&PLATE_STATE=…` returns the landing page with an empty form; the `searchResults` path is POST-only (GET → 404). The digest link is the landing page.
9. **Column list confirmed** from dataset metadata: `plate, state, license_type, summons_number, issue_date, violation_time, violation, judgment_entry_date, fine_amount, penalty_amount, interest_amount, reduction_amount, payment_amount, amount_due, precinct, county, issuing_agency, violation_status, summons_image`. Numeric columns are typed `number` in metadata but delivered as JSON strings — the "cast on read" rule stands, just not as an integer.

## Questions John must answer

Each has a recommendation. Answer "default" to take it. Q1–Q6 gate the classifier; Q7–Q8 gate the migration and the send path; Q9 is the standing veto pass.

**Q1 — Open predicate: decimal, not integer.** *Recommend:* `BigDecimal(amount_due) > 0`; a present-but-unparseable `amount_due` is drift → Uncertain. Amend PRD §6 and DEC-037; CLAUDE.md's "cast to Integer" line follows.

**Q2 — Camera blocklist = exact match on `violation` against the eight strings above.** No agency test, no prefix matching (`PHTO` prefix would work today but a constant set is reviewable). Extend the set when a new string appears — the WARN residue log won't catch it (an unrecognized camera string with a balance simply counts as parking, which is the safe direction), so the list is maintained by re-running today's group-by probe occasionally. *Recommend:* the eight, as a frozen constant.

**Q3 — Are the MTA ACE camera tickets "camera"?** `MTA CAMERA VIOLATION - DOUBLE PARKING / PARKING IN A BUS STOP / PARKING IN A BIKE LANE` are parking offences enforced by bus-mounted cameras (TRANSIT AUTHORITY). They follow the camera dispute/penalty track, not the parking one. *Recommend:* blocklist them, consistent with DEC-002's rationale (different schedule, different rules). The cost: a subscriber whose only open item is an ACE ticket hears silence. Same cost already accepted for school-zone speed.

**Q4 — Open row with no `violation` string → count it, don't alert.** Under blocklist semantics an unmatched row is "not recognized camera," so it is kept and counted; the outcome is **Count**, not Uncertain. Over-counting a camera ticket as parking errs toward "go check," never toward a false clean. The alternative — Uncertain — would alert the affected plate every day forever under statelessness. *Recommend:* count it, and log it at WARN as residue-with-balance so the classifier gets an enhancement signal. Amend PRD §6's "routes to Uncertain if it would affect the count" clause.

**Q5 — Drift rule, made operational.** Replace "universality" with two checks: (a) **row-level** — a row that carries any of `fine_amount`, `penalty_amount`, `payment_amount`, `violation`, `issuing_agency` but no `amount_due` key is drift → Uncertain; (b) **response-level** — a non-empty response in which no row carries `amount_due` is drift → Uncertain. A row with none of those keys is the archival sparse shape → residue. *Recommend:* (a) + (b). No percentage thresholds.

**Q6 — Pagination.** *Recommend:* `$limit=5000`; a response of exactly 5,000 rows resolves to Uncertain with the count omitted. No paging code in Phase 1. Family plates run 100–200 rows.

**Q7 — Run-level empty guard (proposed addition, small).** `[]` per plate is Clean. If the dataset were emptied, renamed or replaced, every plate would read Clean at once — a systemic false all-clear that per-plate logic cannot see. *Recommend:* the run first fetches a **canary plate** (a constant; John's own) whose full history is known non-empty. Canary Unreachable → the whole run is Unreachable (skip, log). Canary `[]` → every plate resolves to Uncertain (alert, count omitted). ~10 lines; it is the invariant's guard, not a Phase 2 feature. Say no and it's dropped.

**Q8 — `subscriptions` schema details.** *Recommend:* `phone` (E.164 string), `plate`, `state`, `nickname` (nullable), timestamps; unique index on `(phone, plate, state)`; **no** `active` flag — console removal is `destroy`. STOP is honored by Twilio, surfaces as error 21610 on the next send attempt, logged at WARN; nothing flips in the table.

**Q9 — Veto pass on P1–P20, A2–A4, DEC-045 (log levels).** Pending since 2026-08-05. The ones code touches first: P3 (cron 14:00 UTC), P4 (welcome sent synchronously from console), P8/P9 (fixture-first, JSON), P10 (GitHub Actions), P13 (trunk-based), P15 (env vars), P16 (constants). *Recommend:* accept all as written; A2–A4 land in PRD v0.10 with Q1–Q7.

**Q10 — Retry schedule numbers** (design D5 says "~an hour with backoff"). *Recommend:* attempts at +0, +2 m, +10 m, +30 m — four tries, 42 minutes, then skip. Only Unreachable retries.

**Q11 — Alert count semantics.** "Count survived" = the number of rows with a parseable `amount_due > 0`, taken **before** the camera filter (so the copy "items with a balance" is literally true). It survives whenever the failure was classification (Q4/Q5a on a subset) and is omitted on response-level drift (Q5b, Q6, Q7). *Recommend:* as stated.

**Q12 — A2P 10DLC status?** Unknown in every doc. It gates production sends only, not the build. If not started, it is still the first real-world action.

## Closed today (record in DECISIONS.md with the Q1–Q11 answers)

- C1 camera set enumerated (finding 3). C2 judgment rows (finding 2). C3 `$limit` behavior (finding 7; policy is Q6). C5 column list (finding 9). C6 no CityPay prefill (finding 8).
- E3: the first fixture is committed — `docs/fixtures/open-data/plate-JPR7462-NY-2026-09-20.json` supersedes the uncommitted August sample; move to `spec/fixtures/` when Rails exists.

## Plan

1. **John, one sitting (~20 min):** answer Q1–Q12 above, in the message or inline in this file. Defaults are fine.
2. **Claude, same day:** PRD v0.10 (Q1, Q3–Q7, Q11; A2–A4), `DECISIONS.md` entries, design doc v0.3 reconciliation (open-questions §B), `open-questions.md` pruned to what's actually open, `CLAUDE.md` predicate line, `open-data-reference.md` column table + camera set. One commit per doc.
3. **Claude:** `rails new` (Rails 8, Postgres, RSpec, RuboCop, GitHub Actions), fixtures moved to `spec/fixtures/open_data/`, `CLAUDE.md` Commands section filled. Commit.
4. **Claude → John reviews:** `subscriptions` migration + model (normalization, uniqueness); the classifier (`OpenData::Fetch`, `Classifier`, `RunOutcome`) developed against the five fixtures plus synthetic drift/empty/non-JSON cases. Test surface per P9 + Q1–Q7.
5. **Claude → John reviews:** the three send templates, `Sender` (Twilio, 21610 handling, per-run no-double-send), the `clementine:daily_run` rake task with per-plate isolation and Q10 retries, structured logging per P18/P19.
6. **Deploy:** Render web + cron + Postgres, env group; live-fire against John's plate and phone; enroll John; begin the 2-week exit-criteria clock. In parallel: 10DLC registration if not done.

Steps 3–5 are two or three sessions once step 1 lands.
