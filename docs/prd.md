# Clementine — PRD v0.9
*Formerly PlateWatch.*

**Owner:** John · **Status:** Draft for review · **Last updated:** 2026-08-05

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

1. **Text** — a daily SMS digest of open NYC parking tickets per registered plate, with a payment link,
2. **Page** — our own per-plate results page for viewing and managing tickets, and
3. **Pay** — submits payment to CityPay **on the user's behalf** after an explicit, logged text authorization — **never autonomously**.

Clementine is not a payment processor: it never holds or moves funds. Money flows directly from the user's bank or card to NYC DOF via CityPay; Clementine acts as the user's agent at checkout.

**Solicited by design.** Clementine exists to send messages — and never sends one that wasn't asked for. Solicitation operates at the subscription level, not per message: signing up *is* the request to receive notifications, nobody is enrolled who didn't ask, the welcome restates the contract, and STOP is honored natively and immediately. This is not a spam bot with a good excuse; it is a system whose entire capability is delivering helpful messages to people who requested them. It is also the product's lane — the city's official channel for individuals is paper and silence (DOF publicly warns it will never text a payment reminder), the fraudulent channel is unsolicited by definition, and Clementine occupies the third position: warnings you signed up to receive, from a sender you know, before deadlines bite.

**Why it exists.** Clementine is primarily a learning vehicle — an exercise in AI-assisted product development by its author — that earns its keep by being genuinely useful to the author and an invited circle. It is not a commercial venture: no billing, no growth ambitions (§3 stands). Competitors in the category are read as market validation, not threat; at this scale the moat is trust — your phone number and plate go to someone you know, not to a service.

Success looks like: nobody on the system ever pays a late penalty again.

## 3. Users & scale

- Invite-only: John plus family and friends. Target **< 20 users in year one**.
- In Phase 1 a "user" is a subscription row (phone + plate); accounts materialize in Phase 2. Multi-plate and multi-phone from day 1 — two subscribers to one plate each get the digest, and the plate is polled once.
- John is the sole admin, console-first: invites, plate removal, and inspection happen in the Rails console until Phase 2 adds health alerting.
- No self-serve signup, no billing, no marketing.

## 4. Scope

**In:** NYC **parking violations only**, end to end across the three phases: text → page → pay.

**Out:**
- **Camera violations** (school-zone speed, red light, bus lane). The dataset includes them; the job excludes them via a **camera-side blocklist** — recognized camera rows are dropped, every other row is kept regardless of issuing agency (an allowlist of parking issuers was rejected: it would silently drop parking tickets from agencies outside the known set, a false clean). The job stays type-aware, so enabling camera violations later is configuration, not migration.
- **Dispute support of any kind.** A ticket the user doesn't want to pay is simply never authorized; Phase 2's **dismiss** silences it. The product takes no position on disputes.
- Payment processing (see §2 — agent, not processor), other cities, native mobile apps, payment plans / judgment-debt handling.

## 5. External constraints (verified July 2026; read source, payment channels & landscape re-verified 2026-08-05; field structure verified against live sample 2026-08-05)

- **Sole read source (decided 2026-08-05, supersedes 2026-08-02):** NYC Open Data **"Open Parking and Camera Violations"** — dataset `nc67-uf89`, Socrata SODA API, JSON over plain HTTPS, queried by `plate` + `state` (values exact-match, uppercase). App token attached (managed secret) for rate-limit headroom. **Field needs, phase-tiered — now verified against a live 132-row pull (single plate, 3 open):** P1 — enumerable rows + violation-type discrimination: **present**; open-ness reads directly off `amount_due` (int) > 0; amounts are **string-typed**; the response returns **full history**, including archival rows with no financial fields. P2 — summons number, amount due, issue date: **present**. P3 — authoritative amounts at execution: **not this dataset** — a weekly-lagged export is never the money authority; amounts bind at CityPay checkout at execution time, as §6 Phase 3 always required.
- **Data freshness.** New violations load **weekly (Sundays)**; satisfied violations clear **daily (Tue–Sun)**; the city separately warns new tickets take days to enter its system at all. Net: new-ticket detection typically ~1 week, worst ~2, after issuance; a payment falls out of the count within a day. The **welcome message** carries the caveat (the digest stays minimal).
- **Deadlines (parking violations).** Pay or dispute within **30 days of issuance** or penalties accrue: **+$10 at day 30, +$20 at day 60, +$30 at day 90; judgment around day 100** (interest begins; boot/tow exposure above $350 in judgment debt). → Deadline math is absent from Phase 1 by design (count-only digest); countdown surfaces on the Phase 2 page; urgency messaging is Phase 3, spec later. (Camera violations follow a different, faster schedule — one more reason they're out of scope.)
- **Payment channels (re-verified 2026-08-05).** CityPay web (the city's recommended option), the official "NYC Pay or Dispute" mobile app, an automated phone payment line, mail, or in person. **No public payment API.** eCheck carries no fee; cards add a ~2% service fee. Automation alternatives to the web UI were examined and rejected: the mobile app is a private undocumented API to the same backend (brittle and adversarial to automate for money movement); the phone line routes card data through our telephony (processor territory, and no eCheck); programmatic mail (check-printing services) makes Clementine the account of origin (processor again) and adds 2–3 weeks of processing against deadline clocks; DOF's fleet programs (Regular Fleet / Stipulated Fine / Commercial Abatement) require commercial enrollment and trade away hearing rights — wrong shape for family plates. → Phase 3 remains **headless-browser automation of CityPay checkout**, and **eCheck is the default stored method**.
- **Landscape (verified 2026-08-05).** No official proactive ticket alerting exists for individuals: the Pay or Dispute app is pull-only lookup/pay/dispute — saved plates save typing, not a subscription — and the only official monitoring, the fleet programs' weekly consolidated statements, is gated on commercial enrollment. Independent plate-monitoring services exist (lookup tools and text-alert services), almost certainly on this same dataset and so inheriting the same weekly lag; none visibly performs authorized agent payment. Read as market validation. Clementine's differentiation at family scale is trust and the Phase 3 arc, not features. DOF publicly disclaims ever sending unsolicited payment texts → see §10 scam adjacency.
- **Carrier registration (added 2026-08-04).** US application-to-person SMS requires A2P 10DLC brand/campaign registration — or toll-free number verification — through Twilio before production sends. Registration wants a use case, sample messages (we now have three templates — welcome, digest, alert), and an opt-in description (console enrollment of consenting family — the solicited-by-design story, §2). Approval lead time is days to weeks → it opens M1. Number-type choice → design doc.

## 6. Phases

### Phase 1 — Text *(stateless daily count)*

- **Data:** `subscriptions` (phone, plate, state, optional nickname), console-managed; plates normalized (uppercase, no spaces/dashes) at enrollment. Nothing else persists — no ticket memory, no send markers, no accounts. The Alert and the skip-log add **no tables** — both are log-only.

- **Open predicate:** a row is open when `amount_due`, cast to integer, is **> 0**. `amount_due` is the net balance already (fine + penalty + interest − reductions − payments), so it is read directly, never recomputed. All amounts arrive as strings — the cast is load-bearing.

- **Run outcome model — per plate, per daily run.** Four outcomes, and the boundary between the first and third is the invariant:
  - **Clean** — response read in full, zero open parking rows → **no send**. Silence means clean.
  - **Count** — response read in full, ≥1 open parking row → **Digest** with the number.
  - **Uncertain** — a usable response came back, but the open/type read on it can't be trusted (a row that should carry financials has lost `amount_due`; a whole-response shape change; a row that can't be classified camera-or-not that would affect the count) → **Alert**, never silent. The Alert carries the count when the count survived the failure and omits it when it didn't.
  - **Unreachable** — no usable response (timeout, connection failure, non-JSON body) → **log, skip; tomorrow covers**, per the 24h SLA. Retries live here.
  - **Invariant (load-bearing):** *a row we cannot evaluate can never produce a Clean.* Silence is earned only by a fully-read response with zero open rows — never by an unreadable or drifted one.

- **Camera filter (blocklist, runs before the count):** recognized camera-enforcement rows are excluded; every other row is kept regardless of issuing agency. Seeded from the sample (photo school-zone speed, DOT-issued) and extended as red-light/bus-lane examples appear; exact predicate is a design-doc detail. A row that can't be classified camera-or-not is not silently dropped — it routes to Uncertain if it would affect the count.

- **Sparse / financially-empty rows:** the dataset returns full history, including archival rows with no financial fields (observed: a 2021 row with only plate/state/summons/issue-date/image). Disposition:
  - A partial row is a well-formed record, **not** a malformed response — it never trips Unreachable.
  - A row with **no** `amount_due` reads as **not-open** and is skipped (and logged — see below): we can't assert a balance we can't see, and an open ticket in this data always carries `amount_due` > 0.
  - A row that *should* carry financials but has **lost** `amount_due` on an otherwise-populated response is **drift → Uncertain**, not a silent skip.
  - The tell between archival noise and schema drift is **universality**: one empty row among many is noise (skip + log); every row losing the field is a rename (Uncertain, alert). A whole-response shape change never resolves to Clean. The failure direction is safe — if the rule misfires it errs toward "go check," never toward a false clean.

- **Skip-logging (instrumentation, not a fifth outcome):** the unclassifiable residue — rows skipped as not-open that fit none of the routine cases (recognized camera, or parking with a readable `amount_due`) — is logged at **WARN**, full raw row, tagged subscription id + plate (no phone; the row carries none). Routine paid rows and recognized camera rows are **not** logged. Statelessness means the same residue row returns and re-logs **every day** — accepted at slow scale; row-level dedup is a Phase 2 capability (the violations mirror). The WARN denotes a **standing condition** — "a row shape exists the classifier can't yet handle, build an enhancement" — not a fresh per-run incident; structured logs filter/dedup at read time. **A run with a logged skip still resolves to Clean or Count.**

- **Three send types, all templated; there are no others:**
  - **Welcome** — on console enrollment: identifies Clementine, echoes plate + nickname, states the contract (morning text when open tickets exist; silence means clean; new tickets can take a week or more to appear in the city's data), STOP/HELP footer. Doubles as the wrong-plate tripwire — the echo arrives while enrollment is fresh.
  - **Digest** — daily ~09:00 ET, only when open parking tickets exist: count of open tickets, plate nickname, plate, CityPay plate-search link. No amounts, no dates — the link carries the detail. (The link stays CityPay: that's the *payment* surface; the API is our read path, not the user's.)
  - **Alert** *(new — Uncertain outcome)* — one template, count slot optional. When the count survived: names the number of items seen with a balance on the plate, states Clementine couldn't confirm the details this morning, directs the user to the link to review. When the count didn't survive: states Clementine couldn't read the plate's status this morning, directs the user to the link. **Never claims "new"** — statelessness can't distinguish new from known-open; the words are "open" / "outstanding." Final copy lands at campaign registration with the other templates.

- **Job:** once daily, ~09:00 ET, per distinct plate (plate + state): fetch → if Unreachable, retry-then-skip → else classify each row (camera blocklist; open predicate; residue skip-log) → resolve the outcome → Clean (no send), Count (digest to every subscribed phone for that plate), or Uncertain (alert to every subscribed phone for that plate). Per-plate isolation: one plate's Uncertain or Unreachable never affects another's.

- **No tickets → no text.** Silence means clean — the Clean outcome, stated in the welcome, guarded by the invariant above.

- **Retries:** scoped to **Unreachable only** — bounded in-run attempts with backoff; if all fail, today's run for that plate is skipped (logged) and tomorrow's covers it (a 24h SLA absorbs a missed day at day-granularity deadlines). Uncertain does **not** retry — re-fetching won't fix a schema that changed; it alerts.

- **Accepted noise:** open tickets re-text daily until satisfied (the nag is arguably a feature); a retry after a partial send can double-text; **no urgency gradient** — a day-5 ticket and a day-28 ticket read identically, escalation is repetition; and residue rows re-log at WARN daily under statelessness. All fine at family scale; all end (or gain dedup) with Phase 2.

- **Opt-out:** STOP/HELP auto-handled by Twilio; a stopped subscriber goes silent and surfaces in send logs; START plus console to resume.

- **Etiquette:** the read path is a public data API built for programmatic access — token attached, back off on 429/5xx, tens of requests/day. (Scraping posture — stop-on-captcha — moves to Phase 3, where the browser lives.)

- **Exit criteria:** welcome received on a fresh enrollment; 2+ weeks of clean daily operation on real plates; at least one real ticket detected with an accurate count and a working link; a forced unreadable-or-drift condition produces an **Alert** (never a Clean), with the count when it survived; an unclassifiable residue row logs at **WARN** without suppressing a real count or producing a false clean; no unexplained double-sends — all verified in logs, there being no UI.

### Phase 2 — Page *(persist, display, manage)*

- **Persistence begins:** `violations` mirror (unique `summons_number`, type, `issue_date`, amounts, status, raw payload, `first_seen_at`). Ticket memory ends the noise era: digests distinguish new from known-open, send dedup becomes possible, and residue rows dedup instead of re-logging daily.
- **Results page** per plate: open tickets, amounts, deadline countdown, last-polled time — the product's first per-ticket detail surface. The digest link swaps from CityPay to this page.
- **Refresh:** poll-on-login plus a manual refresh button.
- **Auth:** SMS OTP, phone-first (ratified). Subscriptions graduate to user-owned plates. Optional internal ship order: tokenized read-only page first (plate data is public anyway); OTP lands with dismiss — the first write worth protecting.
- **Dismiss:** persists a dismissed set per plate; dismissed summonses leave the digest and the page. Silence, not action — no dispute machinery.
- **Admin:** console remains primary; add poll-health visibility and an alert to John after N consecutive failures (the system's first alerting).
- **Exit criteria:** page live behind OTP; a dismissed ticket vanishes from the next digest; a satisfied ticket drops off after the next poll; a forced failure fires the health alert.

### Phase 3 — Pay *(authorize by text, submit, confirm)*

*Scope flagged for re-examination against the solicited-by-design principle and the landscape findings before this phase specs up (§11). The spec below stands until then.*

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
- **Reliability:** Phases 1–2 read a public API; failure modes are outages, schema drift, and dataset deprecation — rarer and louder than markup drift. Posture: a usable-but-untrustworthy response resolves to **Uncertain (alert)**, never to a silent clean; no usable response resolves to **Unreachable** (log, skip, retry-then-tomorrow); health alert after N consecutive failures arrives in Phase 2. "The scraper *will* break on markup changes" now applies to **Phase 3 checkout only**, which degrades to notify-only with a CityPay deep link.
- **Etiquette & risk posture:** daily per-plate API calls are the intended use of a public data service (tens of requests/day, tokened). The automation posture that must be revisited before any broader release is Phase 3's checkout automation, not the read path.
- **Observability:** Phase 1 — structured logs only (welcome, digest, and alert sends included). **Log levels:** INFO for routine (run outcome + every send); **WARN** for the residue skip-log (a standing "shape needs an enhancement" condition) and for a single Unreachable run; **ERROR** for an Uncertain outcome (an active degradation that fired a user-facing alert this run). *(Level hierarchy proposed/derived — strike if it overreaches; residue-at-WARN is confirmed.)* Phase 2 — dashboard (last successful poll per plate, send status) + admin alerts. Phase 3 — submission success rate.

## 8. System sketch

- **Stack (decided):** Ruby on Rails (current stable) + PostgreSQL; Solid Queue or Sidekiq; Twilio SMS + OTP (number type & A2P registration per §5); Twilio SendGrid (first used in Phase 3); **Phase 1–2 reads are plain HTTPS JSON — no browser** (amounts string-typed → cast on read); Ferrum/Cuprite with a Playwright sidecar fallback, **scoped to Phase 3 checkout**. Hosting: Render, single region.
- **Tables by phase:**
  - **P1:** `subscriptions` (phone, plate, state, nickname). The welcome, digest, and alert sends add no table — they fire and are recorded in logs; the residue skip-log is log-only.
  - **P2:** `users`, `plates`, `violations`, `dismissals`, `notifications` (send log — dedup starts here), job telemetry. The violations mirror stores the raw API row as its raw payload.
  - **P3:** `payment_profiles`, `payment_methods`, `quotes`, `authorizations` (one per transaction; per-ticket line items), `submissions`, `audit_events`.

## 9. Success metrics

- **0 late penalties** on enrolled plates — the product promise, live from Phase 1 (human + link) and guaranteed by Phase 3.
- **0 sends without a live subscription:** every message traces to an active enrollment; STOP means silence until START. Nothing Clementine sends is unsolicited — by definition and by check.
- **0 false all-clears:** no failed, malformed, **or uninterpretable** response is ever presented — by silence or otherwise — as "no tickets." A response with rows we cannot evaluate resolves to the **Uncertain alert**, never to Clean.
- **100%** of submissions preceded by a logged authorization transaction itemizing every covered ticket; **0** credential exposures.
- SMS delivery ≥ 99% (Twilio-reported).

## 10. Risks

- **Open Data outage / schema change / deprecation** → a usable-but-drifted response resolves to **Uncertain (alert)**; no usable response resolves to **Unreachable** (log, skip, retry-then-tomorrow); health alerts arrive in Phase 2. A published city dataset with stable IDs drifts rarely, but the response is identical: never conclude clean from a response we can't read.
- **Detection lag (new tickets load weekly)** → accepted 2026-08-05: worst-case ~2 weeks against a day-30 penalty leaves margin; the welcome message sets the expectation.
- **Silent empty from a malformed query** — the API's exact, case-sensitive matching means a subtly wrong query returns a legitimate-looking empty set (found live 2026-08-05) → plates normalized at enrollment; the welcome echo remains the wrong-plate tripwire.
- **Archival / partial rows in the dataset** — full history returns rows with no financial fields (observed: a 2021 row) → read as not-open, skipped, and logged at WARN for later classifier work; statelessness means daily repeats, accepted. A *financial* row losing `amount_due` is drift, not archival noise → Uncertain, not silent.
- **Scam adjacency (added 2026-08-05).** DOF has publicly trained New Yorkers that unsolicited parking-payment texts are fraud — and Clementine's digest is superficially that shape (text + ticket + payment link) to everyone except its recipient, who subscribed to receive it. Mitigation is mostly existing design: every send is solicited at the subscription level (§2), the welcome establishes the contract and the sender, every digest and alert arrives from that same number, and links go only to the canonical CityPay URL (Phase 1) then our own page (Phase 2). One added discipline: **Clementine never borrows CityPay's name, branding, or look** — it is always unmistakably Clementine. The A2P campaign registration (§5) presents this opt-in story. The risk sharpens in Phase 3 — a reply-PAY prompt is the most scam-shaped message there is — folded into the Phase 3 re-examination (§11).
- **CityPay markup change / captcha** → now a Phase 3 checkout risk only; degrade to notify-only with a deep link (§7).
- **Wrong plate registered** → welcome echo at enrollment time, plate + nickname on every digest; console removal (one-tap removal on the Phase 2 page).
- **Amount drift between quote and execution** → transaction-level abort + immediate re-quote (§6 Phase 3).
- **eCheck returns (NSF)** → the reopened ticket lands back in the count when the dataset reflects it (automatic under Phase 1's stateless model); Phase 2+ re-alerts it as reopened; Phase 3 alerts user + admin.
- **Unauthorized submission** → critical-incident path (§6 Phase 3).
- **SIM swap / stolen phone** → accepted at family scale: text auth can only pay the victim's tickets to the city; profile and payment-method changes require the authenticated page; the vault never re-renders details.
- **Daily-noise fatigue (Phase 1)** → accepted explicitly, including the flat urgency gradient and daily residue re-logs; ends (or gains dedup) with Phase 2 memory + dismiss.

## 11. Open questions

**None blocking.**

Standing notes, not questions: Phase 3's scope gets re-examined against the solicited-by-design principle, the scam-adjacency risk, and the landscape findings when that phase specs up (deferred 2026-08-05) — nothing changes before then. The open predicate is pinned (`amount_due` int > 0); the camera filter strategy is pinned (blocklist), with the exact recognized-camera set extended against live samples as red-light/bus-lane examples appear (design-doc detail). The judgment/interest-stage behavior of this dataset is unobserved in the sample (no aged-to-judgment row present) — a known unknown, not a Phase 1 blocker. The **design doc (v0.2)** still describes the CityPay-scraper read path and needs a reconciliation pass against the API pivot. Run a real trademark search before anything public-facing.

## 12. Milestones (rough — assumes part-time build via Claude Code)

- **M1** Carrier registration first (lead time) + Rails skeleton + subscriptions + Open Data fetch/filter/count + welcome + digest + uncertain-alert + residue skip-log *(Phase 1 done)*
- **M2** Violations persistence + results page (tokenized) + digest link swap
- **M3** OTP login + dismiss + refresh + admin health alerts *(Phase 2 done)*
- **M4** Payment profile + vault + quote/authorization flow + CityPay checkout probe (recon for M5)
- **M5** CityPay submission executor + confirmation sends + audit *(Phase 3 done)*

## References

- NYC Open Data — Open Parking and Camera Violations (`nc67-uf89`): data.cityofnewyork.us/City-Government/Open-Parking-and-Camera-Violations/nc67-uf89 · SODA API docs: dev.socrata.com
- NYC parking & camera tickets service page (penalty schedule): nyc.gov/main/services/parking-and-camera-tickets
- NYC 311 — Parking Ticket or Camera Violation Payment
- CityPay parking portal: a836-citypay.nyc.gov/citypay/Parking (payment link + Phase 3 checkout)
- NYC DOF — Pay or Dispute app page: nyc.gov/site/finance/vehicles/nyc-pay-or-dispute.page
- Twilio messaging compliance docs (A2P 10DLC / toll-free verification)
