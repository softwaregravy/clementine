> **Role in the repo (note added at the GitHub handoff, 2026-09-19):** Phase 3 recon. Phases 1–2 read from NYC Open Data (`docs/open-data-reference.md`); CityPay is the digest's payment link and, in Phase 3, the checkout rail this doc's mechanics feed. Body below is verbatim v1 (2026-08-05).

# CityPay Integration Reference — v1

**Source:** Distilled from a live capture (HAR + 5 saved HTML pages) of a by-plate search on
`a836-citypay.nyc.gov`, plate `JPR7462` (NY), Aug 2026. Captured with Firefox 153 / macOS.

**Purpose:** Single canonical reference for the Clementine CityPay scraper (Phase 1 lookup;
Phase 3 payment). Replaces the raw HAR and HTML captures, which can be dropped from the project
once this is committed. Everything Clementine needs to reproduce the request and parse the
response is below.

**Scope note:** This documents the *mechanics* of the endpoint and response only. The reCAPTCHA
solving strategy is deliberately **not** decided here — see §5. Parser design and payment (cart)
flow are captured structurally but not yet built.

---

## 1. The lookup request (the one that matters)

A by-plate search is a **single POST** to one endpoint. There is no intermediate GET to prime the
form for the by-plate path — the landing page is served with both tab-forms already in the DOM, and
the "Search By License Plate" tab just unhides the `#by-plate-form`. Both tabs POST to the **same**
endpoint; the fields differ.

| | |
|---|---|
| **Method** | `POST` |
| **URL** | `https://a836-citypay.nyc.gov/citypay/Parking/searchResults` |
| **Content-Type** | `application/x-www-form-urlencoded` |
| **HTTP version** | HTTP/1.1 |
| **Response** | `200 text/html; charset=utf-8` — the results page is rendered server-side into the same response. No redirect, no JSON. |

### 1.1 POST body fields (by-plate)

Exact field names, from both the live POST body and the `#by-plate-form` markup:

| Field | Example value | Notes |
|---|---|---|
| `PLATE_NUMBER` | `JPR7462` | `maxlength=10`, `minlength=1`. Uppercased, no spaces. |
| `PLATE_STATE` | `NY` | 2-letter code. Full option list in §4. Defaults to `NY`. |
| `PLATE_TYPE` | `  ` (two spaces) | **A single/space value = "--ALL--".** In the live capture this was sent as spaces and worked. This is important: **a driver won't know their plate type**, and "ALL" is a valid catch-all, so we never have to resolve it. Full list exists in the form but we can ignore it. |
| `g-recaptcha-response` | *(long token)* | reCAPTCHA Enterprise token. See §5. Required — the server rejects without a valid one. |

**Minimal body Clementine must produce:**
```
PLATE_NUMBER=<PLATE>&PLATE_STATE=<ST>&PLATE_TYPE=+&g-recaptcha-response=<TOKEN>
```
(The by-violation tab instead sends `VIOLATION_NUMBER` + textarea; we don't use that path.)

### 1.2 Request headers that appear to matter

Most headers are ordinary browser noise, but these are worth replicating:

- `Cookie: PLAY_SESSION=<...>` — see §2. **This is the one piece of required prior state.**
- `Content-Type: application/x-www-form-urlencoded`
- `Origin: https://a836-citypay.nyc.gov`
- `Referer: https://a836-citypay.nyc.gov/citypay/Parking/searchResults`
- A normal-looking `User-Agent`.

---

## 2. Session / cookies

- The app is **Play Framework** (server: `nginx/1.19.5` fronting it). Session is carried in a single
  cookie: **`PLAY_SESSION`**, e.g.
  `PLAY_SESSION=88630c7e...-sessionId=1cd71895-d5eb-4d3d-b1a4-35236e3ad265`.
- In the capture, the **POST response set no new cookies** — the `PLAY_SESSION` was already
  established by the initial page load (the GET of the landing page). So the real flow is:
  1. `GET` the search page once → receive `PLAY_SESSION`.
  2. `POST` the search with that cookie + a fresh reCAPTCHA token.
- **Implication for the scraper:** we need one warm-up GET to obtain a session cookie before posting.
  Whatever mechanism produces the reCAPTCHA token (§5) will almost certainly be loading that page
  anyway, so the session cookie comes for free from the same context.

---

## 3. Parsing the results page

The response HTML contains a results table plus a running "cart"/checkout block. For Phase 1
(read-only lookup) we only need the table.

### 3.1 Where the data lives

- **Results table:** `<table id="resultsTable" class="search-results-list table table-hover dataTable ...">`
- Rendered by **DataTables** with **rowGroup** — so there is a **group header row** followed by one
  `<tr>` per ticket.
- **Group header row** (class `dtrg-group dtrg-start`) carries the plate-level summary and a
  convenient grand total:
  ```
  <u>3 Violations $195.00</u>
  ```
  Regex-able as `(\d+)\s+Violations\s+\$([\d,]+\.\d{2})`. Also carries
  `data-amnesty-applied="true"` at the row level when an amnesty program is in effect.
- **One ticket per row:** `<tr id="ticket-<VIOLATION_NUMBER>" ...>`, e.g. `id="ticket-2026676651005"`.

### 3.2 Column map (per ticket `<tr>`)

Header order and where each value is:

| Col | Header | How to read it |
|---|---|---|
| 0 | *(checkbox)* | `<input type="checkbox" name="VIOLATION_NUMBER" value="2026676651005">` → **the internal violation ID** |
| 1 | Violation # | Text = the **summons number** the driver recognizes, e.g. `9291099594`. (Plus a "View Ticket" link.) |
| 2 | Plate Details | e.g. `JPR7462 NY PAS` (plate / state / actual plate type) |
| 3 | Description | e.g. `21-No Parking (street clean)` — leading number is the NYC violation code |
| 4 | Issue Date | `MM/DD/YYYY`, e.g. `07/20/2026` |
| 5 | Liability Amount | `$65.00` — cell tag has a bare `liability` attribute |
| 6 | Pending Payment | `$0.00` |
| 7 | Total Amount Due | `$65.00` — **best machine-readable source:** cell has `data-amt-to-pay="65.00"` |
| 8 | Payment Amount | editable `<input type="number" name="paymentAmount" value="65.00" min="1.00" max="65.00" step="0.01">` |
| 9 | *(actions)* | Add-to-cart controls; hidden `newAmount` + `itemID` inputs (see §6) |

### 3.3 Two different "numbers" — store both

This is a real gotcha:

- **`VIOLATION_NUMBER`** (e.g. `2026676651005`) — the **internal** ID. It's what the form submits,
  what the row `id` uses, and what the payment cart references (`itemID`). **This is our primary key
  for a ticket.**
- **Summons # / displayed "Violation #"** (e.g. `9291099594`) — the **human-facing** number printed
  on the physical ticket. This is what a driver will read back to us over SMS.

Clementine should persist both, keyed on `VIOLATION_NUMBER`, and surface the **summons number** in
SMS copy.

### 3.4 Fields Clementine actually needs (Phase 1)

Per ticket: `violation_number` (internal), `summons_number` (displayed), `description`,
`issue_date`, `total_amount_due` (from `data-amt-to-pay`). Plus plate-level: `violation_count`,
`total_due`. Everything else (liability vs. pending split, payment inputs) is Phase 3.

### 3.5 Recommended parse strategy

Parse the DOM (Nokogiri), don't regex the whole page:
1. Select `#resultsTable tr[id^="ticket-"]` for ticket rows.
2. `violation_number` = the row's `id` minus the `ticket-` prefix (or the col-0 checkbox `value`).
3. `total_amount_due` = col-7 `data-amt-to-pay` (numeric, no `$`/comma cleanup needed).
4. `total_due` (plate level) = parse the group row's `N Violations $X` text once, as a
   cross-check against the sum of rows.
5. **Zero-violation case is unconfirmed** — we haven't captured a clean-plate response yet. Before
   trusting a "no tickets" result in production, capture that page too and confirm the empty-state
   markup (likely an empty `#resultsTable` or a message div). *Open item.*

---

## 4. `PLATE_STATE` option values

We only ever expect to *send* these; we don't parse them. Full list from the form (value → label):

```
NY NJ CT AL AK AZ AR CA CO DE FL FO(Foreign) GA HI ID IL IN IA KS KY LA ME MD MA
MX(Mexico) MI MN MS MO MT NE NV NH NM NC ND OH OK OR PA RI SC SD TN TX
GV(US Gov) DP(US State Dept) UT VT VA WA DC WV WI WY
— Canada — AB BC MB NF NB NT NS ON QB PE SK YT
```
Default and overwhelmingly common case: `NY`. (`PLATE_TYPE` full list omitted intentionally — we
send "ALL".)

---

## 5. reCAPTCHA — mechanics only (NOT solved here)

**What it is:** Google **reCAPTCHA Enterprise**, invisible/score-based (bound to the submit button,
not a checkbox challenge).

- **Site key:** `6Lcjyq4kAAAAAMjfezuVzT2r7CmFs1XbJnZs0PE9`
  (appears as `data-sitekey` on `<button type="submit" class="button g-recaptcha">` and in the
  `enterprise.js?render=<sitekey>` script URL).
- **Where the token goes:** POST field **`g-recaptcha-response`** (also mirrored into a hidden
  `<textarea name="g-recaptcha-response">` in each form).
- **Loader:** `https://www.google.com/recaptcha/enterprise.js?render=<sitekey>`, plus the site's own
  `assets/bb/javascripts/app/recaptcha.js`.
- **Token lifetime:** Google reCAPTCHA tokens are single-use and short-lived (~2 min). A token must
  be freshly minted per search and used immediately.
- **Server enforcement:** confirmed required — the field was present and non-empty in the successful
  POST; the server is presumably calling Google's Enterprise `assessment` API server-side and will
  reject a missing/invalid/low-score token.

**Not decided (deferred to a later session):** how Clementine obtains a valid token — real headless
browser executing the site JS, a third-party solver service, or another route. This is the central
open question for the scraper and is intentionally left open. Nothing above presupposes an answer.

---

## 6. Payment / cart flow (Phase 3 — captured, not built)

Enough was visible to note the shape; do **not** treat this as a spec yet.

- Selecting a ticket adds it to a cart. Each ticket row's action cell carries hidden inputs:
  `<input type="hidden" name="newAmount" value="65.00">` and
  `<input type="hidden" name="itemID" value="<VIOLATION_NUMBER>">`.
- There's an **"Add All"** grouped submit and per-row **Add to cart / Remove** controls.
- A second table (`summary="Payment Amount and Proceed To Checkout"`) holds the running
  selected-count / amount and the checkout entry point.
- `paymentAmount` per ticket is bounded `min=1.00 max=<total due>` — partial payments are allowed by
  the site, which is relevant to our **transaction-level amount-binding / abort-on-drift** rule:
  the `max` and `data-amt-to-pay` give us the authoritative figure to bind against.

**Open items for Phase 3:** capture the actual checkout POST(s) and confirmation page the same way
we captured the search, then extend this reference.

---

## 7. Miscellaneous observations

- **Framework fingerprint:** Play Framework behind `nginx/1.19.5`. Strong CSP, `X-Frame-Options:
  SAMEORIGIN`, HSTS — nothing that blocks a server-side client, but the CSP confirms they expect
  their own JS to run (relevant to the reCAPTCHA question).
- **Client-side error logging:** the page POSTs JS errors to `/citypay/logIt`. Harmless to us, but a
  reminder the front-end is chatty and brittle (the capture even shows a live JS `TypeError` in
  `parking-search.js`). Reinforces: **don't depend on their JS; drive the endpoint directly** once
  the token problem is solved.
- **Amnesty flag:** `data-amnesty-applied="true"` on the group row indicates a citywide amnesty
  window was active at capture time. Amounts shown already reflect it. Worth remembering that
  displayed totals are program-dependent and can shift.

---

## Changelog

- **v1** — Initial extraction from HAR (`NYC_Citypay_Post__har.txt`, entry 2 = the searchResults
  POST) and saved HTML (landing, by-license tab, results, results-expanded). Documents the by-plate
  request contract, session cookie, results-table parse map, dual-number gotcha, plate-state list,
  and reCAPTCHA mechanics. reCAPTCHA solving and Phase-3 checkout intentionally left as open items.
