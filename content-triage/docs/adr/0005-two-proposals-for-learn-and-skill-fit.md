---
status: accepted
---

# An item that fits both the Skill bucket and the Learn bucket gets two Proposals

Until now, a triage run gave each item one bucket and at most one Proposal. A short note ("also a Skill idea") named a second fit. Some items are both a repeatable method that Claude can do and a deep topic that needs study. For these items, AB wants both results: a skill and knowledge. Thus an item still has exactly one main bucket, and the Digest lists it only there. When the item fits both the Skill bucket and the Learn bucket with a fit score of 2 or more, the run writes two Proposals for it. One is a Skill-bucket proposal (`S-...`). The other is a Learn proposal (`L-...`). These are the Paired Proposals. Each names the ID of the other, so the Digest shows that they come from one item. Each waits for its own approval, so AB can approve one and reject the other. Nothing changes for the Mindset bucket and the Skip bucket. Nothing changes for an item that fits only one of the Learn bucket and the Skill bucket.

This ADR does not replace ADR 0002. ADR 0002 stays in force for each Paired Proposal. A run writes only a Proposal for these items. The work starts only after AB approves that Proposal. One approval never starts the other work. ADR 0003 also stays in force: the Skill-bucket proposal lists the risky needs of the skill at the top.

## Considered Options

- **Keep exactly one Proposal for each item, with a note for the second fit (the old rule).** Rejected: the note has no ID, so AB cannot approve it. AB would lose the second result. Or AB would have to start a second triage by hand.
- **Let an item be in two buckets.** Rejected: the Digest would list the item twice. One fit score would have to be true for two buckets. The counts in the Digest and the `bucket` field of the Seen Ledger would be unclear.
- **One combined Proposal that AB approves as a whole.** Rejected: AB could not approve one result and reject the other. This also breaks the rule of ADR 0002 that each piece of work waits for its own approval.
- **Write two Proposals for every item that fits both buckets, also with a fit score of 1.** Rejected: a Weak Fit item gets no Proposal. This would add noise to the Digest.
- **Write two lines in the Seen Ledger for one item.** Rejected: the `id` of a line must be unique. A line must stay one item. Two optional fields on the existing line keep older lines valid.
- **Count the second Proposal outside the limits of the Config File, or add new keys for it.** Rejected: the limits keep the Digest short. Each Proposal counts against the limit of its own letter, and no new key is needed.

## Consequences

- The Digest lists the item once, in its main bucket. It shows both Paired Proposals there, one after the other. The counts line counts the item once.
- The Seen Ledger keeps one line for each item. The optional fields `paired` and `paired_status` hold the second Proposal. A line without these fields is still valid.
- The commands `approve` and `reject` act on one ID. A group never adds the other Paired Proposal by itself.
- A run can write more Proposals for AB to decide on. The limits of the Config File still apply to each kind.
- A later change to more than two Proposals for one item (for example, with the Mindset bucket) needs a new ADR.
