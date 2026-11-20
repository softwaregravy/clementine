# Clementine — PRD v0.11
*Formerly PlateWatch.*

**Owner:** John · **Status:** Draft for review · **Last updated:** 2026-09-24

## Changelog — v0.10 → v0.11

Implementation of the `subscriptions` table (issue #3). Resolutions live in `DECISIONS.md` **DEC-086 and DEC-087**; that log binds, this changelog summarizes. §6 Phase 1 is the only section that moves.

**Decided this session:**

- **The check-constraint patterns are fixed, and `phone` gains one.** v0.10 said the patterns were "fixed at implementation against the observed domain"; they now are — `plate ~ '^[A-Z0-9]{1,10}$'` and `state ~ '^[A-Z0-9]{2}$'`, against a live pull of both query-key domains rather than the fourteen distinct plates the fixtures hold. **A third constraint on `phone`** (`^\+[1-9][0-9]{7,14}$`) extends the two DEC-076 named: E.164 was already the column's stated type, a mistyped phone is a send to someone who never subscribed (invariant 2), and the console is the only enrollment path. It rejects a bare ten-digit number rather than inferring `+1`. (DEC-086; extends DEC-076.)
- **Mixed-case plates in the city's data are an accepted undercount.** 204 rows dataset-wide carry a plate that is not all-uppercase, some of them open and recent. Uppercasing at enrollment cannot reach them, so such a row is invisible to the count — a false all-clear if it is a plate's only open row. At 1 in 735,000 against a population under 20 plates, and against a case-insensitive alternative measured at 45 s under a 10 s timeout, it is accepted and recorded, not engineered around; it is banked for Phase 2. The finding confirms DEC-034's uppercasing rather than arguing against it. (DEC-087.)

**Nothing proposed this session.**

## Changelog — v0.9 → v0.10

Phase 1 readiness pass (2026-09-20) against five live API pulls, committed under `docs/fixtures/open-data/`, followed by a same-day confirmation pass with John. Resolutions live in `DECISIONS.md` **DEC-064 to DEC-081**; that log binds, this changelog summarizes. The through-line of the pass: **maximum permissiveness and minimum classification in Phase 1** — carry the API's values as they arrive, count anything that might be money owed, and spend the remaining care on the two places where a wrong answer is silent. Superseded text is rewritten in place, not preserved.

**Decided this session:**

- **Open predicate is a string test.** `amount_due` is carried exactly as the API delivers it and **never cast**: open ⇔ present, non-empty, not `"0"`. The integer cast was wrong twice over — judgment-stage rows land on cents (`"93.76"`), where `Integer()` raises, and nothing in Phase 1 consumes a number. Anything unrecognized counts as **open** and logs WARN without changing behavior. Any amount owed is owed: a penny balance is one open ticket. (DEC-064; supersedes DEC-037.)
- **Scope is every violation the city says is owed on the plate.** Parking was the *minimum* scope, not a ceiling. Phase 1 **classifies nothing** — no camera filter, no blocklist, and `violation` and `issuing_agency` are not read. Camera-specific *features* stay out (dispute handling, camera deadline math); camera *rows* do not. Copy says "tickets", never "parking tickets". (DEC-065; supersedes DEC-002, retires DEC-038; DEC-066–068 struck.)
- **Schema drift is a run-level check, not per-row logic.** The run summary carries `rows`, `rows_with_amount_due`, `rows_without_amount_due` and `unknown_keys`; rows present with none carrying `amount_due`, or any key outside the dataset's 19 published columns, raises the summary to **ERROR**. Sparse rows stay not-open, skipped, WARN residue. (DEC-069; amends DEC-039.)
- **Fetch is one attempt per plate, 10-second timeout, no retries.** `$limit=5000`, and a response of exactly 5,000 rows is truncation → Uncertain. No canary in Phase 1. Per-plate isolation unchanged. (DEC-070, DEC-072, DEC-074; supersedes DEC-052's retry model and amendment A1.)
- **HTTP failures split, and both halves are silent to the subscriber.** Timeout, connection failure, 5xx, 429 and a body that will not parse as JSON → **Unreachable**; any other 4xx and a 2xx body that parses but is not a JSON array → **Uncertain**. Both log at ERROR and the rake task **exits non-zero**, so a failed morning shows as a failed run in Render's cron dashboard. System failures alert the maintainer, never the user — the user cannot fix the system. (DEC-071; amends DEC-041.)
- **No Alert send. Two send types: Welcome and Digest.** With classification gone, Uncertain arises only from system failure, and system failure is the maintainer's business — so the Alert has no trigger. Its template is banked for Phase 2, where consecutive-day memory and health alerting can gate it. What the first invariant now means: a broken read is never *recorded* as Clean and never produces a digest, but to a subscriber Uncertain looks like Unreachable — silence. "Silence means clean" becomes "silence means clean, or the system is broken and John knows." (DEC-077; supersedes DEC-029 for Phase 1.)
- **Errors are structured logs only; the one-table rule holds.** One JSON line per plate outcome (subscription id, plate, state, outcome, reason code) plus a run summary (outcomes, sends, duration, the drift counts). Levels: INFO routine; WARN residue skips, unrecognized `amount_due` strings and a Twilio 21610 on a send; ERROR both Uncertain and Unreachable. Never a phone number. (DEC-073, DEC-078; DEC-045 decided in corrected form.)
- **`subscriptions` is phone, plate, state, timestamps.** **No nickname** and no `active` flag; unique on (phone, plate, state); database check constraints on `plate` and `state`, with exact patterns fixed at implementation (the data contains `state = "99"`). Console removal is `destroy`; STOP is Twilio's, surfacing as error 21610 at send time. (DEC-075, DEC-076; amends DEC-013.)
- **Veto pass complete.** P1–P20 and amendments A2–A4 accepted as written: cron at 14:00 UTC, welcome sends synchronously from the console, fixture-first with WebMock, GitHub Actions on every push, trunk-based, env-var secrets, dev + prod only. (DEC-078; closes DEC-055 and DEC-056.)
- **Twilio is step zero.** No account exists as of 2026-09-20: account → local NYC number → A2P 10DLC on the sole-proprietor path, running in parallel with the build. Two sample messages. (DEC-079.)
- **Accepted risks, named rather than implicit** (§10): sustained-outage silence and empty-dataset silence (DEC-081, DEC-074); small balances count (DEC-064); a ticket under dispute counts (open-questions C3); plate collisions across license types (C2); SODA 2.1 deprecation (C1).
- **Closed by live probes** (DEC-080): judgment rows keep `amount_due` as the net balance with interest; `$limit` above 1,000 works; the 19-column list is confirmed; CityPay has no plate-prefill URL, so the digest links to the landing page.
- **Drift mechanics — added at the cascade review, 2026-09-21.** The daily run is **two-pass** — fetch every plate, run the drift check, then resolve and send — so the run-level check precedes every outcome line and every send. No row in the whole run carrying `amount_due` resolves every fetched plate to **Uncertain** (reason `drift`) with no sends; unknown keys alone leave outcomes and digests untouched and raise the summary to ERROR; either condition fails the run. Makes DEC-069, DEC-071 and DEC-077 mechanically consistent — a per-plate loop that sends as it goes had already logged every plate Clean by the time the check could fire. (DEC-082.)

**No proposed items remain from this pass** — every item above is decided. The Phase 2/3 proposals carried since v0.4 are unchanged; they are listed in the v0.8 → v0.9 changelog below and confirm when those phases spec up.

---

## Changelog — v0.8 → v0.9

Reality pass against live API output (2026-08-05, following v0.8's definition pass same day). A real `nc67-uf89` response — 132 rows for a single plate, 3 open — was analyzed and used to pin the predicates v0.8 explicitly deferred and to elevate one invariant to first-class. Superseded text is not preserved inline; this changelog is the record.

**Decided this session:**

- **Sample validates §5's field claims.** The 132-row pull confirms summons_number, amount_due, issue_date present; violation-type discrimination present. Amounts arrive **string-typed** (`"65"`, not `65`) — the integer cast is load-bearing, not cosmetic. The dataset returns **full history**, including archival rows with **no financial fields at all** (observed: a 2021 row carrying only plate/state/summons/issue-date/image).
- **"Open" predicate pinned.** A row is open when `amount_due`, cast to integer, is **> 0**. `amount_due` is the net balance already — read directly, never recomputed from fine/penalty/reduction/payment. (Resolves the §6 "pin against the live sample" note for the predicate.)
- **Phase 1 outcome model replaces the two-state parse-safety.** Four outcomes, determined **per plate, per run**: **Clean** (read fully, zero open → silence), **Count** (read fully, ≥1 open → digest), **Uncertain** (usable response but the open/type read can't be trusted → alert, never silent), **Unreachable** (no usable response → log, skip, tomorrow covers). The load-bearing invariant: **a row we cannot evaluate can never produce a Clean.**
- **Uncertain is first-class, and a third send type.** §6's "two send types, there are no others" becomes three: Welcome, Digest, and **Alert**. The Alert is the "we see activity we couldn't read — go check" message; it carries the count when the count survived the failure and omits it when it didn't. It never says "new" — statelessness can't distinguish new from known-open.
- **§9 broadened.** "0 false all-clears" now covers failed, malformed, **or uninterpretable** responses; the Uncertain alert is the named mechanism that makes it first-class rather than aspirational.
- **Camera filter = camera-side blocklist (not a parking-issuer allowlist).** Recognized camera-enforcement rows are excluded; every other row is kept regardless of issuing agency. An allowlist of parking issuers (TRAFFIC + SANITATION) was rejected because it silently drops parking tickets written by agencies outside that set (e.g. NYPD) — a false clean, the exact failure the product exists to prevent. The recognized-camera set is seeded from the sample (photo school-zone speed, DOT-issued) and extended as red-light/bus-lane examples appear; exact predicate is a design-doc detail.
- **Sparse-row disposition.** A partial row is a well-formed record, **not** a malformed response (never trips Unreachable). A row with no `amount_due` reads as **not-open** and is skipped (and logged, below). But a row that *should* carry financials and has **lost** `amount_due` on an otherwise-populated response is **drift → Uncertain**, not a silent skip. The tell is **universality**: one empty row among many is archival noise (skip + log); every row losing the field is a rename (Uncertain, alert). A whole-response shape change never resolves to Clean. Failure direction is safe — misfires err toward "go check," never toward a false clean.
- **Retries scoped to Unreachable only.** Re-fetching does not fix a schema that changed, so Uncertain does not retry — it alerts. Total unreachability stays **silent per the 24h SLA** (skip, log, tomorrow covers) — no "couldn't check today" send.
- **Skip-logging (instrumentation, not a fifth outcome).** The unclassifiable residue — rows skipped as not-open that fit none of the routine cases — is logged at **WARN**, full raw row, tagged subscription id + plate (no phone; the row carries none). Routine paid rows and recognized camera rows are **not** logged. Statelessness means the same residue row re-logs every day — accepted at slow scale; row-level dedup is a Phase 2 capability. The WARN denotes a **standing condition** ("a shape exists the classifier can't handle — build an enhancement"), not a fresh per-run incident; a run with a logged skip still resolves to Clean or Count.

**Proposed / derived this session — strike if it overreaches:**

- **Log-level hierarchy.** INFO for routine (run outcome + every send, per P18); **WARN** for the residue skip-log and for a single Unreachable run; **ERROR** for an Uncertain outcome (an active degradation that fired a user-facing "go check" this run). Gives the levels operational meaning; exact assignment is a design-doc detail.

**Proposed, not yet explicitly confirmed** — all Phase 2/3 material, unchanged from v0.4, to be confirmed when their phases spec up:

- **Quote supersession:** a newer quote invalidates an unanswered older one; PAY always binds to the most recent quote.
- **Unauthorized submission** defined as any CityPay submission lacking a matching, valid authorization text — registered number, matching quote (tickets + amounts), not already executed.
- **Phase 2 internal ship order:** tokenized read-only results page may ship before OTP; OTP lands with dismiss.
- **SIM-swap posture:** text authorization accepts phone-possession risk at family scale; profile and payment-method changes require the authenticated page, never text.

**Still open (§11):** nothing blocking. Standing note: the *design doc* (v0.2) still describes the CityPay-scraper read path throughout — it predates the v0.8 API pivot — and needs its own reconciliation pass; not folded here.

---

## 1. Problem

Street-parked vehicles in NYC accumulate parking tickets the owner may never see — paper tickets blow away, and cars sit untouched between alternate-side moves. Miss the windshield copy and the first real signal is often a penalty notice: NYC adds a late fee at day 30, more at days 60 and 90, and enters judgment (with interest and boot/tow exposure) around day 100. The fix is boring but hard to do manually: check the city's system regularly and pay on time.

## 2. Goal

A small multi-user service that ships in three stages:

1. **Text** — a daily SMS digest of open NYC violations on each registered plate, with a payment link,
2. **Page** — our own per-plate results page for viewing and managing tickets, and
3. **Pay** — submits payment to CityPay **on the user's behalf** after an explicit, logged text authorization — **never autonomously**.

Clementine is not a payment processor: it never holds or moves funds. Money flows directly from the user's bank or card to NYC DOF via CityPay; Clementine acts as the user's agent at checkout.

**Solicited by design.** Clementine exists to send messages — and never sends one that wasn't asked for. Solicitation operates at the subscription level, not per message: signing up *is* the request to receive notifications, nobody is enrolled who didn't ask, the welcome restates the contract, and STOP is honored natively and immediately. This is not a spam bot with a good excuse; it is a system whose entire capability is delivering helpful messages to people who requested them. It is also the product's lane — the city's official channel for individuals is paper and silence (DOF publicly warns it will never text a payment reminder), the fraudulent channel is unsolicited by definition, and Clementine occupies the third position: warnings you signed up to receive, from a sender you know, before deadlines bite.

**Why it exists.** Clementine is primarily a learning vehicle — an exercise in AI-assisted product development by its author — that earns its keep by being genuinely useful to the author and an invited circle. It is not a commercial venture: no billing, no growth ambitions (§3 stands). Competitors in the category are read as market validation, not threat; at this scale the moat is trust — your phone number and plate go to someone you know, not to a service.

Success looks like: nobody on the system ever pays a late penalty again.

## 3. Users & scale

- Invite-only: John plus family and friends. Target **< 20 users in year one**.
- In Phase 1 a "user" is a subscription row — phone + plate + state, and nothing else (no nickname — DEC-075); accounts materialize in Phase 2. Multi-plate and multi-phone from day 1 — two subscribers to one plate each get the digest, and the plate is polled once.
- John is the sole admin, console-first: invites, plate removal, and inspection happen in the Rails console until Phase 2 adds health alerting.
- No self-serve signup, no billing, no marketing.

## 4. Scope

**In:** **every violation the city says is owed on a registered plate** — parking, camera, anything — counted and linked, end to end across the three phases: text → page → pay. Parking is the motivating case, not a boundary: the count is every row with a balance, whatever wrote it, and Phase 1 reads neither `violation` nor `issuing_agency` (DEC-065).

**Out:**
- **Camera-specific features** — dispute tracks, camera deadline math. Camera *rows* are counted like every other row; camera *features* stay out (DEC-065, with DEC-003 and DEC-018).
- **Dispute support of any kind.** A ticket the user doesn't want to pay is simply never authorized; Phase 2's **dismiss** silences it. The product takes no position on disputes.
- Payment processing (see §2 — agent, not processor), other cities, native mobile apps, payment plans / judgment-debt handling.

Whether a camera violation may appear inside a Phase 3 payment quote folds into the Phase 3 scope re-examination (DEC-010, §11).

## 5. External constraints (verified July 2026; read source, payment channels & landscape re-verified 2026-08-05; field structure verified against live sample 2026-08-05)

- **Sole read source (decided 2026-08-05, supersedes 2026-08-02):** NYC Open Data **"Open Parking and Camera Violations"** — dataset `nc67-uf89`, Socrata SODA API, JSON over plain HTTPS, queried by `plate` + `state` (values exact-match, uppercase). App token attached (managed secret) for rate-limit headroom. **Field needs, phase-tiered — now verified against a live 132-row pull (single plate, 3 open):** P1 — enumerable rows with a readable `amount_due`: **present**; no type discrimination is needed (DEC-065). Open-ness is a string test on `amount_due` — present, non-empty, not `"0"` (DEC-064); values arrive as **strings** and are never cast, and judgment-stage rows carry cents. The response returns **full history**, including archival rows with no financial fields. P2 — summons number, amount due, issue date: **present**. P3 — authoritative amounts at execution: **not this dataset** — a weekly-lagged export is never the money authority; amounts bind at CityPay checkout at execution time, as §6 Phase 3 always required.
- **Data freshness.** New violations load **weekly (Sundays)**; satisfied violations clear **daily (Tue–Sun)**; the city separately warns new tickets take days to enter its system at all. Net: new-ticket detection typically ~1 week, worst ~2, after issuance; a payment falls out of the count within a day. The **welcome message** carries the caveat (the digest stays minimal).
- **Deadlines (parking violations).** Pay or dispute within **30 days of issuance** or penalties accrue: **+$10 at day 30, +$20 at day 60, +$30 at day 90; judgment around day 100** (interest begins; boot/tow exposure above $350 in judgment debt). → Deadline math is absent from Phase 1 by design (count-only digest); countdown surfaces on the Phase 2 page; urgency messaging is Phase 3, spec later. (Camera violations carry a different penalty schedule — a flat $25 in the data — which is why camera-specific deadline math stays out even though the rows are counted.)
- **Payment channels (re-verified 2026-08-05).** CityPay web (the city's recommended option), the official "NYC Pay or Dispute" mobile app, an automated phone payment line, mail, or in person. **No public payment API.** eCheck carries no fee; cards add a ~2% service fee. Automation alternatives to the web UI were examined and rejected: the mobile app is a private undocumented API to the same backend (brittle and adversarial to automate for money movement); the phone line routes card data through our telephony (processor territory, and no eCheck); programmatic mail (check-printing services) makes Clementine the account of origin (processor again) and adds 2–3 weeks of processing against deadline clocks; DOF's fleet programs (Regular Fleet / Stipulated Fine / Commercial Abatement) require commercial enrollment and trade away hearing rights — wrong shape for family plates. → Phase 3 remains **headless-browser automation of CityPay checkout**, and **eCheck is the default stored method**.
- **Landscape (verified 2026-08-05).** No official proactive ticket alerting exists for individuals: the Pay or Dispute app is pull-only lookup/pay/dispute — saved plates save typing, not a subscription — and the only official monitoring, the fleet programs' weekly consolidated statements, is gated on commercial enrollment. Independent plate-monitoring services exist (lookup tools and text-alert services), almost certainly on this same dataset and so inheriting the same weekly lag; none visibly performs authorized agent payment. Read as market validation. Clementine's differentiation at family scale is trust and the Phase 3 arc, not features. DOF publicly disclaims ever sending unsolicited payment texts → see §10 scam adjacency.
- **Carrier registration (added 2026-08-04; status recorded 2026-09-20).** US application-to-person SMS requires A2P 10DLC brand/campaign registration — or toll-free number verification — through Twilio before production sends. Registration wants a use case, sample messages (**two** templates — welcome, digest; the Alert is cut from Phase 1, DEC-077), and an opt-in description (console enrollment of consenting family — the solicited-by-design story, §2). Approval lead time is days to weeks → it opens M1. **Number type (A3, accepted — DEC-078):** A2P 10DLC, a local NYC number, sole-proprietor path (DEC-027). **No Twilio account exists as of 2026-09-20** — creating the account, buying the number and registering is **step zero**, and it runs in parallel with the build (DEC-079).

## 6. Phases

### Phase 1 — Text *(stateless daily count)*

- **Data:** `subscriptions` — `phone` (E.164), `plate`, `state`, timestamps — console-managed, unique on (phone, plate, state). **No nickname** (DEC-075): the plate is the name everywhere it appears. **No `active` flag** — console removal is `destroy`, and STOP is Twilio's (DEC-076). Plates normalized (uppercase, no spaces/dashes) at enrollment and enforced by **database check constraints** on `phone`, `plate` and `state` — patterns fixed against a live pull of the query-key domains and hand-reviewed with the migration: the data contains `state = "99"`, so the obvious two-letter constraint would reject real rows (DEC-076, DEC-086). The constraints are load-bearing, not belt-and-braces: a lowercase plate reads Clean forever (invariant 1) and a mistyped phone texts a stranger (invariant 2). Nothing else persists — no ticket memory, no send markers, no accounts. The run summary and the residue log add **no tables** — both are log-only.

- **Open predicate:** `amount_due` is carried as the API's string and **never cast**. A row is open when `amount_due` is **present, non-empty and not `"0"`** (DEC-064). It is the net balance already (fine + penalty + interest − reductions − payments), so it is read directly, never recomputed. Anything unrecognized — `"0.00"`, `"-25"`, `"abc"` — counts as **open** and logs at WARN *without changing behavior*, so drift is discovered rather than absorbed; the direction is the one the invariant wants. Judgment-stage rows land on cents (`"93.76"`), which is what killed the cast. **Any amount owed is owed:** a penny balance is one open ticket.

- **Run outcome model — per plate, per daily run.** Four outcomes, and the boundary between the first and third is the invariant:
  - **Clean** — response read in full, zero open rows → **no send**. Silence means clean.
  - **Count** — response read in full, ≥1 open row → **Digest** with the number.
  - **Uncertain** — a usable response the run cannot trust: a page of exactly 5,000 rows (truncation), a non-transient 4xx, a 2xx body that parses but is not a JSON array, or the run-level drift signal — no row in the whole run carrying `amount_due` (DEC-082) → **no send; ERROR log; the run exits non-zero.**
  - **Unreachable** — no usable response (timeout, connection failure, 5xx, 429, a body that will not parse as JSON) → **no send; ERROR log; the run exits non-zero**; tomorrow covers, per the 24h SLA.
  - **Invariant (load-bearing):** *a row we cannot evaluate can never produce a Clean.* It holds **in the record** — the run never logs a broken read as Clean and never sends a digest from one, and Clean and Uncertain are never confused. To a subscriber, Uncertain and Unreachable are both silence; the maintainer's ERROR log and the failed cron run are the signal. "Silence means clean" becomes "silence means clean, or the system is broken and John knows" (DEC-071, DEC-077, DEC-081).

- **No classification:** every row with a balance is counted, regardless of `violation` or `issuing_agency` — **neither field is read**. There is no camera filter, no blocklist and no row classification anywhere in the run (DEC-065). Classification was the only judgment code in the run, so removing it removes a failure surface; the digest promises a number and a link, and CityPay shows every violation on the plate the moment the subscriber taps through.

- **Sparse / financially-empty rows:** the dataset returns full history, including archival rows with no financial fields — a single six-key shape (plate, state, license_type, summons_number, issue_date, summons_image) spanning 2014–2025, about 6.4% of the dataset. Disposition:
  - A partial row is a well-formed record, **not** a malformed response — it never trips Unreachable.
  - A row with **no** `amount_due` reads as **not-open** and is skipped (and logged — see below): we can't assert a balance we can't see.
  - **Drift is a run-level check, not per-row logic** (DEC-069). The run summary counts `rows`, `rows_with_amount_due`, `rows_without_amount_due`, and `unknown_keys` — keys seen outside the dataset's 19 published columns. Two conditions raise the summary to **ERROR**: rows present with **none** carrying `amount_due` (the column is gone or renamed — the one false all-clear this exists to catch), and `unknown_keys` non-empty (the schema moved, look). Neither sends anything to a subscriber. The check runs after every plate is fetched and before any outcome is resolved or sent (DEC-082): the first condition resolves every fetched plate to **Uncertain** (reason `drift`) — no sends, no Clean in the record; the second leaves outcomes untouched and digests flowing, because `amount_due` is still readable. Either condition fails the run.
  - Run level is what makes this safe: an *individual* plate can be all-archival, but the *run* always carries `amount_due` rows while the column exists. It assumes at least one enrolled plate with financial history — true from day one.

- **Skip-logging (instrumentation, not a fifth outcome):** the unclassifiable residue — rows skipped as not-open that fit none of the routine cases (a readable `amount_due`) — is logged at **WARN**, full raw row, tagged subscription id + plate (no phone; the row carries none). Routine paid rows are **not** logged. Statelessness means the same residue row returns and re-logs **every day** — accepted at slow scale; row-level dedup is a Phase 2 capability (the violations mirror). The WARN denotes a **standing condition** — "a row shape exists the run can't yet account for, build an enhancement" — not a fresh per-run incident; structured logs filter/dedup at read time. **A run with a logged skip still resolves to Clean or Count.**

- **Two send types, both templated; there are no others:**
  - **Welcome** — on console enrollment: identifies Clementine, echoes **plate + state**, states the contract (morning text when open tickets exist; silence means clean; new tickets can take a week or more to appear in the city's data), STOP/HELP footer. Doubles as the wrong-plate tripwire — the echo arrives while enrollment is fresh.
  - **Digest** — daily ~09:00 ET, only when open tickets exist: count of open tickets, plate, state, CityPay plate-search link. No amounts, no dates — the link carries the detail. **Never claims "new"** — statelessness can't distinguish new from known-open; the words are "open" / "outstanding." Never "parking tickets" either: the count includes every violation with a balance (DEC-065). (The link stays CityPay: that's the *payment* surface; the API is our read path, not the user's.)

  The **Alert** introduced in v0.9 is **cut from Phase 1** (DEC-077) and banked for Phase 2. System failures alert the maintainer through the ERROR log, never the subscriber, and with classification gone there is no other Uncertain trigger — so the Alert has no trigger left.

- **Job:** once daily at **14:00 UTC** (09:00 EST / 10:00 EDT — A4), in two passes (DEC-082). **Pass one, per distinct plate (plate + state):** **one fetch**, 10-second timeout → Unreachable (log at ERROR) or Uncertain on an untrustworthy response (log at ERROR), else a page of rows. **Then the run-level drift check** over every fetched row (DEC-069). **Pass two, per fetched plate:** apply the open predicate to every row (residue skip-log for rows with no `amount_due`) → resolve **Clean** (no send), **Count** (digest to every subscribed phone for that plate), or **Uncertain** (log at ERROR, no send) → close with the **run summary line**. The task **exits non-zero** if any plate ended Uncertain or Unreachable, or the summary is ERROR. Per-plate isolation: one plate's Uncertain or Unreachable never affects another's; only the run-level drift check speaks for every plate at once.

- **No tickets → no text.** Silence means clean — the Clean outcome, stated in the welcome, guarded by the invariant above.

- **Retries: none in Phase 1** (DEC-072). One fetch attempt per plate; an Unreachable plate is skipped for the day, logged at ERROR, and the 24h SLA absorbs it — a transient blip costs a plate one day instead of two minutes, which is deliberate MVP reliability debt, not an oversight. Uncertain would not retry in any case: re-fetching won't fix a schema that changed. Retries return in **Phase 2** with Solid Queue, and must return as a **two-pass batch** — fetch every plate once, collect the failures, retry the failed set — because retrying inline per plate costs 42 minutes × N plates.

- **Accepted noise:** open tickets re-text daily until satisfied (the nag is arguably a feature); a manual re-run after a partial send can double-text; **no urgency gradient** — a day-5 ticket and a day-28 ticket read identically, escalation is repetition; residue rows re-log at WARN daily under statelessness; a **penny balance counts as one open ticket** (DEC-064); a ticket **under dispute counts as open** and is nagged daily (`HEARING PENDING` rows carry a balance — open-questions C3; Phase 2's dismiss is the relief); and a **multi-day outage is silent to subscribers** (DEC-081). All fine at family scale; all end (or gain dedup) with Phase 2.

- **Opt-out:** STOP/HELP auto-handled by Twilio; a stopped subscriber goes silent and surfaces on the next send attempt as **Twilio error 21610**, logged at WARN, with nothing flipping in the table (DEC-076); START plus console to resume.

- **Etiquette:** the read path is a public data API built for programmatic access — token attached, back off on 429/5xx, tens of requests/day. (Scraping posture — stop-on-captcha — moves to Phase 3, where the browser lives.)

- **Exit criteria:** welcome received on a fresh enrollment; 2+ weeks of clean daily operation on real plates; at least one real ticket detected with an accurate count and a working link; a forced unreadable-or-drift condition produces an **ERROR log line and a failed run** — never a Clean, never a send; a residue row logs at **WARN** without suppressing a real count or producing a false clean; no unexplained double-sends — all verified in logs, there being no UI.

### Phase 2 — Page *(persist, display, manage)*

- **Persistence begins:** `violations` mirror (unique `summons_number`, type, `issue_date`, amounts, status, raw payload, `first_seen_at`). Ticket memory ends the noise era: digests distinguish new from known-open, send dedup becomes possible, and residue rows dedup instead of re-logging daily. Three Phase 1 cuts return here, gated on that memory and on health alerting: the **Alert send** (DEC-077), the **canary probe** — `?$where=amount_due IS NOT NULL&$limit=1` (DEC-074) — and **in-run retries**, as a two-pass batch (DEC-072).
- **Results page** per plate: open tickets, amounts, deadline countdown, last-polled time — the product's first per-ticket detail surface. The digest link swaps from CityPay to this page.
- **Refresh:** poll-on-login plus a manual refresh button.
- **Auth:** SMS OTP, phone-first (ratified). Subscriptions graduate to user-owned plates. Optional internal ship order: tokenized read-only page first (plate data is public anyway); OTP lands with dismiss — the first write worth protecting.
- **Dismiss:** persists a dismissed set per plate; dismissed summonses leave the digest and the page. Silence, not action — no dispute machinery.
- **Admin:** console remains primary; add poll-health visibility and an alert to John after N consecutive failures (the system's first alerting).
- **Exit criteria:** page live behind OTP; a dismissed ticket vanishes from the next digest; a satisfied ticket drops off after the next poll; a forced failure fires the health alert.

### Phase 3 — Pay *(authorize by text, submit, confirm)*

*Scope flagged for re-examination against the solicited-by-design principle and the landscape findings before this phase specs up (§11), including whether camera violations may appear in a quote (DEC-065). The spec below stands until then.*

- **Payment profile (first run):** the first PAY intent routes to an authenticated setup page — legal name, email, billing address, payment method (eCheck default: routing + account; card optional, ~2% fee). Vaulted: encrypted at rest with KMS-managed keys; never logged; never re-rendered in full. After setup, authorization is pure text.
- **Quote:** SMS itemizing every outstanding ticket and its amount, plus the total, ending in the authorization prompt (reply **PAY**). A newer quote supersedes an unanswered one.
- **Messaging (spec later):** richer status copy — e.g. "4 are overdue, and 1 more goes overdue in 3 days" — is Phase 3 material, spec'd alongside the quote flow.
- **Hard rule: no submission ever executes without a logged authorization transaction, and every authorization is preceded by a quote itemizing each ticket and amount it covers.** One transaction record; per-ticket line items beneath it.
- **Amount binding, transaction-level:** if any ticket's amount at execution differs from its quoted amount, the entire transaction aborts and a fresh quote goes out immediately. (Execution amounts come from CityPay at checkout — never from the lagged read source.)
- **Submission:** headless browser drives CityPay checkout with the vaulted method. Agent, not processor.
- **Confirmation of actions taken** (not a "receipt"): SMS + email immediately after submission — tickets, amounts, timestamp, and CityPay's confirmation number as the pointer to the authoritative record. The ticket is verified satisfied on a subsequent daily poll (satisfied-side refresh is daily).
- **Failure handling:** bounded retries with backoff; on persistent failure, immediate SMS + email with a CityPay deep link for manual payment. Never silent.
- **Unauthorized submission** — any execution without a matching, valid authorization (registered number; matching quote; not already executed) — is a critical incident: immediate user + admin alert, logged separately from ordinary risk events.
- **Send timing:** post-hoc sends (confirmation, failure, unauthorized-submission alert) go immediately at any hour; only the scheduled daily digest holds to the morning slot.
- **Audit log:** quote, authorization, every execution attempt, and outcome — immutable, admin-visible, transaction-level with per-ticket line items.
- **Exit criteria:** one real ticket submitted end-to-end via text authorization; amount-drift abort and automation-failure paths exercised.

## 7. Non-functional requirements

- **Security:** Phase 3 vault posture as above; payment credentials never in logs, ever. Phase 1's observability is logs and its working data is phones + plates — keep logs access-controlled and PII-minimal (plates are public data; phone numbers are not; residue logs carry subscription id + plate, never phone). Per-user isolation from Phase 2 accounts onward; secrets in a secret manager (Socrata app token included); full audit trail on money movement.
- **Reliability:** Phases 1–2 read a public API; failure modes are outages, schema drift, and dataset deprecation — rarer and louder than markup drift. Posture: a usable-but-untrustworthy response resolves to **Uncertain** and no usable response to **Unreachable**; neither is ever recorded as Clean, both are **silent to the subscriber and ERROR to the maintainer**, and the cron run fails visibly — the rake task exits non-zero (DEC-071, DEC-082). Health alerting after N consecutive failures arrives in Phase 2; until it does, **sustained-outage silence is an accepted, named risk** (DEC-081, §10). "The scraper *will* break on markup changes" now applies to **Phase 3 checkout only**, which degrades to notify-only with a CityPay deep link.
- **Etiquette & risk posture:** daily per-plate API calls are the intended use of a public data service (tens of requests/day, tokened). The automation posture that must be revisited before any broader release is Phase 3's checkout automation, not the read path.
- **Observability:** Phase 1 — structured logs only, both send types included (DEC-073). **One JSON line per plate outcome** — subscription id, plate, state, outcome, reason code — and a **run summary line** closing every run: outcome counts, sends, duration, `rows`, `rows_with_amount_due`, `rows_without_amount_due`, `unknown_keys`. Two conditions raise that summary to ERROR: rows present with none carrying `amount_due`, and any unknown key (DEC-069); the first also resolves every fetched plate to Uncertain before anything is sent, and either fails the run (DEC-082). **Log levels (decided — DEC-078):** INFO for routine run outcomes and sends; **WARN** for the residue skip-log (a standing "shape needs an enhancement" condition), an unrecognized `amount_due` string, and a Twilio 21610 on a send attempt; **ERROR** for **both** Uncertain and Unreachable — with retries gone, one failed fetch is that plate's final state for the day and the subscriber got no trustworthy answer. Phase 2 — dashboard (last successful poll per plate, send status) + admin alerts. Phase 3 — submission success rate.

## 8. System sketch

- **Stack (decided):** Ruby on Rails (current stable) + PostgreSQL; **no job framework in Phase 1 — Render Cron Job + rake task; Solid Queue at Phase 2** (A2); RSpec; Twilio SMS + OTP (number type & A2P registration per §5); Twilio SendGrid (first used in Phase 3); **Phase 1–2 reads are plain HTTPS JSON — no browser** (amounts string-typed and never cast — DEC-064); Ferrum/Cuprite with a Playwright sidecar fallback, **scoped to Phase 3 checkout**. Hosting: Render, single region.
- **Tables by phase:**
  - **P1:** `subscriptions` (phone, plate, state). The welcome and digest sends add no table — they fire and are recorded in logs; the residue skip-log and the run summary are log-only.
  - **P2:** `users`, `plates`, `violations`, `dismissals`, `notifications` (send log — dedup starts here), job telemetry. The violations mirror stores the raw API row as its raw payload.
  - **P3:** `payment_profiles`, `payment_methods`, `quotes`, `authorizations` (one per transaction; per-ticket line items), `submissions`, `audit_events`.

## 9. Success metrics

- **0 late penalties** on enrolled plates — the product promise, live from Phase 1 (human + link) and guaranteed by Phase 3.
- **0 sends without a live subscription:** every message traces to an active enrollment; STOP means silence until START. Nothing Clementine sends is unsolicited — by definition and by check.
- **0 false all-clears:** no failed, malformed, **or uninterpretable** response is ever presented — by silence or otherwise — as "no tickets." A response with rows we cannot evaluate is never *recorded* as Clean: it resolves to **Uncertain** — silent to the subscriber, ERROR to the maintainer, and a failed run. The residual — a subscriber hears silence while the system is broken — is accepted and named (DEC-081, §10).
- **100%** of submissions preceded by a logged authorization transaction itemizing every covered ticket; **0** credential exposures.
- SMS delivery ≥ 99% (Twilio-reported).

## 10. Risks

- **Open Data outage / schema change / deprecation** → a usable-but-untrustworthy response resolves to **Uncertain**; no usable response resolves to **Unreachable**. Both are ERROR in the log and a non-zero exit — a failed run in Render's cron dashboard — and both are **silent to the subscriber** (DEC-071, DEC-077); health alerting arrives in Phase 2. A published city dataset with stable IDs drifts rarely, but the response is identical: never conclude clean from a response we can't read.
- **Detection lag (new tickets load weekly)** → accepted 2026-08-05: worst-case ~2 weeks against a day-30 penalty leaves margin; the welcome message sets the expectation.
- **Sustained outage → silence (named, accepted).** A multi-day outage presenting as 5xx or timeouts is silent to every subscriber by design — Unreachable never sends — and visible only in logs. Phase 1 is stateless: no consecutive-day memory to detect it, no admin alerting, and after DEC-072 no retries either. The mitigation is John reading the run-summary lines; the exit is Phase 2's health alerting. This is the one place where "silence means clean" and operational reality diverge (DEC-081).
- **Empty dataset → silence (named, accepted).** A dataset that is alive but answers `200 []` for every plate reads Clean per plate, by definition. The run-level canary that would have caught it is cut from Phase 1 and banked for Phase 2 (DEC-074). Same mitigation, same exit.
- **Small balances count.** The dataset carries 136 rows with `0 < amount_due < 1` (e.g. `"0.01"` after a `49.99` payment on a `50` fine) and 4,003 under $5 — most likely interest accruing between a payment being made and posted. Phase 1 does not solve it: any amount owed is owed, so a penny balance produces a digest (DEC-064). A known unknown to investigate later (open-questions C4).
- **Disputed tickets counted.** `HEARING PENDING` rows carry a balance, so a ticket under dispute counts as open and is nagged daily — consistent with zero dispute support (DEC-003); Phase 2's dismiss is the relief (open-questions C3).
- **Plate collisions across license types.** The query is `plate` + `state` and returns every `license_type` on those characters, so a subscriber's count could include a stranger's tickets. The direction is safe — it over-counts, never a false clean — and it matches CityPay's by-plate form, which defaults to all plate types. Unverified whether it happens at all; watch for it in live-fire, and the fix is a `license_type` column on `subscriptions` plus a filter (open-questions C2).
- **SODA 2.1 deprecation.** Socrata defaults new endpoints to SODA3, which requires a token or authentication; the SODA 2.1 endpoint remains supported and answered an anonymous query on 2026-09-20. The app token stays attached as deprecation insurance and rate-limit headroom (open-questions C1).
- **Silent empty from a malformed query** — the API's exact, case-sensitive matching means a subtly wrong query returns a legitimate-looking empty set (found live 2026-08-05) → plates normalized at enrollment; the welcome echo remains the wrong-plate tripwire.
- **Archival / partial rows in the dataset** — full history returns rows with no financial fields (a single six-key shape, about 6.4% of the dataset) → read as not-open, skipped, and logged at WARN as residue; statelessness means daily repeats, accepted. Drift is caught at the **run level**, not per row: rows present with none carrying `amount_due`, or any unknown key, raises the run summary to ERROR and fails the run; the former resolves every fetched plate to Uncertain before anything is sent (DEC-069, DEC-082).
- **Scam adjacency (added 2026-08-05).** DOF has publicly trained New Yorkers that unsolicited parking-payment texts are fraud — and Clementine's digest is superficially that shape (text + ticket + payment link) to everyone except its recipient, who subscribed to receive it. Mitigation is mostly existing design: every send is solicited at the subscription level (§2), the welcome establishes the contract and the sender, every digest arrives from that same number, and links go only to the canonical CityPay URL (Phase 1) then our own page (Phase 2). One added discipline: **Clementine never borrows CityPay's name, branding, or look** — it is always unmistakably Clementine. The A2P campaign registration (§5) presents this opt-in story. The risk sharpens in Phase 3 — a reply-PAY prompt is the most scam-shaped message there is — folded into the Phase 3 re-examination (§11).
- **CityPay markup change / captcha** → now a Phase 3 checkout risk only; degrade to notify-only with a deep link (§7).
- **Wrong plate registered** → welcome echo at enrollment time, plate + state on every digest; console removal (one-tap removal on the Phase 2 page).
- **Amount drift between quote and execution** → transaction-level abort + immediate re-quote (§6 Phase 3).
- **eCheck returns (NSF)** → the reopened ticket lands back in the count when the dataset reflects it (automatic under Phase 1's stateless model); Phase 2+ re-alerts it as reopened; Phase 3 alerts user + admin.
- **Unauthorized submission** → critical-incident path (§6 Phase 3).
- **SIM swap / stolen phone** → accepted at family scale: text auth can only pay the victim's tickets to the city; profile and payment-method changes require the authenticated page; the vault never re-renders details.
- **Daily-noise fatigue (Phase 1)** → accepted explicitly, including the flat urgency gradient and daily residue re-logs; ends (or gains dedup) with Phase 2 memory + dismiss.

## 11. Open questions

**None blocking.**

Standing notes, not questions: Phase 3's scope gets re-examined against the solicited-by-design principle, the scam-adjacency risk, and the landscape findings when that phase specs up (deferred 2026-08-05) — nothing changes before then, including whether a camera violation may appear inside a payment quote (DEC-065, DEC-010). Run a real trademark search before anything public-facing. The remaining data unknowns are tracked as **open-questions C1–C4**: SODA 2.1 deprecation and the `X-App-Token` header name, plate collisions across license types, `violation_status` and disputed tickets, and small balances. None blocks the build.

## 12. Milestones (rough — assumes part-time build via Claude Code)

- **M1** Twilio account + carrier registration first (step zero) + Rails skeleton + subscriptions + Open Data fetch/count + welcome + digest + run summary and residue log *(Phase 1 done)*
- **M2** Violations persistence + results page (tokenized) + digest link swap
- **M3** OTP login + dismiss + refresh + admin health alerts *(Phase 2 done)* (Alert send, canary probe and retries return here)
- **M4** Payment profile + vault + quote/authorization flow + CityPay checkout probe (recon for M5)
- **M5** CityPay submission executor + confirmation sends + audit *(Phase 3 done)*

## References

- NYC Open Data — Open Parking and Camera Violations (`nc67-uf89`): data.cityofnewyork.us/City-Government/Open-Parking-and-Camera-Violations/nc67-uf89 · SODA API docs: dev.socrata.com
- NYC parking & camera tickets service page (penalty schedule): nyc.gov/main/services/parking-and-camera-tickets
- NYC 311 — Parking Ticket or Camera Violation Payment
- CityPay parking portal: a836-citypay.nyc.gov/citypay/Parking (payment link + Phase 3 checkout)
- NYC DOF — Pay or Dispute app page: nyc.gov/site/finance/vehicles/nyc-pay-or-dispute.page
- Twilio messaging compliance docs (A2P 10DLC / toll-free verification)
