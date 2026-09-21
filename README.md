# Clementine

**Solicited-by-design SMS alerts for open NYC violations on your plate.** Invite-only, family scale, built with Ruby on Rails and Twilio on top of NYC Open Data — and an exercise in AI-assisted development.

> **Status (2026-09-20):** specification complete and confirmed — PRD v0.10, Phase 1 design v0.3, decisions DEC-064–081 — and **no code yet.** Phase 1 starts with the Twilio account and A2P 10DLC registration, then the Rails skeleton. See [Where things stand](#where-things-stand).

## The problem

Street-parked cars in NYC collect parking tickets their owners never see: the windshield copy blows away, the car sits between alternate-side moves, and the first real signal is a penalty notice. NYC adds a late fee at day 30, more at days 60 and 90, and enters judgment (interest, boot/tow exposure) around day 100. The fix is boring but hard to do by hand — check the city's system regularly and pay on time.

## What Clementine does

Three ships, in order:

1. **Text** — every morning, for each registered plate that has open tickets, one short SMS: how many, which plate, and a link to pay. The count is **every violation the city says is owed on the plate** — parking, camera, anything. No tickets, no text.
2. **Page** — our own per-plate page: tickets, amounts, deadline countdown, dismiss.
3. **Pay** — submit payment to CityPay on the user's behalf, after an explicit, logged text authorization. Never autonomously.

Phase 1 is deliberately stateless: one table (`subscriptions`), one daily job, two message types (welcome, digest). Ticket memory, login and per-ticket detail arrive in Phase 2; money moves only in Phase 3.

## Principles

- **Solicited by design.** Clementine exists to send messages and never sends one that wasn't asked for. Consent lives at the subscription level: signing up *is* the request. Nobody is enrolled who didn't ask; STOP is honored immediately. The category "unsolicited message" does not exist in this system.
- **Never a false all-clear.** Silence means clean, so silence must be earned by a fully-read response with zero open tickets. A response we can't fully read is never recorded as clean: it fails loudly to the maintainer — an ERROR line and a failed run — and is silent to the subscriber, a named and accepted Phase 1 risk. This is the failure the product exists to prevent, and it shapes the whole Phase 1 outcome model.
- **Agent, not processor.** Clementine never holds or moves funds. In Phase 3 it submits the user's payment into CityPay checkout as their agent; money flows user → NYC DOF.
- **Cut, don't qualify.** Each phase is its minimum viable shape; complexity is deferred with its rationale recorded, not hedged into scope.
- **Decision provenance.** Decided and proposed are kept visibly separate; superseded rationale is retired explicitly, never silently. `DECISIONS.md` is the record.

## Who it's for

Invite-only: the author plus family and friends, under 20 users in year one. No self-serve signup, no billing, no marketing. Not a commercial venture — it earns its keep by being useful to an invited circle, and by being a learning vehicle for AI-assisted product development (this repo is built with Claude Code).

## How it works (Phase 1)

- **Read source:** NYC Open Data "Open Parking and Camera Violations" (`nc67-uf89`) via the Socrata SODA API, queried by plate + state. New violations load weekly and satisfied ones clear daily, so a new ticket is typically seen within ~1 week, worst ~2 — still weeks ahead of the day-30 penalty.
- **Daily job (14:00 UTC — ~09:00 ET), per plate:** one fetch per plate → count every row with a balance (no classification; `amount_due` present, non-empty, not `"0"`) → resolve one of four outcomes: **Clean** (silence), **Count** (digest), **Uncertain** / **Unreachable** (silent to the subscriber; ERROR in the log; failed run). No retries in Phase 1.
- **Sends:** Welcome (at enrollment), Digest (count + plate + state + CityPay link). Twilio handles STOP/HELP natively.
- **Admin:** Rails console. **Observability:** structured logs.

## Stack

Ruby on Rails 8 · PostgreSQL · Render (web service + cron job + managed Postgres, single region) · Twilio (SMS; A2P 10DLC local NYC number) · RSpec · NYC Open Data SODA API. No job framework in Phase 1 (Render Cron + rake task, no retries); Solid Queue arrives with Phase 2. AWS is a services catalog to draw from à la carte (KMS at Phase 3), not a destination.

## Repository map

| Path | What it is |
|---|---|
| `CLAUDE.md` | Working instructions for Claude Code sessions: invariants, conventions, phase discipline |
| `DECISIONS.md` | Provenance log — every decision with date, rationale and status; superseded entries retired in place |
| `docs/prd.md` | Product requirements (v0.10) — the source of truth for *what* |
| `docs/phase1-design.md` | Phase 1 design (v0.3) — the *how*: stack, hosting, jobs, testing, config, observability |
| `docs/open-questions.md` | The remaining unknowns and the next actions, in order |
| `docs/open-data-reference.md` | The read source: endpoint, fields, predicates and quirks verified against real data |
| `docs/messaging.md` | The two send types, copy contracts, and A2P 10DLC registration inputs |
| `docs/citypay-reference.md` | CityPay lookup/checkout mechanics distilled from a live capture — Phase 3 recon |
| `docs/mvp-readiness.md` | The 2026-09-20 Phase 1 readiness review — historical; the resolutions live in `DECISIONS.md` |
| `docs/fixtures/open-data/` | Real API pulls committed as fixtures — see its README |
| `docs/handoffs/` | Prompts that let a fresh session resume work — see its README |

## Where things stand

**Done:** PRD through v0.10 and Phase 1 design v0.3, CityPay recon captured, read source verified live, and the **Phase 1 readiness pass** answered in full on 2026-09-20 — decisions DEC-064–081, five real API pulls committed as fixtures, every doc reconciled.

**Next, in order:**
1. Create the Twilio account, buy a local NYC number, start A2P 10DLC registration — step zero, the longest lead-time item; it runs in parallel with everything below.
2. `rails new` (Rails 8, Postgres, RSpec, RuboCop, GitHub Actions); move the fixtures to `spec/fixtures/open_data/`.
3. Build Phase 1: subscriptions → fetch / count → welcome, digest; run summary and residue log.

## Glossary

- **Welcome / Digest** — the only two send types in Phase 1.
- **Clean / Count / Uncertain / Unreachable** — the four per-plate run outcomes.
- **Open** — a row whose `amount_due` is present, non-empty and not `"0"`.
- **Residue** — rows skipped as not-open that fit no routine case; logged at WARN to drive later enhancements.
- **Run summary** — the one log line per run that carries outcome counts and the drift check.
- **Scheduled** (never "unsolicited") — the system-timed daily send.
- **Agent, not processor** — Clementine submits the user's payment to CityPay; it never touches the money.

## Working conventions

Docs-first, trunk-based, progress by commits. The PRD and design doc are versioned in-document (the changelog at the top records *why*); git carries the rest. When a decision lands, `DECISIONS.md` is updated in the same commit. Proposed items stay marked proposed until John explicitly confirms them.

---

*Formerly PlateWatch. Named for the orange envelope under the wiper.*
