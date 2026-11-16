---
status: accepted
date: 2026-11-16
---

# The output limits are for each day, and each day has one Digest

The limits in the Config File (for example `max_learn_proposals = 3`) applied to each run. On 2026-11-14, two runs on one day gave 6 Learn proposals and 6 Skill-bucket proposals, and each run wrote its own Digest. A combined Digest was then made by hand. AB reads one Digest each day. Thus the limits now apply to each day, in the user's time zone. A run first counts the outputs that earlier runs of the same day wrote, and uses only the rest of each limit. A second run on the same day does not write a new file: it updates the Digest of that day. The counts, the sections, the Top Pick and the Problems Section then cover all the runs of the day.

## Considered Options

- **Limits for each day, but one Digest file for each run.** Rejected: AB would have to read two files and find the open proposals in both.
- **Limits for each run (the old rule).** Rejected: the number of proposals for AB depends on how many runs there were, and the limits stop doing their job.

## Consequences

- The file name is always `digests/YYYY-MM-DD.md`. The old `YYYY-MM-DD-2.md` names stay as a record. New runs do not make them.
- An update of the Digest of the day uses a temp file and a rename (SKILL.md rule 6).
- The IDs of a day continue: a second run starts after the last `L-`, `S-` and `R-` ID of the day.
- **Catch-up Mode** uses other numbers (`catch_up_max_*`), but they are also for each day.
- Outputs that AB asks for in a chat (`add`, `promote`, `promote <key> skill`) do not count against the daily limits.
