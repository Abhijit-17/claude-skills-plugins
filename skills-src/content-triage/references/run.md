# The triage run (`run now`)

A **Triage Run** is often unattended (a **Scheduled Task**). Do not ask questions during a run. If something is not clear, take the safe choice, write it in the **Problems Section**, and continue.

`DATA` below means the **Data Folder**. `TODAY` means the run date in the user's time zone, as `YYYYMMDD` (IDs) or `YYYY-MM-DD` (files).

## Run options

- `run now`: all active sources and both Inboxes.
- `run now bookmarks` or `run now watch-later`: one Inbox only. Do not read the sources or the other Inbox. Do not move other Cursors.
- The option `all` (for example `run now bookmarks all`): read the full list. Do not stop at the first item that is in the Seen Ledger; skip each seen item and continue to the end of the list. Do not apply `first_run_max_items_per_source` or `first_run_max_inbox_items`. The output limits of the day still apply. Do not use `all` again on a list that a run already read in full (the handoff of 2026-11-15 says this for X Bookmarks).

## Step 1. Load the state

1. Read `DATA/config.md`. Use the value after each `=`. If a value is missing, use the default in [files.md](files.md). Note if `catch_up` = `yes` (**Catch-up Mode**).
2. Read `DATA/GOALS.md` and `DATA/sources.md`. Use only the rows with `active` = `yes`.
3. Read `DATA/state/seen.jsonl` (the **Seen Ledger**) and `DATA/state/cursors.json` (the **Cursors**).
4. If `sources.md` has no active rows and both Inboxes are empty, write a short digest that says "No sources yet: add rows to sources.md". Then stop.
5. If `GOALS.md` still has no life goals, continue. Score against the work goals only, and add one line to the Problems Section: "GOALS.md has no life goals yet".
6. Read the `MISSION.md` of each course in `LEARNING/` (read-only). Keep a short list: the course name and its mission in one line.
7. Read the registry `managed-skills.md` (read-only), if it exists, and note the names of the skills that the user already has. Also use the skill list of this session.

## Step 2. Expire old proposals

For each line in the Seen Ledger with `status` = `open` and a `proposal`: if the proposal is older than `proposal_expiry_days`, set `status` = `expired`. Do the same for `paired` and `paired_status`. Each of two Paired Proposals expires on its own.

## Step 3. Check the browser

1. Load the `built-in-browser` skill. Open a new tab.
2. If the browser is not reachable (no tools, or the calls fail): write the digest with only a Problems Section ("The built-in browser was not reachable. Is the Mac awake, online, and is the Claude desktop app open?"). Do not move any Cursor. Send the notification (Step 9) and stop. The next run catches up.

## Step 4. Collect new items

Follow [reading.md](reading.md). Read in this order:

1. YouTube: the Videos tab of each active YouTube source.
2. YouTube: the Watch later playlist (the YouTube **Inbox**).
3. X: the profile of each active X source.
4. X: the Bookmarks page (the X **Inbox**).

For each item that you find:
- If its key (`yt:<id>` or `x:<id>`) is already in the Seen Ledger, skip it. It is not new.
- First run of a source (no Cursor): read only the items from the last `first_run_days`, a maximum of `first_run_max_items_per_source`.
- First run of an Inbox: take a maximum of `first_run_max_inbox_items` (not with the option `all`). The older items above the limit get a ledger line with `bucket` = null and `status` = `backlog`. Do not triage them.
- **Old Inbox items.** An Inbox item older than `inbox_max_age_years` years gets a ledger line with `bucket` = null, `status` = `backlog`, and `note` = "older than <n> years". Do not triage it. For a video, use the age text ("7 years ago"). For an X post, use the post ID: the time in ms is `(id >> 22) + 1288834974657`.
- If a source fails, write the cause in the Problems Section and continue with the next source. Do not move its Cursor.

## Step 5. Get the content of each new item

**Fast Triage** (when there are more than `fast_triage_min_items` new items in this run, for example a large backlog):
1. Step A: give each item a first Fit Score from the list data only: the title (video) or the start of the text (post, about 150 characters).
2. Step B: do the full read below only for the items with a first Fit Score of 2 or more. Then give the final Fit Score.
3. The other items keep the first score. Add the flag `fast_triage`. A `promote` of such an item does the full read first. Be generous in Step A: if the title or the start is not clear, give 2, so that an important item is not lost.

With `fast_triage_min_items` new items or fewer, do the full read below for each item.

Follow [reading.md](reading.md): a part of the transcript of a video (start, middle, end), the full **Thread** of an X post, and one web link if the post's main content is a link. A **Pointer Post** becomes its YouTube video. Read the full transcript only in Step 7, for an item that gets a Short Read or a Proposal.

## Step 6. Triage

Follow [triage.md](triage.md) for each new item:

1. Check for the **Injection Flag**.
2. Check for a **Repeat** (the same idea as a ledger item from the last `repeat_window_days`).
3. Give the **Fit Score** (0 to 3) and the goal that it fits.
4. Choose exactly one main bucket. Then test for **Paired Proposals** ([triage.md](triage.md), section 4). If the item passes, it gets two Proposals. If not, note a second fit, if there is one.

Then apply the limits of `config.md`:
- Only items with a fit score of `min_fit_for_full_output` or more get a Short Read or a Proposal.
- **The limits are for each day, not for each run** (ADR 0007). First count the outputs that earlier runs of today already wrote (the IDs `R-TODAY-*`, `L-TODAY-*`, `S-TODAY-*` in the Seen Ledger). Only the rest of each limit is free for this run.
- In **Catch-up Mode**, use `catch_up_max_short_reads`, `catch_up_max_learn_proposals` and `catch_up_max_skill_proposals` instead of the normal limits.
- Sort each output type by fit score (then by the source note in `sources.md`, then by newest). Take items up to the free part of each limit. The extra items get one line under "More (not expanded)". They stay promotable.
- Paired Proposals need a fit score of 2 or more, and also `min_fit_for_full_output` or more. Use the higher value.
- A Proposal counts against the limit of its own letter: `L-...` against `max_learn_proposals`, `S-...` against `max_skill_proposals`. An item with two Paired Proposals uses one place in each limit. Go through the items in the sort order. An item with Paired Proposals needs room in both limits. If only the limit of its main bucket has room, write only the Proposal of the main bucket. Add the note "also a <bucket> idea". Use no place in the other limit. If the limit of its main bucket is full, the item goes under "More (not expanded)", as before.
- Choose the one **Top Pick**: the item with the highest value today.

## Step 7. Write the outputs

0. For each item with a full output and the flag `part_read`: read the full transcript first ([reading.md](reading.md), "How much to read").
1. For each Short Read: write `DATA/reads/YYYY-MM-DD-<slug>.md` (format: [files.md](files.md)), with the ID `R-TODAY-N`.
2. For each Proposal: give the ID `L-TODAY-N` or `S-TODAY-N`, and write it in the digest. For an item with Paired Proposals, give one `L-` ID and one `S-` ID. Write the "Paired with" line in both ([triage.md](triage.md), sections 6 and 7). Write both in the digest section of the main bucket.
3. **Revisit:** if this is the first run on or after a Monday (that is, no run since the latest Monday wrote a Revisit), choose one older read. It must be `revisit_min_age_days` to `revisit_max_age_days` old, not `kept`, not `dropped`, and shown fewer than `revisit_max_times`. Increase its `revisit_count`.
4. Write the digest `DATA/digests/YYYY-MM-DD.md` (template: [files.md](files.md)). If a digest for today exists, update it: add the new items to the sections, add the new problems, and make the counts line and the Top Pick true for the full day. Number the new IDs after the IDs of today that exist. Use a temp file and a rename.
5. Check the size (not in **Catch-up Mode**): the digest without the links must take `digest_read_minutes` or less to read (about 230 words for each minute). If it is longer: first give each Weak Fit bucket only a count in the digest ("Weak Fit: <n>, see the Digest Page") and keep the lines on the Digest Page; then write Skip as one line for each source ("<source>: <n> skipped").
6. **ASD-STE100 check** (if `language` = ASD-STE100): before you save, read each Short Read, Proposal and the Top Pick sentence again. Fix these points: a sentence longer than 20 words (procedure) or 25 words (description); passive voice where active is possible; more than one instruction in a sentence; a word that has a simpler approved word (for example "use", not "utilize"); an `-ing` word used as a noun. Do not change titles, names or quotes from the source.

## Step 8. Save the state

1. Add one line to the Seen Ledger for each item that you saw (format: [files.md](files.md)). Use a temp file and rename it. An item with Paired Proposals is still one line. Write the ID of the Proposal of the main bucket in `proposal`. Write the other ID in `paired`. Set `status` and `paired_status` to `open`.
2. Add the count of new items of this run to `_run_items` in `cursors.json` (keep the last 2). In **Catch-up Mode**: if both counts are less than `catch_up_end_items`, add "Catch-up can stop: say `catch-up off`" to the Action needed section. Do not change `catch_up` by yourself.
3. Move the Cursor of each source that you read with no failure. Do not move the Cursor of a failed source. Count the failures in a row for each source. If a source failed `source_fail_alert_runs` times in a row, put it at the top of the digest as an action for the user.
4. Do not run `git` in the Data Folder. The user commits it from the Mac Terminal.

## Step 9. Publish and notify

1. Update the **Digest Page** ([digest-page.md](digest-page.md)). If this fails, the run still succeeds: the Markdown digest is the record. Add one line to the Problems Section of the digest file.
2. Send a short notification: "Digest ready: <N> items, Top pick: <title>". Use the push-notification tool if this session has one. Otherwise, the final message of the run is the notification.
3. In the final message, give the digest summary: the Top Pick, the counts for each bucket, the open Proposal IDs, and the problems.
