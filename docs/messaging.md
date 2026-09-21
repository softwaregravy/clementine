# Messaging: send types, copy contracts, and carrier registration

Phase 1 has exactly **two** send types (PRD v0.10 §6; DEC-077). The **contracts are decided; the words are not** — copy below is DRAFT, and final copy lands at A2P campaign registration (DEC-079; open-questions E1). Nothing here is unsolicited by definition (DEC-008): every send traces to a live subscription.

## Contracts (decided)

| Send | Fires | Must contain | Must not contain |
|---|---|---|---|
| **Welcome** | Console enrollment (synchronous send — P4) | Identify Clementine; echo plate + state; the contract — a morning text when open tickets exist, silence means clean, new tickets can take a week or more to appear in the city's data; STOP/HELP footer | — |
| **Digest** | Daily ~09:00 ET (14:00 UTC), only when the run outcome is Count | Count of open tickets; plate; state; CityPay link | Amounts, dates, urgency, the word "new", the word "parking" in the copy (the CityPay URL path is not copy) |

The **Alert** (v0.9) is cut from Phase 1 — system failures alert the maintainer through the ERROR log, never the subscriber (DEC-071, DEC-077) — and is banked for Phase 2, where consecutive-day memory and health alerting can gate it.

Clean, Uncertain and Unreachable send nothing. Twilio handles STOP / HELP / START natively (DEC-025); unrecognized inbound is ignored (P6); custom HELP copy lives on the Messaging Service (P5). Every send is logged with type, outcome and timestamp (PRD §7). A stopped subscriber surfaces as Twilio error 21610 on the next send attempt, logged at WARN (DEC-076).

## Draft copy (proposed — edit freely)

**Welcome**

> Clementine here. You're set up for {plate} {state}. On mornings you have open NYC tickets, I'll text a count and a link to pay. No text means none showed up — but new tickets can take a week or more to appear in the city's data. Reply STOP to end, HELP for help.

**Digest** (form decided in PRD v0.5, amended 2026-09-20 by DEC-065 and DEC-075: "N open tickets on [plate] [state]. Pay or view: [link]")

> {count} open ticket(s) on {plate} {state}. Pay or view: {citypay_link}

`{citypay_link}` = `https://a836-citypay.nyc.gov/citypay/Parking`. Open question C6 is **closed** (verified 2026-09-20, DEC-080): CityPay has no plate-prefill URL — `?PLATE_NUMBER=…&PLATE_STATE=…` returns the landing page with an empty form, and the `searchResults` path is POST-only. The link is the landing page; the user enters the plate on arrival.

## A2P 10DLC registration inputs (DEC-026, DEC-027)

- **Status (2026-09-20):** **no Twilio account exists yet.** Create the account, buy the number, then register — step zero, running in parallel with the build (DEC-079).
- **Brand:** sole-proprietor path (design D6, DEC-027).
- **Number:** a local NYC 10DLC number; one Messaging Service wraps it (P5).
- **Use case, in our words:** notifications a subscriber asked for at enrollment — a daily count of open tickets on their own plate, plus an enrollment confirmation.
- **Sample messages:** the two drafts above — reworded 2026-09-20 for DEC-065 ("tickets", not "parking tickets") and DEC-075 (no nickname slot).
- **Opt-in description:** consenting family and friends are enrolled by the admin at their request (console); the welcome message restates the contract; STOP is honored immediately; START plus console to resume.
- **HELP copy:** written by John at registration.
- **Lead time:** days to weeks — the first real-world action of M1.

## Vocabulary

- "Scheduled" (system-timed) — never "unsolicited."
- "Open" / "outstanding" — never "new" in Phase 1.
- "Tickets" — never "parking tickets": the count includes every violation with a balance, whatever wrote it (DEC-065).
- "Confirmation of actions taken" — never "receipt" (Phase 3).
- Clementine is always unmistakably Clementine — never CityPay's name, branding or look (DEC-009).
