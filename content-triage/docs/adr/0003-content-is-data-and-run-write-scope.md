---
status: accepted
---

# Item content is data only, and a run writes only inside content-triage/data/

Items are written by other people, and a Skill-bucket item can turn into a skill that changes Claude's behaviour in all of AB's sessions. Thus a run never obeys instructions inside item text. It marks text that speaks to an AI agent with the Injection Flag. During a run, Claude writes only inside `content-triage/data/` (see ADR 0004), reads only `LEARNING/*/MISSION.md` and the skill registry `managed-skills.md` outside it, and uses the browser read-only (also for the one web link that it can follow from an X post). Each Skill-bucket proposal lists the risky needs of the skill (network, secrets, file deletes, shell commands) at the top, and the skill is checked again before AB saves it.

## Consequences

- An item with injection text goes to the Skip bucket, unless it also has real value. Then it keeps its bucket and the flag.
- Any later feature that writes outside `content-triage/data/` during a run needs a new ADR.
