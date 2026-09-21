# Read source: NYC Open Data — Open Parking and Camera Violations (`nc67-uf89`)

Canonical reference for Clementine's Phase 1–2 read path. Everything marked *verified* was observed against real data: the 2026-08-05 sample (132 rows, one plate, 3 open), live queries on the dates noted, or — where marked ***verified 2026-09-20*** — the readiness-pass probes run that day from John's machine, whose responses are committed under `docs/fixtures/open-data/` (see its README). Everything else is marked *per docs* or *unverified*. Decisions this doc restates live in `DECISIONS.md` (DEC-032 to DEC-046, and DEC-064 to DEC-081).

## Endpoint

- Dataset page: `https://data.cityofnewyork.us/City-Government/Open-Parking-and-Camera-Violations/nc67-uf89`
- SODA 2.1 JSON endpoint: `https://data.cityofnewyork.us/resource/nc67-uf89.json`
- Query by plate + state with SoQL simple filters — `?plate=JPR7462&state=NY` — or `$where=plate='JPR7462' AND state='NY'`.
- **Values are exact-match and case-sensitive** (*verified 2026-08-05*): a lowercase plate returns `[]` with HTTP 200 and no error. Normalize at enrollment: uppercase, strip spaces and dashes (DEC-034), enforced by database check constraints (DEC-076).
- **App token:** send as the `X-App-Token` header (or the `$$app_token` parameter) — a managed secret, never committed. Anonymous SODA 2.1 queries still work (*verified 2026-09-20*); Socrata's SODA3, the default for new endpoints since late 2025, requires a token or authentication. Keep the token attached regardless: rate-limit headroom and deprecation insurance (open question C1).
- **`$limit`:** defaults to 1,000 rows on SODA 2.1 (*per docs*), and the dataset returns **full history** per plate, so set it explicitly. Phase 1 sends **`$limit=5000`** (*verified 2026-09-20*: 136 rows in 0.3 s; limits above 1,000 work). A page of **exactly 5,000 rows is truncation** and resolves to **Uncertain** — never treat it as a complete read (DEC-070). No paging code in Phase 1.
- **HTTP mapping** (DEC-071). Timeout, connection failure, **5xx**, **429**, and a body that will not parse as JSON → **Unreachable**. Any **other 4xx** (400, 403, 404) and a **2xx body that parses but is not a JSON array** → **Uncertain**. *Verified 2026-09-20:* an unknown column returns 400 `query.soql.no-such-column`; an unrecognized parameter returns 400; a retired dataset id returns 404. The split is diagnostic — it tells John whether to wait or to fix; both are silent to the subscriber.
- **Socrata omits null keys entirely** (*verified 2026-09-20*): an absent key *is* a null value, which is why key-presence is a usable signal and why no committed fixture row carries `violation_status`.
- **Aggregate group-bys** (`$select=violation,count(*)`) take 30–140 s against this dataset — fine for a probe, never in the run.
- **Sandbox note:** this host is generally unreachable from Claude sandboxes (network allowlist). Run live queries locally; commit responses as fixtures.

## Fields as Clementine uses them

| Field | Type as delivered | Notes |
|---|---|---|
| `plate` | string | Uppercase; query key. *Verified* |
| `state` | string | e.g. `NY`; query key. **Not purely alphabetic** — `"99"` appears in the data (*verified 2026-09-20*), so a two-letter constraint would reject real rows (DEC-076). *Verified* |
| `license_type` | string | e.g. `PAS`. Present on every row, archival included. Not read in Phase 1 — see the plate-collision note (open question C2). *Verified 2026-09-20* |
| `summons_number` | string | The number printed on the ticket; Phase 2 mirror key. *Verified present* |
| `issue_date` | string, `MM/DD/YYYY` | e.g. `07/20/2026`. *Verified* |
| `violation_time` | string | e.g. `10:15A`. Not read in Phase 1. *Verified present* |
| `violation` | string | Description, e.g. `NO PARKING-STREET CLEANING`, `PHTO SCHOOL ZN SPEED VIOLATION`. **Not read in Phase 1** — Phase 1 classifies nothing (DEC-065). Absent entirely on some open rows (see row shapes). *Verified* |
| `judgment_entry_date` | string, `MM/DD/YYYY` | Populated on rows that reached judgment; absent otherwise. Not read in Phase 1. *Verified 2026-09-20* |
| `fine_amount`, `penalty_amount`, `interest_amount`, `reduction_amount`, `payment_amount` | **strings** (`"65"`) | Components only — never recompute the balance from them. *Verified string-typed* |
| `amount_due` | **string** (`"65"`, `"0"`, `"93.76"`) | The net balance, and the only field Phase 1 reads for the count. **Open ⇔ present, non-empty, not `"0"`** (DEC-064). **Never cast:** judgment-stage rows carry cents (`"93.76"`), sub-dollar balances exist (`"0.01"`), and no negative values were observed. Paid rows carry `"0"` (even where a reduction applied), not null. *Verified 2026-09-20* |
| `precinct`, `county` | string | e.g. `006`, `NY`. Not read in Phase 1. *Verified present* |
| `issuing_agency` | string | e.g. `TRAFFIC`, `POLICE DEPARTMENT`, `DEPARTMENT OF SANITATION`, `DEPARTMENT OF TRANSPORTATION`. **Not read in Phase 1** — and it never discriminated anyway: DOT writes ordinary parking tickets (DEC-067). *Verified* |
| `violation_status` | string | Populated on ~29M rows (*verified 2026-09-20*): `HEARING HELD-GUILTY` 11.3M, `HEARING HELD-GUILTY REDUCTION` 8.8M, `HEARING HELD-NOT GUILTY` 7.1M, `HEARING PENDING` 807K, plus appeal and admin statuses. **`HEARING PENDING` rows carry a balance**, so a ticket under dispute counts as open (open question C3). Not read in Phase 1. |
| `summons_image` | object (`description`, `url`) | Present even on archival rows. *Verified* |

**The 19 published columns**, confirmed from dataset metadata (*verified 2026-09-20*, DEC-080 C5): `plate`, `state`, `license_type`, `summons_number`, `issue_date`, `violation_time`, `violation`, `judgment_entry_date`, `fine_amount`, `penalty_amount`, `interest_amount`, `reduction_amount`, `payment_amount`, `amount_due`, `precinct`, `county`, `issuing_agency`, `violation_status`, `summons_image`. Numeric columns are typed `number` in metadata but delivered as JSON strings. This list is the constant behind the run summary's `unknown_keys` count (DEC-069).

## Row shapes observed

From the 2026-08-05 sample unless noted; the 2026-09-20 shapes are in the committed fixtures.

- **Open row** — all financial fields present; `amount_due` non-zero; e.g. `issuing_agency = TRAFFIC`, `violation = NO PARKING-STREET CLEANING` ($65 × 3 in the 2026-08-05 sample; 7 open of 136 rows in the 2026-09-20 pull).
- **Paid row** — `amount_due = "0"`, `payment_amount` set.
- **Judgment-stage row** (*verified 2026-09-20*) — `judgment_entry_date` populated, `interest_amount` non-zero, and `amount_due` **remains the net balance with interest included**: `50 + 25 + 18.76 = "93.76"`. Cents appear here and nowhere else. Paid-in-judgment rows still read `"0"`. This is what killed the integer cast (DEC-064).
- **Open row with no `violation` key** (*verified 2026-09-20*) — NYPD-issued rows carrying `amount_due` (`"35"`, `"146.98"`, `"267.13"`) and no `violation` at all. Counted like any other row; under a classifier they would have been the awkward case (DEC-068, struck).
- **Archival / sparse row** — exactly six keys: `plate`, `state`, `license_type`, `summons_number`, `issue_date`, `summons_image`. No `violation`, no `issuing_agency`, no amounts. About **6.4% of the dataset**, issue dates spanning **2014–2025**, and 2,000 of 2,000 sampled were identical in shape. A well-formed record, not a malformed response (DEC-039): not-open, skipped, WARN residue.
- **Camera rows — reference only.** No filter exists (DEC-065); these are recorded so nobody re-derives them. The `violation` strings and their counts (`camera-violation-strings-2026-09-20.json`):

  | `violation` | Rows |
  |---|---|
  | `PHTO SCHOOL ZN SPEED VIOLATION` | 38,226,890 |
  | `FAILURE TO STOP AT RED LIGHT` | 6,293,024 |
  | `BUS LANE VIOLATION` | 4,823,031 |
  | `MOBILE BUS LANE VIOLATION` | 936,061 |
  | `MTA CAMERA VIOLATION - PARKING IN A BUS STOP` | 762,660 |
  | `MTA CAMERA VIOLATION - DOUBLE PARKING` | 759,076 |
  | `MTA CAMERA VIOLATION - PARKING IN A BIKE LANE` | 237 |

  Two traps a filter would have fallen into: **`NO STANDING-BUS LANE` (335,405 rows) is an officer-written parking ticket** that any prefix or regex rule would wrongly swallow, and **DOT issues ordinary parking tickets** — `NO STANDING-OFF-STREET LOT`, `EXPIRED METER-COMM METER ZONE`, `NO STANDING-SNOW EMERGENCY` (`dot-issued-violation-strings-2026-09-20.json`) — so `issuing_agency` never discriminated (DEC-067). The penalty schedules differ, and that is all they do differently: camera rows (school-zone, red-light, MTA) carry `penalty_amount = 25`, officer-written parking rows carry `60` (DEC-066). Judgment, interest and the CityPay surface are shared.
- **Not observed** — any row carrying a financial field *without* `amount_due`: a full scan for `amount_due IS NULL AND fine_amount IS NOT NULL` returns `[]` (*verified 2026-09-20*). A partial-rename shape does not exist in today's data (DEC-069).

## Freshness

Per the dataset's documentation, recorded in PRD v0.6: new violations load **weekly (Sundays)**; satisfied violations clear **daily (Tue–Sun)**; the city separately warns new tickets take days to enter its system at all. Net: new-ticket detection ~1 week typical, ~2 worst; a payment falls out of the count within a day. Daily polling is retained for the satisfied side (DEC-014).

## Counting rules (PRD v0.10 §6, DEC-064–072)

1. **HTTP first.** Map the response per the endpoint section above: timeout / connection failure / 5xx / 429 / unparseable body → **Unreachable**; other 4xx or a 2xx body that is not a JSON array → **Uncertain**. Both are silent to the subscriber and ERROR in the log.
2. **No classification.** Every row is a candidate. `violation` and `issuing_agency` are not read; there is no camera filter, no blocklist and no row classification anywhere in the run (DEC-065).
3. **Open predicate.** `amount_due` present, non-empty, not `"0"` — carried as the API's string and never cast. Anything unrecognized counts as **open** and logs at WARN without changing behavior (DEC-064).
4. **Sparse rows.** No `amount_due` → not-open, skipped, logged at WARN as residue, full raw row, tagged subscription id + plate, never phone (DEC-043, DEC-044). Never trips Unreachable.
5. **Outcome, and what the subscriber sees.** Fully read with zero open → **Clean** (silence). One or more open → **Count** (digest). Everything else — **Uncertain** or **Unreachable** — sends nothing, logs at **ERROR**, and makes the rake task **exit non-zero** (DEC-071, DEC-077).
6. **Run summary.** One line closing every run: outcomes, sends, duration, `rows`, `rows_with_amount_due`, `rows_without_amount_due`, `unknown_keys`. Two conditions raise it to **ERROR**: `rows > 0` with `rows_with_amount_due == 0` (the column is gone or renamed — the one false all-clear this exists to catch), and `unknown_keys` non-empty (the schema moved). Neither sends anything to a subscriber (DEC-069, DEC-073).
7. **Truncation sentinel.** `$limit=5000`; a page of exactly 5,000 rows → **Uncertain** (DEC-070).
8. **One attempt.** One fetch per plate, 10-second timeout, **no retries** (DEC-072). Per-plate isolation: one plate's failure never affects another's (DEC-046).

## Banked for Phase 2

- **The canary probe** — `?$where=amount_due IS NOT NULL&$limit=1`. *Verified 2026-09-20:* a healthy dataset returns one full row; a renamed column returns 400 `query.soql.no-such-column`; an emptied dataset returns `[]`. It catches the one systemic false all-clear per-plate logic cannot see — a dataset alive but answering `200 []` for every plate. Cut from Phase 1 as not an MVP requirement; the unfiltered first draft was broken anyway, because an unfiltered `$limit=1` deterministically returns an archival row (DEC-074).
- **The Alert send** — no trigger in Phase 1, since system failures reach the maintainer, not the subscriber; it returns where consecutive-day memory and health alerting can gate it (DEC-077).
- **In-run retries** — and they must return as a **two-pass batch** (fetch every plate, collect failures, retry the failed set), because retrying inline per plate costs 42 minutes × N plates (DEC-072).

## Fixtures

Committed under `docs/fixtures/open-data/`, pulled live 2026-09-20; full detail in that folder's README. They move to `spec/fixtures/open_data/` when the Rails app exists.

| File | What it demonstrates |
|---|---|
| `plate-JPR7462-NY-2026-09-20.json` | The everyday shape: 136 rows, 7 open, 1 archival, 2 camera |
| `judgment-stage-rows-2026-09-20.json` | Cents in `amount_due`, interest, `judgment_entry_date`; both penalty schedules |
| `open-rows-missing-violation-2026-09-20.json` | Open rows with no `violation` key; `state = "99"` |
| `camera-violation-strings-2026-09-20.json` | The camera strings and counts — reference only, no filter exists |
| `dot-issued-violation-strings-2026-09-20.json` | DOT writes ordinary parking tickets, so the issuer carries no signal |

## Related

- PRD §5 (constraints), §6 Phase 1 (predicate, outcomes, sends), §7 (observability), §10 (risks) — `docs/prd.md`
- Open questions C1–C4 — `docs/open-questions.md`
- CityPay (payment link; Phase 3 checkout) — `docs/citypay-reference.md`
- Decisions DEC-064 to DEC-081 — `DECISIONS.md` §9
