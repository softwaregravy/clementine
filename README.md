# Clementine

**Solicited-by-design SMS alerts for open NYC parking tickets.** Invite-only, family scale, built with Ruby on Rails and Twilio on top of NYC Open Data — and an exercise in AI-assisted development.

> **Status (2026-09-19):** specification complete — PRD v0.9, Phase 1 design v0.2 — and **no code yet.** Phase 1 starts with A2P 10DLC registration and the Rails skeleton. See [Where things stand](#where-things-stand).

## The problem

Street-parked cars in NYC collect parking tickets their owners never see: the windshield copy blows away, the car sits between alternate-side moves, and the first real signal is a penalty notice. NYC adds a late fee at day 30, more at days 60 and 90, and enters judgment (interest, boot/tow exposure) around day 100. The fix is boring but hard to do by hand — check the city's system regularly and pay on time.

## What Clementine does

Three ships, in order:

1. **Text** — every morning, for each registered plate that has open parking tickets, one short SMS: how many, which plate, and a link to pay. No tickets, no text.
2. **Page** — our own per-plate page: tickets, amounts, deadline countdown, dismiss.
3. **Pay** — submit payment to CityPay on the user's behalf, after an explicit, logged text authorization. Never autonomously.

Phase 1 is deliberately stateless: one table (`subscriptions`), one daily job, three message types (welcome, digest, alert). Ticket memory, login and per-ticket detail arrive in Phase 2; money moves only in Phase 3.

## Principles

- **Solicited by design.** Clementine exists to send messages and never sends one that wasn't asked for. Consent lives at the subscription level: signing up *is* the request. Nobody is enrolled who didn't ask; STOP is honored immediately. The category "unsolicited message" does not exist in this system.
- **Never a false all-clear.** Silence means clean, so silence must be earned by a fully-read response with zero open tickets. A response we can't fully read produces an alert ("go check"), never silence. This is the failure the product exists to prevent, and it shapes the whole Phase 1 outcome model.
- **Agent, not processor.** Clementine never holds or moves funds. In Phase 3 it submits the user's payment into CityPay checkout as their agent; money flows user → NYC DOF.
- **Cut, don't qualify.** Each phase is its minimum viable shape; complexity is deferred with its rationale recorded, not hedged into scope.
- **Decision provenance.** Decided and proposed are kept visibly separate; superseded rationale is retired explicitly, never silently. `DECISIONS.md` is the record.

## Who it's for

Invite-only: the author plus family and friends, under 20 users in year one. No self-serve signup, no billing, no marketing. Not a commercial venture — it earns its keep by being useful to an invited circle, and by being a learning vehicle for AI-assisted product development (this repo is built with Claude Code).

## How it works (Phase 1)

- **Read source:** NYC Open Data "Open Parking and Camera Violations" (`nc67-uf89`) via the Socrata SODA API, queried by plate + state. New violations load weekly and satisfied ones clear daily, so a new ticket is typically seen within ~1 week, worst ~2 — still weeks ahead of the day-30 penalty.
- **Daily job (~09:00 ET), per plate:** fetch → drop recognized camera violations (blocklist) → count rows with `amount_due > 0` → resolve one of four outcomes: **Clean** (silence), **Count** (digest), **Uncertain** (alert, never silent), **Unreachable** (log, skip, tomorrow covers).
- **Sends:** Welcome (at enrollment), Digest (count + plate + CityPay link), Alert (couldn't fully read — go check). Twilio handles STOP/HELP natively.
- **Admin:** Rails console. **Observability:** structured logs.

## Stack

Ruby on Rails 8 · PostgreSQL · Render (web service + cron job + managed Postgres, single region) · Twilio (SMS; A2P 10DLC local NYC number) · RSpec · NYC Open Data SODA API. No job framework in Phase 1 (Render Cron + rake task); Solid Queue arrives with Phase 2. AWS is a services catalog to draw from à la carte (KMS at Phase 3), not a destination.

## Repository map

| Path | What it is |
|---|---|
| `CLAUDE.md` | Working instructions for Claude Code sessions: invariants, conventions, phase discipline |
| `DECISIONS.md` | Provenance log — every decision with date, rationale and status; superseded entries retired in place |
| `docs/prd.md` | Product requirements (v0.9) — the source of truth for *what* |
| `docs/phase1-design.md` | Phase 1 design (v0.2) — the *how*; partly stale pending reconciliation (see its banner) |
| `docs/open-questions.md` | Unknowns, pending vetoes, and next actions |
| `docs/open-data-reference.md` | The read source: endpoint, fields, predicates and quirks verified against real data |
| `docs/messaging.md` | The three send types, copy contracts, and A2P 10DLC registration inputs |
| `docs/citypay-reference.md` | CityPay lookup/checkout mechanics distilled from a live capture — Phase 3 recon |

## Where things stand

**Done:** PRD through v0.9 (reality-checked against a live 132-row API pull), Phase 1 design v0.2 (stack and hosting decided), CityPay recon captured, read source verified live.

**Next, in order:**
1. Start A2P 10DLC registration in Twilio — the longest lead-time item; it opens M1.
2. Veto pass on the design doc's proposed batch (P1–P20) and PRD amendments (A2–A4).
3. Reconcile the design doc with the Open Data read path (it predates that pivot).
4. Bootstrap the Rails 8 app (RSpec, RuboCop, CI) and commit the sample API response as a fixture.
5. Build Phase 1: subscriptions → fetch / classify / count → welcome, digest, alert.

## Glossary

- **Welcome / Digest / Alert** — the only three send types in Phase 1.
- **Clean / Count / Uncertain / Unreachable** — the four per-plate run outcomes.
- **Open** — a row whose `amount_due`, cast to integer, is greater than zero.
- **Camera blocklist** — recognized camera-enforcement rows are excluded before counting; everything else is kept.
- **Residue** — rows skipped as not-open that fit no routine case; logged at WARN to drive classifier enhancements.
- **Scheduled** (never "unsolicited") — the system-timed daily send.
- **Agent, not processor** — Clementine submits the user's payment to CityPay; it never touches the money.

## Working conventions

Docs-first, trunk-based, progress by commits. The PRD and design doc are versioned in-document (the changelog at the top records *why*); git carries the rest. When a decision lands, `DECISIONS.md` is updated in the same commit. Proposed items stay marked proposed until John explicitly confirms them.

---

*Formerly PlateWatch. Named for the orange envelope under the wiper.*
