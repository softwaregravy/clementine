# Doc cascade DEC-064–081 — report

**Status:** done · **Brief:** `docs/handoffs/2026-09-20-cascade.md` · **Branch:** `phase1-readiness-review` · **Nothing pushed.**

All eight files done, one commit each, in the brief's order. No decision was made: every changed sentence traces to `DECISIONS.md` §9 or to an earlier entry those decisions amend. **No `TODO(john)` was needed** — see *Editorial calls* below for the judgment calls that were made inside the brief's rules, and *Unsourced facts* for three data claims that came from the brief rather than from `DECISIONS.md` or a fixture.

**A note on dates.** Every date written into the documents is **2026-09-20** — the decision date, as the brief prescribes. The session executing the cascade ran past midnight into 2026-09-21; nothing in the docs reflects that, deliberately.

## Commits

| # | Commit | File |
|---|---|---|
| 1 | `d724f31` | `docs/prd.md` → v0.10 |
| 2 | `8bf14e9` | `CLAUDE.md` |
| 3 | `affb839` | `README.md` |
| 4 | `673d5de` | `docs/messaging.md` |
| 5 | `6bef020` | `docs/open-data-reference.md` |
| 6 | `713bce0` | `docs/phase1-design.md` → v0.3 |
| 7 | `513f629` | `docs/open-questions.md` |
| 8 | `6c19de9` | `docs/fixtures/open-data/README.md` (new) |

Plus this report and the brief's `Status:` flip.

## TODO(john) left: none

Every sentence the brief named, and every consequential sentence it did not, was covered by an existing decision. Nothing was resolved by guessing.

## Editorial calls made inside the brief's rules

These are changes the brief did not enumerate line-by-line but that DEC-064–081 forced. Each retires superseded text rather than deciding anything new — listed so the reviewing session can check them cheaply.

1. **`CLAUDE.md` line 3** — "invite-only NYC parking-ticket monitoring" → "invite-only monitoring of open NYC violations". Same change the brief prescribes for the README tagline; DEC-065 supersedes the scope claim wherever it appears.
2. **"the classifier" as a named component** — deleted where it named code that DEC-065 removed: PRD §6 skip-log ("a row shape exists the **classifier** can't yet handle" → "the **run** can't yet account for"), PRD §10 ("logged at WARN for later **classifier** work" → "as residue"), README glossary ("to drive **classifier** enhancements" → "later enhancements").
3. **"unclassifiable residue" kept** in PRD §6 — it is DEC-044's own vocabulary, and DEC-044 is unamended. It labels the residue; it does not describe a classifier.
4. **Digest copy contract, `docs/messaging.md`** — "must not contain … the word 'parking'" was qualified to "**in the copy** (the CityPay URL path is not copy)". The link is `…/citypay/Parking`, so the unqualified rule would be untestable and self-contradictory. Disambiguation, not a new rule.
5. **PRD §11** — deleted the whole sentence "The open predicate is pinned (`amount_due` int > 0); the camera filter strategy is pinned (blocklist)…": the brief says delete the camera-filter sentence, and the predicate clause in the same sentence is superseded by DEC-064. Also deleted "The judgment/interest-stage behavior of this dataset is unobserved in the sample" — closed by DEC-080 (C2).
6. **PRD §10 scam adjacency** — "every digest **and alert** arrives from that same number" → "every digest arrives…". It described an Alert that sends.
7. **README repository map** — "`docs/open-questions.md` | Unknowns, **pending vetoes**, and next actions" → "The remaining unknowns and the next actions": the veto pass closed with DEC-078.
8. **Design doc section titles** — §9, §10, §11 and the deployment section still read "**proposed batch**"; retitled "decided (DEC-078)", and §8's "closed with D6 + proposals" → "closed with D6, batch decided". Also merged a duplicated `## Changelog` heading created when the stale banner was replaced.
9. **`docs/open-questions.md` §C1, §E1, §F** — pointers that dangled once the cascade landed: C1's "list SODA 2.1 deprecation as a PRD §10 risk" is now done (only the header-name confirmation stays open); E1's "must take the rewording before registration" is now done; §F dropped the doc-cascade item and renumbered, with a one-line note that it completed.
10. **New PRD §10 risk bullets** were inserted after **Detection lag**, grouping them with the read-path risks rather than appending at the end.

## Unsourced facts — flagged, not invented

Rule 4 says every data claim must already appear in `DECISIONS.md`, `docs/open-data-reference.md` or a fixture. Three claims the brief instructed me to write meet none of those tests; they come from the brief itself, written by the session that ran the probes. They are now in the docs as the brief specified — confirm or drop them:

- **"about 6.4% of the dataset"** (archival sparse rows) — PRD §6, §10; `open-data-reference.md`. `DECISIONS.md` DEC-069 gives the six-key shape and the 2014–2025 span, but no percentage.
- **"2,000 of 2,000 sampled were identical in shape"** — `open-data-reference.md`.
- **"aggregate group-bys take 30–140 s"** — `open-data-reference.md`, fixtures README.
- **"no negative values observed"** in the `amount_due` row — `open-data-reference.md`. DEC-064 tests `"-25"` as a WARN-and-open input but does not say none exist in the data.

Everything else was checked against `DECISIONS.md`, the fixtures (re-read this session: 136 rows / 7 open / 1 archival / 2 camera; the six archival keys; `"93.76"`, `"267.13"`, `state = "99"`; the camera and DOT string counts) or the existing reference doc.

## What I could not do

**`docs/handoffs/README.md` still lists this brief as `open`.** Its own convention says to flip the status in the index table, but the brief's rule 1 forbids editing any other file under `docs/handoffs/`. The guardrail won. Whoever picks this up next should flip that one table row.

Nothing else in the brief was left undone.

## Verification

- **Off-limits files untouched.** `git diff 13e50aa..HEAD --stat` (this session's first commit's parent → HEAD) lists exactly the eight permitted files. `DECISIONS.md`, `docs/mvp-readiness.md`, `docs/citypay-reference.md` and every fixture JSON: zero changes.
- **Versions and changelogs.** `docs/prd.md` v0.10 with a `v0.9 → v0.10` changelog above the retained v0.8 → v0.9 block, header dated 2026-09-20. `docs/phase1-design.md` v0.3 with a v0.3 changelog entry above v0.2/v0.1, status "Decided; proposed batch confirmed 2026-09-20". The other five files carry no version block; their dated headers and status lines were updated.
- **`git status` clean** after the last commit.
- **Stale-term grep: 93 hits, 0 defects.** Nothing describes a filter, a nickname, an Alert that sends, an integer cast, retries in Phase 1, or a canary in Phase 1. Full annotated output below.

## Final grep output, annotated

Command, run from the repo root:

```
grep -n -i -E 'nickname|alert|camera|blocklist|classif|cast to integer|Integer\(|three (send|templates)|Solid Queue or Sidekiq|parking ticket|retr(y|ies)|canary|probe-gated|stale' \
  docs/prd.md CLAUDE.md README.md docs/messaging.md docs/open-data-reference.md docs/phase1-design.md docs/open-questions.md
```

Hits by file: `docs/prd.md` 49 · `docs/open-data-reference.md` 18 · `docs/phase1-design.md` 10 · `README.md` 6 · `CLAUDE.md` 5 · `docs/messaging.md` 3 · `docs/open-questions.md` 2.

`docs/prd.md:8` [classif]
    New changelog: names the pass's through-line (minimum classification).
`docs/prd.md:12` [integer(]
    New changelog: why the integer cast died — `Integer()` raises on cents.
`docs/prd.md:13` [blocklist, camera, classif, parking ticket]
    New changelog: states there is no filter, no blocklist, no "parking tickets".
`docs/prd.md:15` [canary, retries, retry]
    New changelog: states no retries, no canary.
`docs/prd.md:16` [alert]
    New changelog: "alert the maintainer" = the ERROR log, not a send.
`docs/prd.md:17` [alert, classif]
    New changelog: states the Alert is cut.
`docs/prd.md:19` [nickname]
    New changelog: states there is no nickname.
`docs/prd.md:36` [cast to integer]
    v0.9 changelog — historical; kept per brief, superseded by DEC-064 above.
`docs/prd.md:37` [alert]
    v0.9 changelog — historical; superseded by DEC-071/077 above.
`docs/prd.md:38` [alert]
    v0.9 changelog — historical; the Alert's arrival, cut by DEC-077 above.
`docs/prd.md:39` [alert]
    v0.9 changelog — historical; §9 reworded in the body.
`docs/prd.md:40` [blocklist, camera, parking ticket]
    v0.9 changelog — historical; blocklist retired by DEC-065 above.
`docs/prd.md:41` [alert]
    v0.9 changelog — historical; drift reworked by DEC-069 above.
`docs/prd.md:42` [alert, retries, retry]
    v0.9 changelog — historical; retries removed by DEC-072 above.
`docs/prd.md:43` [camera, classif]
    v0.9 changelog — historical; "unclassifiable residue" is DEC-044's term.
`docs/prd.md:62` [parking ticket]
    §1 Problem — parking is the motivating problem; legitimate survivor per brief.
`docs/prd.md:83` [nickname]
    §3 — states the subscription has no nickname.
`docs/prd.md:84` [alert]
    §3 — Phase 2 health alerting.
`docs/prd.md:89` [camera]
    §4 In — camera rows are in scope and counted.
`docs/prd.md:92` [camera]
    §4 Out — camera-specific *features*, per the brief's wording.
`docs/prd.md:96` [camera]
    §4 — the Phase 3 quote question (DEC-010).
`docs/prd.md:100` [camera]
    §5 — the dataset's own name.
`docs/prd.md:102` [camera]
    §5 — the camera penalty schedule, per the brief's replacement sentence.
`docs/prd.md:104` [alert]
    §5 Landscape — "no official proactive ticket alerting exists"; unrelated sense.
`docs/prd.md:105` [alert]
    §5 — two templates; states the Alert is cut.
`docs/prd.md:111` [nickname]
    §6 Data — states there is no nickname.
`docs/prd.md:122` [blocklist, camera, classif]
    §6 — the No-classification bullet, which says there is no filter or blocklist.
`docs/prd.md:130` [classif]
    §6 skip-log — "unclassifiable residue" is DEC-044's own (unamended) vocabulary.
`docs/prd.md:134` [parking ticket]
    §6 Digest — the prohibition: never "parking tickets".
`docs/prd.md:136` [alert, classif]
    §6 — states the Alert is cut and banked.
`docs/prd.md:142` [retries, retry]
    §6 Retries — states there are none in Phase 1.
`docs/prd.md:154` [alert, canary, retries]
    §6 Phase 2 — where the Alert, canary and retries return.
`docs/prd.md:159` [alert]
    §6 Phase 2 — health alerting.
`docs/prd.md:160` [alert]
    §6 Phase 2 — exit criterion for the health alert.
`docs/prd.md:164` [camera]
    §6 Phase 3 — the camera-in-a-quote question (DEC-065).
`docs/prd.md:173` [retries]
    §6 Phase 3 — checkout retries; not the Phase 1 read path.
`docs/prd.md:174` [alert]
    §6 Phase 3 — unauthorized-submission alert.
`docs/prd.md:175` [alert]
    §6 Phase 3 — post-hoc send timing.
`docs/prd.md:182` [alert]
    §7 Reliability — Phase 2 health alerting; sustained-outage risk named.
`docs/prd.md:184` [alert, retries]
    §7 Observability — "with retries gone"; states there are none.
`docs/prd.md:204` [alert]
    §10 — Phase 2 health alerting.
`docs/prd.md:206` [alert, retries]
    §10 — the sustained-outage risk: "after DEC-072 no retries either".
`docs/prd.md:207` [canary]
    §10 — the empty-dataset risk: the canary is cut and banked.
`docs/prd.md:218` [alert]
    §10 eCheck returns — Phase 2/3 re-alerting.
`docs/prd.md:227` [camera]
    §11 — the Phase 3 camera-in-a-quote standing note.
`docs/prd.md:233` [alert, canary, retries]
    §12 M3 — Phase 2 milestone: Alert, canary and retries return there.
`docs/prd.md:239` [camera]
    References — the dataset's published name.
`docs/prd.md:240` [camera]
    References — the NYC service page's name.
`docs/prd.md:241` [camera, parking ticket]
    References — the NYC 311 page's name.
`CLAUDE.md:25` [camera, classif]
    Invariant 5, per the brief verbatim: camera *features* out, classification out.
`CLAUDE.md:34` [blocklist, camera, classif]
    Rules — the No-classification bullet: no filter, no blocklist.
`CLAUDE.md:36` [retries]
    Rules — states there are no retries.
`CLAUDE.md:37` [canary]
    Rules — states there is no canary in Phase 1.
`CLAUDE.md:41` [parking ticket]
    Rules — the copy prohibition: never "parking tickets".
`README.md:3` [alert]
    Tagline — "SMS alerts" in the ordinary sense, per the brief's wording.
`README.md:9` [parking ticket]
    The problem — legitimate survivor per brief.
`README.md:15` [camera]
    What Clementine does — camera rows are in scope.
`README.md:35` [camera]
    How it works — the dataset's own name.
`README.md:36` [classif, retries]
    How it works — "no classification"; "No retries in Phase 1."
`README.md:42` [retries]
    Stack — "no retries", per the brief.
`docs/messaging.md:12` [alert]
    States the Alert is cut and banked; "alert the maintainer" = the ERROR log.
`docs/messaging.md:34` [nickname, parking ticket]
    Records that the samples were reworded away from nickname/"parking tickets".
`docs/messaging.md:43` [parking ticket]
    Vocabulary — the prohibition itself (DEC-065).
`docs/open-data-reference.md:1` [camera]
    Title — the dataset's own name.
`docs/open-data-reference.md:7` [camera]
    The dataset page URL.
`docs/open-data-reference.md:28` [classif]
    `violation` row — "Phase 1 classifies nothing".
`docs/open-data-reference.md:33` [parking ticket]
    `issuing_agency` row — DOT writes ordinary parking tickets, so it never discriminated.
`docs/open-data-reference.md:46` [classif]
    Row shape — counterfactual: "under a classifier" (DEC-068, struck).
`docs/open-data-reference.md:48` [camera]
    Camera rows marked **reference only**: "No filter exists".
`docs/open-data-reference.md:56` [camera]
    A camera `violation` string, quoted from the fixture.
`docs/open-data-reference.md:57` [camera]
    A camera `violation` string, quoted from the fixture.
`docs/open-data-reference.md:58` [camera]
    A camera `violation` string, quoted from the fixture.
`docs/open-data-reference.md:60` [camera, parking ticket]
    The two traps a filter would have hit; data fact, no filter exists.
`docs/open-data-reference.md:70` [blocklist, camera, classif]
    Counting rule 2 — "No classification": no filter, no blocklist.
`docs/open-data-reference.md:76` [retries]
    Counting rule 8 — "no retries".
`docs/open-data-reference.md:80` [canary]
    Banked for Phase 2 — the canary, explicitly cut from Phase 1.
`docs/open-data-reference.md:81` [alert]
    Banked for Phase 2 — the Alert, explicitly with no Phase 1 trigger.
`docs/open-data-reference.md:82` [retries, retry]
    Banked for Phase 2 — retries, as a two-pass batch.
`docs/open-data-reference.md:90` [camera]
    Fixtures table — the plate pull contains 2 camera rows.
`docs/open-data-reference.md:93` [camera]
    Fixtures table — the camera-strings fixture, reference only.
`docs/open-data-reference.md:94` [parking ticket]
    Fixtures table — DOT writes parking tickets, so the issuer carries no signal.
`docs/phase1-design.md:8` [probe-gated, retries, stale]
    v0.3 changelog — records that the stale banner and probe-gated §7 were retired and that A1 is superseded.
`docs/phase1-design.md:9` [probe-gated]
    v0.2 changelog — historical entry, unchanged.
`docs/phase1-design.md:17` [classif]
    §0 inherited-fixed — "no classification".
`docs/phase1-design.md:18` [retries, retry]
    §0 — "The retry line (A1) never landed: Phase 1 has no retries".
`docs/phase1-design.md:32` [alert, retries, retry, solid queue or sidekiq]
    D5 — quotes PRD §8's old "Solid Queue or Sidekiq" as the line it settles; states no retries.
`docs/phase1-design.md:38` [camera, classif, probe-gated]
    §7 — "The probe-gated questions ... are moot"; no camera discrimination.
`docs/phase1-design.md:42` [retries]
    §7 — "no retries".
`docs/phase1-design.md:45` [blocklist, classif]
    §7 — "No classification": no filter, no blocklist.
`docs/phase1-design.md:89` [alert]
    P20 — Phase 2 alerting.
`docs/phase1-design.md:100` [retries, retry]
    A1 — "superseded by DEC-072 ... Phase 1 has no retries at all".
`docs/open-questions.md:27` [camera]
    D4 — the Phase 3 camera-in-a-quote question.
`docs/open-questions.md:31` [alert, nickname, parking ticket]
    E1 — states the Alert is cut and the nickname/"parking tickets" rewording has landed.

TOTAL: 93 hits
