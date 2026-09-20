# Read source: NYC Open Data — Open Parking and Camera Violations (`nc67-uf89`)

Canonical reference for Clementine's Phase 1–2 read path. Everything marked *verified* was observed against real data: the 2026-08-05 sample (132 rows, one plate, 3 open) or live queries on the dates noted. Everything else is marked *per docs* or *unverified*. Decisions this doc restates live in `DECISIONS.md` (DEC-032 to DEC-046).

## Endpoint

- Dataset page: `https://data.cityofnewyork.us/City-Government/Open-Parking-and-Camera-Violations/nc67-uf89`
- SODA 2.1 JSON endpoint: `https://data.cityofnewyork.us/resource/nc67-uf89.json`
- Query by plate + state with SoQL simple filters — `?plate=JPR7462&state=NY` — or `$where=plate='JPR7462' AND state='NY'`.
- **Values are exact-match and case-sensitive** (*verified 2026-08-05*): a lowercase plate returns `[]` with HTTP 200 and no error. Normalize at enrollment: uppercase, strip spaces and dashes (DEC-034).
- **App token:** send as the `X-App-Token` header (or the `$$app_token` parameter) — a managed secret, never committed. Anonymous SODA 2.1 queries still work (*verified 2026-09-19*); Socrata's SODA3, the default for new endpoints since late 2025, requires a token or authentication. Keep the token attached regardless: rate-limit headroom and deprecation insurance.
- **`$limit`:** defaults to 1,000 rows on SODA 2.1 (*per docs*). The dataset returns **full history** per plate, so set an explicit limit and never treat a page of exactly `$limit` rows as complete (open question C3).
- **Sandbox note:** this host is generally unreachable from Claude sandboxes (network allowlist). Run live queries locally; commit responses as fixtures.

## Fields as Clementine uses them

| Field | Type as delivered | Notes |
|---|---|---|
| `plate` | string | Uppercase; query key. *Verified* |
| `state` | string | e.g. `NY`; query key. *Verified* |
| `summons_number` | string | The number printed on the ticket; Phase 2 mirror key. *Verified present* |
| `issue_date` | string, `MM/DD/YYYY` | e.g. `07/20/2026`. *Verified* |
| `violation` | string | Description, e.g. `NO PARKING-STREET CLEANING`, `PHTO SCHOOL ZN SPEED VIOLATION`, `BUS LANE VIOLATION`. Camera discrimination lives here, with `issuing_agency`. *Verified* |
| `issuing_agency` | string | e.g. `TRAFFIC`, `DEPARTMENT OF SANITATION`, `DEPARTMENT OF TRANSPORTATION` (the camera rows in the sample). *Verified* |
| `fine_amount`, `penalty_amount`, `interest_amount`, `reduction_amount`, `payment_amount` | **strings** (`"65"`) | Components only — never recompute the balance from them. *Verified string-typed* |
| `amount_due` | **string** (`"65"`, `"0"`) | The net balance. **Open ⇔ `Integer(amount_due) > 0`.** Paid rows carry `"0"` (even where a reduction applied), not null. *Verified* |
| image field (`summons_image`, *per docs*) | object / URL | Present even on archival rows. *Observed* |

Other published columns (license_type, precinct, county, violation_status, judgment_entry_date, violation_time, …) exist *per docs* but were not exercised; verify before use.

## Row shapes observed

From the 2026-08-05 sample unless noted:

- **Open parking row** — all financial fields present; `amount_due` > 0; `issuing_agency = TRAFFIC`; `violation = NO PARKING-STREET CLEANING` ($65 × 3 in the sample).
- **Paid parking row** — `amount_due = "0"`, `payment_amount` set.
- **Camera row** — `violation = PHTO SCHOOL ZN SPEED VIOLATION`, `issuing_agency = DEPARTMENT OF TRANSPORTATION`. In the sample, issuer separated camera from parking perfectly — but red-light and bus-lane rows were absent. On 2026-09-19 a live query returned `BUS LANE VIOLATION` rows, also DOT-issued. The red-light string remains unobserved.
- **Archival / sparse row** — a 2021 record carrying only plate, state, summons_number, issue_date and the image field: no `violation`, no `issuing_agency`, no amounts. A well-formed record, not a malformed response (DEC-039).
- **Not observed** — any row with `interest_amount > 0` (judgment stage).

## Freshness

Per the dataset's documentation, recorded in PRD v0.6: new violations load **weekly (Sundays)**; satisfied violations clear **daily (Tue–Sun)**; the city separately warns new tickets take days to enter its system at all. Net: new-ticket detection ~1 week typical, ~2 worst; a payment falls out of the count within a day. Daily polling is retained for the satisfied side (DEC-014).

## Classification rules (PRD v0.9 §6, restated for implementation)

1. **Unreachable** — no usable response (timeout, connection failure, non-JSON body, non-2xx after bounded in-run retries) → log, skip this plate today.
2. **Camera blocklist** runs first — drop recognized camera rows. Seed set: `violation` starting `PHTO` (photo school-zone speed) and `BUS LANE VIOLATION`; red light pending observation. Everything else is kept regardless of `issuing_agency`. A row that can't be classified camera-or-not and would change the count → Uncertain.
3. **Open predicate** — `Integer(amount_due) > 0`.
4. **Sparse rows** — no `amount_due` → not-open, skip, log at WARN as residue. A financial row that has *lost* `amount_due` on an otherwise-populated response, or a whole-response shape change → **Uncertain**. The tell is universality.
5. **Outcome** — fully read with zero open → **Clean** (silence); one or more open → **Count** (digest); untrusted read → **Uncertain** (alert; never silent; never "new").
6. **Residue log** — WARN, full raw row, subscription id + plate, never phone: rows skipped as not-open that fit none of the routine cases. Routine paid rows and recognized camera rows are not logged.

## Related

- PRD §5 (constraints), §6 (Phase 1), §10 (risks) — `docs/prd.md`
- Open questions C1–C6 — `docs/open-questions.md`
- CityPay (payment link; Phase 3 checkout) — `docs/citypay-reference.md`
