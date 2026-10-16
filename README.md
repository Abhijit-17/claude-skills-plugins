# claude-skills-plugins

The Claude skills and tools that I use on Claude desktop, Claude cloud sessions, Projects and Claude Code. Written in ASD-STE100.

## Contents

| Path | What it is |
|---|---|
| `skills/` | Skill zips. Upload in claude.ai: **Customize > Skills**. |
| `skills/grill-with-docs.zip`, `grilling.zip`, `domain-modeling.zip`, `codebase-design.zip`, `improve-codebase-architecture.zip`, `two-axis-review.zip`, `pr.zip`, `handoff.zip` | Adapted Matt Pocock skills, build 2026-10-15.1. |
| `skills/decompile-java-artifact.zip` | My skill: decompile a deployed Java JAR or WAR into a repo, map it, scan it for risks, explain it. |
| `skills/reverse-engineer-anything.zip` | The REA skill (from REA 6.5.0). It needs the REA server: see [INSTALL-REA.md](INSTALL-REA.md). |
| `skills-src/decompile-java-artifact/` | Source of the decompile skill. |
| `install-rea-mac.sh` | Installs the REA server on a Mac for Claude Desktop and Claude Code. |
| `tests/` | Test kit for the adapted skills, and the build script for the Java decompile test samples. |
| `docs/TASK2-REPORT.html` | Result of the Java decompile test on Spring PetClinic. |

## Set up a new Mac

1. Skills: in claude.ai, go to **Customize > Skills** and upload the zips from `skills/` that you need. You do this one time for each Claude account. The skills are then available on all devices of that account.
2. REA (only where you want it): follow [INSTALL-REA.md](INSTALL-REA.md).
3. Decompile skill: no install. When it runs, the skill copies itself into the connected folder. If there is no Java, see `skills-src/decompile-java-artifact/references/java-on-demand.md`.

To get the whole repo: `git clone https://github.com/Abhijit-17/claude-skills-plugins.git ~/Downloads/WORKSPACE/SkillsPlugins`

## Rules

- Use REA and the decompile skill only on software that you own or may examine.
- This repo is public. Do not commit company JAR or WAR files, their decompiled output, or secrets.
