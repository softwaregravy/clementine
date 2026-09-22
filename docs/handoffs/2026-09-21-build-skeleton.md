# Build — generate the Rails skeleton for Phase 1

**Status:** open · **For:** a build session (staff-level; the role `CLAUDE.md` describes; runs on John's machine via Remote Control, because the skeleton needs rubygems and a database) · **Kickoff:** `Read docs/handoffs/2026-09-21-build-skeleton.md and follow it.` · **Writes:** `docs/handoffs/2026-09-21-build-skeleton-report.md`, the `CLAUDE.md` Commands section, and commits.

You are picking up after the cascade review of 2026-09-21. Read `CLAUDE.md` in full before anything else; then `docs/phase1-design.md` (v0.3) and `docs/open-questions.md` §F. The PRD (v0.10) is the *what*; you will not need most of it for this step.

## Where things stand

- `main` carries everything: PRD v0.10, design v0.3, `DECISIONS.md` through **DEC-083**, the five fixtures, and the handoffs folder. The cascade branch `phase1-readiness-review` was fast-forwarded into `main` on 2026-09-21 (`c6022c4`) and `main` was pushed to origin the same day. **DEC-083, decided after this brief was first written, made `main` PR-only:** do this work on `build/rails-skeleton`, push the branch, open a pull request, stop — see `CLAUDE.md`.
- **No code exists.** This handoff produces the skeleton only: `rails new`, the test/lint/CI plumbing, fixtures moved, `CLAUDE.md` Commands filled. The Phase 1 build itself (subscriptions → fetch/count → sends → rake task) is the *next* handoff, written by you at the end.
- **DEC-082 is new since the docs were cascaded** and changes the daily run's shape: two passes — fetch every plate, run the run-level drift check, then resolve and send — with the exit code non-zero on any Uncertain/Unreachable plate *or* a summary ERROR. It does not affect the skeleton, but read it before writing the rake task later.

## Twilio — parallel (DEC-079)

**Twilio step zero is John's action** (DEC-079: account → local NYC number → A2P 10DLC, sole-proprietor). It gates live sends, not the build, and runs in parallel. John was asked on 2026-09-21 whether to sequence it first; he did not say so, and DEC-079 stands. Generate without waiting: only the live-fire step at the end of Phase 1 needs the number.

## Environment facts (probed 2026-09-21 on John's machine)

| Thing | State |
|---|---|
| Ruby | 4.0.6 via mise (`latest`); **no `.ruby-version` in the repo yet** — write one so mise pins it |
| RubyGems / Bundler | gem 4.0.16, bundler 4.0.16; **no `rails` gem installed**; rubygems.org reachable (HTTP 200) |
| Rails | not installed — `gem install rails` first, then check the release supports Ruby 4.0; if not, pin Ruby 3.4.x with mise and `.ruby-version` |
| PostgreSQL | **no server and no libpq** — `psql` and `pg_config` are both missing, so the `pg` gem will not build until `libpq-dev` is installed (sudo: John's step); Docker 29 is present for a local server (`postgres:17`) |
| Node | 24.19 via mise; `npm` is aliased to `pnpm` — irrelevant if JavaScript is skipped (below) |
| Git / GitHub | `gh` authenticated as `softwaregravy`; origin `git@github.com:softwaregravy/clementine.git`; branch `main` |
| Repo root | `CLAUDE.md`, `DECISIONS.md`, `README.md`, `docs/` only; no `.gitignore`, no `.envrc` |

## The skeleton — Proposed, John vetoes by exception

None of this is decided yet. When John confirms (in chat, by exception), record it as **DEC-084** in the same commit as the generated app, listing the exact `rails new` line and the gems added. Anything he vetoes, drop and say so in the report.

1. **Install and generate**, from the repo root so the existing files stay put:

   ```
   gem install rails
   rails new . --database=postgresql --skip --skip-bundle \
     --skip-test --skip-solid --skip-kamal --skip-docker \
     --skip-jbuilder --skip-action-mailbox --skip-action-text \
     --skip-active-storage --skip-action-cable --skip-javascript
   ```

   `--skip` keeps `README.md` and everything else that already exists. `--skip-test` because RSpec (D7). `--skip-solid` because no job framework in Phase 1 (D5; Solid Queue returns at Phase 2 with `bin/rails solid_queue:install`). `--skip-kamal` and `--skip-docker` because Render deploys from git (P1). `--skip-javascript` because Phase 1 has one route, `/up`; Phase 2's page adds importmap/Turbo in a minute. Keep Propshaft, Brakeman, RuboCop (rails-omakase) and the generated GitHub Actions workflow.

2. **Gems** — the ask-before-adding list (`CLAUDE.md`), all boring: `rspec-rails`, `factory_bot_rails`, `webmock` (test); `rubocop-rspec` (development); `dotenv-rails` (development, test — P15); `twilio-ruby` (runtime, the only send path). **No HTTP client gem** — `Net::HTTP` with an explicit 10 s timeout is the fetch (DEC-072). **No lograge in Phase 1** — the run's JSON lines come from the rake task's own formatter (P18 says "lograge or equivalent"). Then `bundle install`, `bin/rails generate rspec:install`, and one smoke spec so the suite is green and non-empty.

3. **Fixtures:** `git mv docs/fixtures/open-data spec/fixtures/open_data` (README included) and repoint every reference — `docs/open-data-reference.md` "Fixtures", `README.md` repository map, `CLAUDE.md` Sandbox notes, design P8, `docs/open-questions.md` §F, the fixtures README's own last line. Never edit a fixture's contents.

4. **CI:** adapt the generated `.github/workflows/ci.yml` to run `bin/rspec` and `bin/rubocop` (keep Brakeman) against a Postgres service container. Push the branch and open the PR; the workflow's run on that PR is the first CI event, and the merge is the first deploy once Render is wired (a later PR).

5. **Local dev:** `.ruby-version`; `.envrc` containing `PATH_add bin` (John's global convention — mise + direnv) with `.env*` and `.envrc` gitignored; `.env.example` listing `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `SOCRATA_APP_TOKEN` with placeholder values only (invariant 4 applies to every secret: never real values). `config/database.yml` reading `DATABASE_URL` in production (Render-injected).

6. **`CLAUDE.md` Commands section:** replace the placeholder paragraph with setup, test, lint, the daily-run rake task name (`clementine:daily_run`, per open-questions §F — not yet written), and console. Update the status line to "skeleton generated YYYY-MM-DD".

## Rules

- **Edit only:** the generated app files, `Gemfile`, `.github/`, `.ruby-version`, `.envrc`, `.env.example`, `.gitignore`, `spec/`, the fixture move plus the reference repoints listed above, `CLAUDE.md` (Commands, status line, Sandbox notes), `DECISIONS.md` (append DEC-084 only), and this file's `Status:`.
- **Off limits:** the PRD and design doc bodies (no design changes in a skeleton commit), `docs/mvp-readiness.md`, `docs/citypay-reference.md`, every other file under `docs/handoffs/`, fixture contents.
- **Proposed ≠ decided:** anything above John has not confirmed stays labelled Proposed in the report.
- **No Phase 1 behavior yet** — no `Subscription` model, no fetch, no sends. The skeleton is done when the suite is green and empty of product code.

## Verify (paste into the report)

`ruby -v`, `bin/rails -v`, `bin/rspec` (green), `bin/rubocop` (clean), `bin/rails db:create db:migrate` if a local Postgres exists (say so if not), `git status` clean, `ls spec/fixtures/open_data/` showing six files, and `grep -rn 'docs/fixtures/open-data' --include='*.md' .` returning nothing.

## Report and next handoff

Write `docs/handoffs/2026-09-21-build-skeleton-report.md`: the exact `rails new` line run, the Rails and Ruby versions, every gem added, anything John vetoed, anything you could not do (sudo steps, Postgres), and the verification output. Flip this file to `done`, add both to the handoffs README index, and write the next brief — `YYYY-MM-DD-build-phase1.md` — mapping open-questions §F items 3–5 onto work, with DEC-082's two-pass run spelled out in the rake-task step. Commit as you go on `build/rails-skeleton`, push the branch, open the PR per `CLAUDE.md`, and stop; the status flip and the next brief ride in the same PR.
