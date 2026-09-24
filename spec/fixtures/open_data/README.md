# Open Data fixtures

Real responses from NYC Open Data `nc67-uf89`, pulled live from John's machine during the Phase 1 readiness pass and committed so fetch and count code can be developed against them without touching the network (P8; WebMock blocks all real HTTP in the suite). The data facts they establish are written up in `docs/open-data-reference.md`; the decisions they settled are `DECISIONS.md` DEC-064 to DEC-081.

Base URL for every query below: `https://data.cityofnewyork.us/resource/nc67-uf89.json`.

| File | What it is | Query | Date | What it demonstrates |
|---|---|---|---|---|
| `plate-JPR7462-NY-2026-09-20.json` | John's plate, full history — 136 rows, 7 open, 1 archival, 2 camera | `?plate=JPR7462&state=NY&$limit=5000` | 2026-09-20 | The everyday shape. Open and paid rows, string-typed amounts, `$limit=5000` working (0.3 s), and a run that carries plenty of `amount_due` rows — the assumption behind the run-level drift check (DEC-069, DEC-070) |
| `judgment-stage-rows-2026-09-20.json` | 8 rows that reached judgment | `?$where=judgment_entry_date IS NOT NULL AND amount_due IS NOT NULL&$limit=8` | 2026-09-20 | `amount_due` stays the net balance with interest included (`50 + 25 + 18.76 = "93.76"`) — cents, where `Integer()` raises. Also `judgment_entry_date`, non-zero `interest_amount`, paid-in-judgment rows still reading `"0"`, and both penalty schedules side by side (`25` camera, `60` officer-written) (DEC-064, DEC-066, DEC-080) |
| `open-rows-missing-violation-2026-09-20.json` | 5 open rows carrying no `violation` key | `?$where=violation IS NULL AND amount_due IS NOT NULL AND amount_due != '0'&$limit=5` | 2026-09-20 | Open, NYPD-issued rows with no `violation` at all — counted by construction now that nothing classifies (DEC-065, DEC-068). Also `state = "99"`, the reason a `^[A-Z]{2}$` check constraint would reject real data (DEC-076) |
| `camera-violation-strings-2026-09-20.json` | Aggregate: the camera `violation` strings and their row counts | `?$select=violation,count(*)`, filtered to camera-looking strings | 2026-09-20 | Reference only — **no filter exists in Phase 1** (DEC-065). Recorded so the set is never re-derived, and to show the trap: `NO STANDING-BUS LANE` (335,405 rows) is an officer-written parking ticket any prefix rule would swallow (DEC-067) |
| `dot-issued-violation-strings-2026-09-20.json` | Aggregate: DOT-issued `violation` strings and counts | `?$select=violation,issuing_agency,count(*)`, filtered to `DEPARTMENT OF TRANSPORTATION` | 2026-09-20 | DOT writes ordinary parking tickets — `NO STANDING-OFF-STREET LOT`, `EXPIRED METER-COMM METER ZONE`, `NO STANDING-SNOW EMERGENCY` — so `issuing_agency` never discriminated camera from parking (DEC-067) |

| `state-domain-2026-09-24.json` | The whole `state` domain — 70 values with row counts | `?$select=state,count(*)&$group=state&$order=count DESC` | 2026-09-24 | Every value is exactly two uppercase alphanumerics, including the sentinels `99`, `88`, `DP`, `GV`, `FO` — the evidence that fixed `state ~ '^[A-Z0-9]{2}$'` and ruled out `^[A-Z]{2}$` (DEC-086). **Read by `spec/models/subscription_spec.rb`,** which asserts the constraint accepts all 70 |
| `mixed-case-plates-2026-09-24.json` | 25 open rows whose plate is not all-uppercase | `?$where=plate <> upper(plate) AND amount_due IS NOT NULL AND amount_due != '0'&$order=issue_date DESC&$limit=25` | 2026-09-24 | The inverse of DEC-034's hazard: 204 such rows exist dataset-wide and some are open and recent, so uppercasing at enrollment cannot reach them. An accepted 1-in-735,000 undercount, not a design change (DEC-087) |

Aggregate group-bys against this dataset take 30–155 s (the 2026-09-24 pulls: 47 s for the `state` domain, 85 s for a `like` scan, 155 s for the plate-length distribution); they are probe-only and never run inside the daily job.

**Contents:** public data only — plates, summons numbers, violation descriptions, amounts. No phone numbers appear in any fixture, and none ever should (invariant 8).

**Where this lives:** moved here from `docs/fixtures/open-data/` with the Rails skeleton (DEC-084); the 2026-09-24 pulls were written here directly. The fetch and count specs read these files; nothing here is an Active Record fixture (P8, P9).
