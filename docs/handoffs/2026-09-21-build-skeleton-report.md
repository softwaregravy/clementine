# Report — Rails skeleton generated

**Brief:** `2026-09-21-build-skeleton.md` (now `done`) · **Issue:** #2 · **Branch:** `build/rails-skeleton` · **Executed:** 2026-09-22, on John's machine via Remote Control · **Decision recorded:** DEC-084

## What was run

```
rails new . --database=postgresql --skip --skip-bundle \
  --skip-test --skip-solid --skip-kamal --skip-docker \
  --skip-devcontainer --skip-thruster \
  --skip-jbuilder --skip-action-mailbox --skip-action-text \
  --skip-active-storage --skip-action-cable --skip-javascript
```

**Versions:** Ruby 4.0.6 (mise, pinned by `.ruby-version`), Rails 8.1.3.1, PostgreSQL 17 (Docker) with libpq 16.15, 112 gems installed.

**Gems added:** `twilio-ruby` (runtime); `rspec-rails`, `factory_bot_rails`, `dotenv-rails` (development + test); `webmock` (test); `rubocop-rspec` (development). No HTTP client gem (DEC-072 — `Net::HTTP`), no lograge (P18's formatter is the rake task's own job). `rubocop-rails` arrives inside `rubocop-rails-omakase`, satisfying DEC-053 without a direct dependency.

**Nothing was vetoed.** John confirmed the brief's flags and gems at the kickoff, and the gem-isolation question was decided in session (below). No product code exists: no model, no fetch, no sends.

## Deviations from the brief, all recorded in DEC-084

| Deviation | Why |
|---|---|
| `--skip-devcontainer`, `--skip-thruster` added | Read the 8.1 generator's flag list; both serve container deploys and Render deploys from git (P1). `--skip-hotwire` proved unnecessary — `--skip-javascript` already omits turbo and stimulus. |
| `.envrc` **committed**, not gitignored | It holds no secret, and committed it makes "cd in and the binstubs work" a property of the repository rather than of one shell's history. `.env` stays ignored. |
| `BUNDLE_PATH: vendor/bundle` in a committed `.bundle/config` | John asked for gem isolation that works in his zsh, in a Claude Code session, and at deploy. A file works in all three; an `.envrc` export does not — see below. |
| `ruby file: ".ruby-version"` added to the `Gemfile` | Makes bundler enforce the one pin mise, `ruby/setup-ruby` and Render already read, instead of letting it drift silently. |
| `config.time_zone = "America/New_York"` set | A4 and the `CLAUDE.md` convention; the skeleton is where app-wide config belongs, and a digest timestamp in UTC is the kind of thing nobody notices until it ships. Active Record still stores UTC. |
| `bin/ci` gained a `step "Tests: RSpec"` | The generator left `config/ci.rb` without a test step because `--skip-test`; now `bin/ci` mirrors what GitHub Actions runs. |
| The brief's `grep` check cannot return nothing | `DECISIONS.md`, `docs/mvp-readiness.md`, the PRD changelog and the older handoffs all cite `docs/fixtures/open-data/`, and all are off-limits or historical. The six live references were repointed; the record keeps the path it was written with. |
| No `build-phase1.md` next brief | John's call, asked at the kickoff: issues #3–#7 already carry the scope, specs, hand-review lines, refs and branch names that brief would have restated, and DEC-083 narrowed handoffs to context no pull request holds. Duplicating five issue bodies into a file that can then contradict them buys nothing. |

## The environment, and why the bundle is project-local

A Claude Code session's shell is **non-interactive**: `_direnv_hook` is undefined and `precmd_functions` is empty, so `.envrc` never loads. mise works, but only because the session inherits a snapshot of an already-activated PATH — which resolved to `installs/ruby/latest`, not to the project's pin. Today `latest` *is* 4.0.6, so nothing diverges; the day the project pins something else, a session would silently use the wrong Ruby.

That is why isolation lives in files bundler and Rails read unconditionally:

- `.ruby-version` — mise when John `cd`s in, `ruby/setup-ruby` in CI, Render at deploy, and now bundler.
- `.bundle/config` — `BUNDLE_PATH: vendor/bundle`, so every invocation in any shell finds the same 112 gems, and the dependency **source tree sits in-tree** at `vendor/bundle/ruby/4.0.0/gems/` where a session reads a real API instead of recalling one.
- `Gemfile.lock` — one version set for all four contexts.

**Open follow-up, John's `system_files` repo (not this one):** `export PATH="$HOME/.local/share/mise/shims:$PATH"` in `~/.zshenv` would make mise resolve the project's pin in non-interactive shells too, closing the snapshot gap above. Offered, not done.

## What needed John, and what could not be done here

- **`libpq-dev`** required sudo with a password — John installed it (libpq 16.15). Without it the `pg` gem cannot build, which blocks `bundle install` and everything after it.
- **PostgreSQL** runs as a Docker container (`clementine-pg`, `postgres:17`, bound to `127.0.0.1:5432`), not a system service; the exact command is in `CLAUDE.md` Commands. Render's managed instance is the production equivalent (DEC-051).
- **Twilio step zero** (DEC-079) is still John's and still parallel. Nothing in the skeleton depends on it; the live-fire step at the end of Phase 1 does.
- **Render is untouched** — no service, no env group, no deploy. That is issue #8.
- `config/credentials.yml.enc` exists because the generator writes it, and `config/master.key` is gitignored. Phase 1 reads no credentials (P15 is environment variables), so Render needs `RAILS_MASTER_KEY` only if something later starts reading them.

## Verification

```
$ ruby -v
ruby 4.0.6 (2026-07-14 revision 03b6d3f889) +PRISM [x86_64-linux]

$ cat .ruby-version
ruby-4.0.6

$ bin/rails -v
Rails 8.1.3.1

$ bin/rails db:prepare
(exit 0)

$ bin/rspec
Finished in 0.03616 seconds (files took 0.63548 seconds to load)
3 examples, 0 failures

$ bin/rubocop
26 files inspected, no offenses detected

$ bin/brakeman --no-pager
No warnings found

$ bin/bundler-audit
No vulnerabilities found

$ bin/ci
✅ Continuous Integration passed in 11.95s

$ ls spec/fixtures/open_data/
camera-violation-strings-2026-09-20.json
dot-issued-violation-strings-2026-09-20.json
judgment-stage-rows-2026-09-20.json
open-rows-missing-violation-2026-09-20.json
plate-JPR7462-NY-2026-09-20.json
README.md

$ bundle exec ruby -e 'puts Gem.loaded_specs["twilio-ruby"].full_gem_path'
vendor/bundle/ruby/4.0.0/gems/twilio-ruby-7.11.2
```

`git status` is clean on `build/rails-skeleton`. The five JSON fixtures moved as pure renames — `git status` reported `R`, not `RM`, so no fixture's contents changed; only the folder README's closing line did.

## For the next session

There is no next brief by design. Take the lowest-ranked item in the [Clementine project](https://github.com/users/softwaregravy/projects/3) that is not Done — **#3, subscriptions** — read the issue, and work it to a pull request per `CLAUDE.md`. What that session needs that no issue carries:

- Start the database first: `docker start clementine-pg` (it is created with `--restart unless-stopped`, so a reboot brings it back on its own).
- `bin/rspec` and `bin/rubocop` must both be green before the pull request, and `bin/ci` runs the whole gate locally in about twelve seconds.
- The first migration will make `db/schema.rb` non-empty; CI's `db:test:prepare` step already expects that.
- **DEC-082** changes the daily run's shape (two passes, drift check between them) and lands in issue #7, not before.
