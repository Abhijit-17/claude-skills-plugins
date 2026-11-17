# File formats in the Data Folder

```
ContentTriage/                  (the Data Folder; private; its own local git repo, no remote; ADR 0009)
├── CLAUDE.md                   The rules for sessions of the Content Triage project.
├── queue.md                    Work that the user asked for: promotes, links to add, decisions to remember.
├── tools/git-agent.sh          Commits the folder and cleans the lock files that git leaves.
├── GOALS.md                    AB owns it. Never change it by yourself.
├── sources.md                  The Source List (a Markdown table).
├── config.md                   The limits (key = value).
├── .gitignore                  Has the line `/digest-page/`.
├── digests/YYYY-MM-DD.md       One Digest for each day (the record). A second run on the same day updates it (ADR 0007).
├── digest-page/index.html      The source of the Digest Page. Made again by each run. Ignored by git.
├── reads/YYYY-MM-DD-<slug>.md  One file for each Short Read (the Read Library).
└── state/
    ├── seen.jsonl              The Seen Ledger.
    └── cursors.json            The Cursors and the failure counts.
```

Write every file in `state/` and every changed file to `<name>.tmp` first, then rename it over the old file.

## config.md defaults

If a key is missing, use this value:

| Key | Default | Key | Default |
|---|---|---|---|
| max_short_reads (each day) | 3 | first_run_days | 7 |
| max_learn_proposals (each day) | 3 | first_run_max_items_per_source | 10 |
| max_skill_proposals (each day) | 3 | first_run_max_inbox_items | 50 |
| min_fit_for_full_output | 2 | proposal_expiry_days | 30 |
| digest_read_minutes | 10 | revisit_min_age_days | 14 |
| max_posts_per_x_profile | 20 | revisit_max_age_days | 90 |
| max_link_words | 5000 | revisit_max_times | 2 |
| seconds_between_pages | 4 | source_fail_alert_runs | 3 |
| repeat_window_days | 30 | language | ASD-STE100 |
| digest_page_url | (empty: create a page) | transcript_part_words | 500 |
| catch_up | no | catch_up_max_short_reads | 5 |
| catch_up_max_learn_proposals | 5 | catch_up_max_skill_proposals | 5 |
| catch_up_end_items | 30 | fast_triage_min_items | 40 |
| inbox_max_age_years | 3 | | |

The skill can write only two keys by itself: `digest_page_url` (after the first publish of the Digest Page) and `catch_up` (only on the user's command `catch-up on` or `catch-up off`).

**Catch-up Mode** (`catch_up = yes`): the user is clearing a large backlog. The `catch_up_max_*` limits replace `max_short_reads`, `max_learn_proposals` and `max_skill_proposals`. The digest has no read-time limit (`digest_read_minutes` does not apply), and each Weak Fit item keeps its full line. See [run.md](run.md), Step 6 and Step 7.

## state/seen.jsonl (the Seen Ledger)

One JSON object on each line. The key `id` is unique. Never remove a line. Change a line only to update `status`, `proposal`, `paired`, `paired_status`, or `note`.

```json
{"id":"yt:VIDEOID","url":"https://www.youtube.com/watch?v=VIDEOID","title":"...","source":"Martin Kleppmann","platform":"youtube","from":"source","first_seen":"2026-11-04","bucket":"Learn","fit":3,"goal":"distributed systems","proposal":"L-20261104-1","read":null,"status":"open","flags":["no_transcript"],"note":""}
```

An item with Paired Proposals is still one line. It has two more fields:

```json
{"id":"yt:VIDEOID","url":"https://www.youtube.com/watch?v=VIDEOID","title":"...","source":"SOURCE NAME","platform":"youtube","from":"source","first_seen":"2026-11-13","bucket":"Skill","fit":3,"goal":"GOAL NAME","proposal":"S-20261113-1","paired":"L-20261113-2","read":null,"status":"open","paired_status":"open","flags":[],"note":""}
```

| Field | Values |
|---|---|
| `id` | `yt:<video id>` or `x:<post id>` (for a Thread: the first post) |
| `from` | `source`, `inbox`, or `chat` (a link that the user gave with `add`) |
| `bucket` | `Learn`, `Skill`, `Mindset`, `Jobhunt`, `Skip`, or null (backlog) |
| `fit` | 0 to 3, or null (backlog) |
| `proposal` | `L-...` or `S-...`, or null. For an item with Paired Proposals: the Proposal of the main bucket. For a Mindset item after `promote <key> skill`: the `S-...` Proposal (ADR 0006) |
| `paired` | Optional. The ID of the other Paired Proposal: `S-...` if the main bucket is Learn, `L-...` if it is Skill. A missing field is null: no Paired Proposal |
| `paired_status` | Optional. `open`, `approved`, `rejected`, or `expired`: the status of the Proposal in `paired`. A missing field is null |
| `read` | `R-...`, or null |
| `status` | `done` (no further action), `open` (proposal waits), `approved`, `rejected`, `expired`, `backlog`, `jobhunt` (Jobhunt line, promotable), `weak` (Weak Fit, promotable), `more` (not expanded, promotable) |
| `flags` | any of `no_transcript`, `link_not_read`, `injection`, `repeat`, `part_read` (only parts of a long transcript were read; see reading.md), `fast_triage` (scored from the title and the start of the text only; see run.md Step 6) |
| `note` | free text, for example the reject reason, "repeat of yt:...", "also a Mindset idea" |

A Short Read item has `status` = `done`. The read's own state (kept, dropped, revisits) is in its read file. After `promote <key> skill`, a Mindset item has both `read` and `proposal`; then `status` is the status of the Proposal (ADR 0006).

An item has two Proposals at most. An older ledger line has no `paired` and no `paired_status`. It is still valid: read a missing field as null. Do not add the two fields to a line with one Proposal. For an item with Paired Proposals, `status` is the status of the Proposal in `proposal` only. `paired_status` is the status of the Proposal in `paired`. Each Proposal changes status on its own. If the line has `paired`, start each text that you add to `note` with the Proposal ID and a colon, for example `S-20261113-1: skill proposed`. Separate two texts with ` | `.

## state/cursors.json

```json
{
  "youtube:https://www.youtube.com/@handle": {"cursor": "VIDEOID", "last_ok": "2026-11-04", "fails": 0},
  "x:https://x.com/handle": {"cursor": "1853000000000000000", "last_ok": "2026-11-04", "fails": 0},
  "inbox:youtube-watch-later": {"cursor": null, "last_ok": "2026-11-04", "fails": 0},
  "inbox:x-bookmarks": {"cursor": "1853000000000000000", "last_ok": "2026-11-04", "fails": 0},
  "_last_run": "2026-11-04",
  "_last_revisit": "2026-11-02",
  "_run_items": [117, 357]
}
```

The key is `<platform>:<link from sources.md>`. `fails` counts the failed runs in a row. Set it to 0 after a run with no failure. `_run_items` holds the counts of new items of the last 2 runs, newest last (for the end of **Catch-up Mode**).

## reads/YYYY-MM-DD-slug.md (one Short Read)

```md
---
id: R-20261104-1
item: x:1853000000000000000
source: <name>
link: <url>
goal: <goal>
created: 2026-11-04
state: active        # active | kept | dropped
revisit_count: 0
last_revisit: null
---

<the Short Read text, as in the digest>
```

The "Kept" list is the set of read files with `state: kept`.

## digests/YYYY-MM-DD.md (one Digest)

One file for each day. A second run on the same day (or an `add` command) updates the file of that day: the counts, the sections and the Problems cover all the runs of the day (ADR 0007). Sections in this order. Leave out an empty section, except "Problems" (write "None."). Count each item once, in its main bucket, also when it has Paired Proposals. Write both Paired Proposals in the section of the main bucket, with the Proposal of the main bucket first.

```md
# Digest YYYY-MM-DD

<N> new items · Learn <n> · Skill <n> · Mindset <n> · Jobhunt <n> · Skip <n> · from <sources read>/<sources active> sources · <r> runs today<; Catch-up Mode, if on>

## Action needed
<only if a source failed source_fail_alert_runs times in a row, a setup problem, or "Catch-up can stop: say `catch-up off`">

## Top pick
<title> · <link> · <bucket> · fits: <goal>
<one sentence: why it is the top pick today>

## Open proposals
<each proposal with status open, oldest first, with its age in days: "L-20261101-2 · <topic> · 3 days">
<read `status` and `paired_status`. Each Paired Proposal has its own line, with the other ID at the end: "S-20261113-1 · <topic> · 0 days · paired with L-20261113-2">
Reply in a chat: `approve <ID>`, `reject <ID> [reason]`.

## Learn
<Learn proposals (template in triage.md)>
<if the main bucket is Learn and the item has Paired Proposals: the Learn proposal first, then the Skill-bucket proposal>
<Weak Fit lines>

## Skill bucket
<Skill-bucket proposals>
<if the main bucket is Skill and the item has Paired Proposals: the Skill-bucket proposal first, then the Learn proposal>
<Weak Fit lines>

## Mindset
<Short Reads>
<Weak Fit lines>

## Jobhunt
<one line for each Jobhunt item (template in triage.md, section 8); never shortened to a count>

## Revisit
<only in the first run on or after a Monday>
R-YYYYMMDD-N · <title> (<age> days ago). Did you try this action? Reply `kept <R-ID>` or `drop <R-ID>`.
<the "Try this" line of the read>

## More (not expanded)
<lines>

## Skip (<n>)
<details><summary>Show the skipped items</summary>

<Skip lines>

</details>

## Problems
<one line for each failed source, missing file, unread link, or warning, with the action for the user; or "None."
Only failures and decisions for the user go here. Information (for example "Watch later: 1 new item") goes in the counts line or nowhere.>
```
