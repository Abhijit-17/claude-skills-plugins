---
status: accepted
date: 2026-11-17
---

# The Data Folder moves out of the skills repo into its own folder

ADR 0004 put the Data Folder inside the public skills repo (`SkillsPlugins/content-triage/data/`), ignored by git and with its own local git repo. AB made the SkillsPlugins repo and its claude.ai project to build and maintain skills only. Runs of content-triage, AB's decisions and the private data are a different job. Thus the Data Folder is now `~/Downloads/WORKSPACE/ContentTriage/`, a folder outside every public repo. It keeps its own local git repo, with its full history, and it has no remote. A separate claude.ai project, Content Triage, does the runs and the commands (`run now`, `add`, `approve`, `promote`, ...) in that folder. The Skills Plugins project keeps the skill source, the glossary and the ADRs, and builds new versions.

This ADR replaces the location part of ADR 0004. The rest of ADR 0004 stays in force: the data is private, and no part of it goes into the public repo or into a skill.

## Considered Options

- **Keep the Data Folder in SkillsPlugins.** Rejected by AB: it mixes skill building with skill use in one repo and one project.
- **Put the skill source in ContentTriage too.** Rejected: all of AB's skills are built, checked, zipped and registered in SkillsPlugins.

## Consequences

- The skill looks for `ContentTriage/` first; the old path is a fallback only.
- The Data Folder has its own copy of `tools/git-agent.sh`, so the Content Triage project needs no access to SkillsPlugins.
- When an approved Skill-bucket Proposal needs a new skill, the Content Triage project writes a handoff for the Skills Plugins project. It does not build the skill.
- The Scheduled Task connects the folders `ContentTriage` and `~/Downloads/LEARNING`.
