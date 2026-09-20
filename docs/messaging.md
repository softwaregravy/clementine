# Messaging: send types, copy contracts, and carrier registration

Phase 1 has exactly three send types (PRD v0.9 §6). The **contracts are decided; the words are not** — copy below is DRAFT, and final copy lands at A2P campaign registration (DEC-029). Nothing here is unsolicited by definition (DEC-008): every send traces to a live subscription.

## Contracts (decided)

| Send | Fires | Must contain | Must not contain |
|---|---|---|---|
| **Welcome** | Console enrollment (synchronous send — P4, proposed) | Identify Clementine; echo plate + nickname; the contract — a morning text when open tickets exist, silence means clean, new tickets can take a week or more to appear in the city's data; STOP/HELP footer | — |
| **Digest** | Daily ~09:00 ET, only when the run outcome is Count | Count of open parking tickets; nickname; plate; CityPay link | Amounts, dates, urgency, the word "new" |
| **Alert** | Daily run, outcome Uncertain | The count if it survived (otherwise no number); that Clementine couldn't confirm / read this morning; the link to check | The word "new" — say "open" / "outstanding" |

Clean and Unreachable send nothing. Twilio handles STOP / HELP / START natively (DEC-025); unrecognized inbound is ignored (P6, proposed); custom HELP copy lives on the Messaging Service (P5, proposed). Every send is logged with type, outcome and timestamp (PRD §7).

## Draft copy (proposed — edit freely)

**Welcome**

> Clementine here. You're set up for {nickname} ({plate} {state}). On mornings you have open NYC parking tickets, I'll text a count and a link to pay. No text means none showed up — but new tickets can take a week or more to appear in the city's data. Reply STOP to end, HELP for help.

**Digest** (form decided in PRD v0.5: "N open parking tickets on [nickname] ([plate]). Pay or view: [link]")

> {count} open parking ticket(s) on {nickname} ({plate}). Pay or view: {citypay_link}

**Alert — count survived**

> Clementine saw {count} item(s) with a balance on {nickname} ({plate}) this morning but couldn't confirm the details. Please check: {citypay_link}

**Alert — no count**

> Clementine couldn't read the ticket status for {nickname} ({plate}) this morning. Please check: {citypay_link}

`{citypay_link}` = `https://a836-citypay.nyc.gov/citypay/Parking`. The by-plate search is a POST, so no plate-prefilled URL is known (open question C6); the user enters the plate on arrival.

## A2P 10DLC registration inputs (DEC-026, DEC-027)

- **Brand:** sole-proprietor path (working assumption, design D6).
- **Number:** a local NYC 10DLC number; one Messaging Service wraps it (P5).
- **Use case, in our words:** notifications a subscriber asked for at enrollment — a daily count of open parking tickets on their own plate, plus an enrollment confirmation.
- **Sample messages:** the three drafts above.
- **Opt-in description:** consenting family and friends are enrolled by the admin at their request (console); the welcome message restates the contract; STOP is honored immediately; START plus console to resume.
- **HELP copy:** written by John at registration.
- **Lead time:** days to weeks — the first real-world action of M1.

## Vocabulary

- "Scheduled" (system-timed) — never "unsolicited."
- "Open" / "outstanding" — never "new" in Phase 1.
- "Confirmation of actions taken" — never "receipt" (Phase 3).
- Clementine is always unmistakably Clementine — never CityPay's name, branding or look (DEC-009).
