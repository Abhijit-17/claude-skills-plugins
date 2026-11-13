---
status: accepted
---

# AB's personal data lives in content-triage/data/, which the public repo ignores

The folder `SkillsPlugins` is a clone of the public repo `Abhijit-17/claude-skills-plugins`. The goals, sources, digests, reads and Seen Ledger are personal. Thus they live in `content-triage/data/`. The public repo's `.gitignore` ignores this folder, and it is its own local git repo that is never pushed to a public place. The public part of `content-triage/` holds only the glossary, the ADRs and the skill source. The skill has no personal data in it, so other people can use it with their own data folder.

## Consequences

- Before each commit to the public repo, check that `git status` shows no file from `data/`.
- AB does the git commits of `data/` from the Mac Terminal, because git from the Mac shell cannot remove its own lock files.
- The `.gitignore` line is added at build time, before the first file goes into `data/`.
