---
status: accepted
date: 2026-11-16
---

# AB can ask for a Skill-bucket Proposal from a Mindset item

An item with the main bucket Mindset gets a Short Read and, if it also fits the Skill bucket, only the note "also a Skill idea". The note has no ID, so AB cannot approve it. On 2026-11-15, AB asked for skills from two Mindset items, and the skills were drafted by hand. Thus AB can now give the command `promote <key> skill` for a Mindset item. The command writes one Skill-bucket Proposal (`S-...`) for the item. The item keeps its main bucket Mindset, its fit score and its Short Read. The run never does this by itself: only AB's command starts it.

This ADR does not replace ADR 0002 or ADR 0005. The new Proposal waits for its own `approve <ID>`. An item still has two Proposals at most. A Mindset item has no Learn Proposal, so it has one Proposal after this command.

## Considered Options

- **Paired output in the run (a Short Read and a Skill-bucket Proposal for each Mindset item that also fits the Skill bucket).** Rejected: a run would write more Proposals, and the Digest would be longer. Most "also a Skill idea" notes are weak. AB wants to choose.
- **No change (keep the note).** Rejected: AB must then ask for the skill outside the skill's flow, with no ID and no record in the Seen Ledger.

## Consequences

- The Seen Ledger line keeps `bucket` = `Mindset` and `read`, and gets `proposal` = `S-...`. Its `status` is then the status of the Proposal (`open`, `approved`, ...). The state of the Short Read stays in its read file.
- The Proposal does not count against the daily limits, because AB asked for it.
- The Proposal has the line "From Mindset item", so the Digest and `status` show where it came from.
- An earlier Mindset line with a skill that was drafted by hand (the two items of 2026-11-15) keeps its ledger note. It needs no Proposal.
