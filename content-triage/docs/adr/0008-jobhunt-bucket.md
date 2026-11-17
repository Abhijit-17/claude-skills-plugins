---
status: accepted
date: 2026-11-16
---

# A fifth bucket, Jobhunt, keeps the job-search items for later

AB bookmarks many posts about job search: interviews, pay data, companies that hire, search methods. GOALS.md has no job-search goal yet, so the triage gave these items a low Fit Score, and most went to the Skip bucket or became Weak Fit lines in other buckets. AB will look for a new job later and wants these items in one place then. Thus there is a fifth bucket, Jobhunt. An item that helps with a future job search goes there, also with a Fit Score of 0. A Jobhunt item gets one line in the Digest, with no Short Read and no Proposal, and it uses no place in the daily limits. Its ledger `status` is `jobhunt`, and AB can `promote` it.

AB decided on 2026-11-16 that only new items use the Jobhunt bucket. The earlier job-search items stay as they are. The job-search items of the run of 2026-11-16 were moved to Jobhunt by hand.

## Considered Options

- **Keep the items as Weak Fit or Skip until GOALS.md has the goal.** Rejected: the Skip items are hard to find later, and the Weak Fit lines are spread over three buckets.
- **Add a job-search goal to GOALS.md now.** Rejected for now: AB is not looking for a job yet. A goal would give these items Short Reads and Proposals and use the daily limits.
- **Move all earlier job-search items to Jobhunt.** Rejected by AB: new items only.

## Consequences

- The Digest has a Jobhunt section after Mindset. Its lines are never shortened to a count.
- When GOALS.md gets a job-search goal, a new ADR decides if Jobhunt items get full outputs in a run.
