# claude-skills-plugins

The Claude skills and tools that I use on Claude desktop, Claude cloud sessions, Projects and Claude Code. Written in ASD-STE100.

## Contents

| Path | What it is |
|---|---|
| `skills/` | Skill zips. Upload in claude.ai: **Customize > Skills**. |
| `skills/grill-with-docs.zip`, `grilling.zip`, `domain-modeling.zip`, `codebase-design.zip`, `improve-codebase-architecture.zip`, `two-axis-review.zip`, `pr.zip`, `handoff.zip` | Adapted Matt Pocock skills, build 2026-10-30.1. |
| `skills/tdd.zip`, `diagnosing-bugs.zip`, `to-spec.zip`, `to-tickets.zip`, `implement.zip` | Adapted Matt Pocock skills (build 2026-11-13.2; diagnosing-bugs 2026-11-17.1 adds a fact-and-hypothesis method): test-first work, a diagnosis loop for bugs, and the flow from a discussion to a spec, to tickets, to code. The tracker is local Markdown in `.scratch/` by default. They use the 8 skills in the row above. |
| `skills/decompile-java-artifact.zip` | My skill: decompile a deployed Java JAR or WAR into a repo, map it, scan it for risks, explain it. |
| `skills/reverse-engineer-anything.zip` | The REA skill (from REA 6.8.0). It needs the REA server: see [INSTALL-REA.md](INSTALL-REA.md). |
| `skills/content-triage.zip` | My skill: watch a short list of YouTube and X sources, and sort each new item into Learn, Skill, Mindset, Jobhunt or Skip against my goals. Needs the Claude desktop app's built-in browser. |
| `skills/verify-skill-setup.zip` | My skill: make a `verify` skill for a repo, so Claude starts the app, drives it end to end and checks the result before each commit (stop after 3 failed fix rounds; optional diff-triggered checklist). |
| `skills-src/decompile-java-artifact/` | Source of the decompile skill. |
| `skills-src/content-triage/`, `content-triage/` | Source of the content-triage skill, and its design glossary and ADRs. |
| `install-rea-mac.sh` | Installs the REA server on a Mac for Claude Desktop and Claude Code. |
| `tests/` | Test kit for the adapted skills (`run-skill-tests.sh`; `--local` tests copies in `~/.claude/skills/` before an upload; `compare-skill-runs.py` compares 2 runs), and the build script for the Java decompile test samples. |
| `tests/TASK2-SAMPLES.md` | Where the Java test samples (JAR and WAR) come from, and how to run and verify the decompile test on a different Mac. |
| `tests/VERIFY-ON-NEW-MAC.md` | Checklist to verify the skills, REA and the decompile skill on a Mac without Claude Code CLI. |
| `tests/verify-task2-decompile.py` | Compares the decompile output with the original source. Shows PASS or FAIL for each check. |
| `docs/TASK2-REPORT.html` | Result of the Java decompile test on Spring PetClinic. |

## Set up a new Mac

1. Skills: in claude.ai, go to **Customize > Skills** and upload the zips from `skills/` that you need. You do this one time for each Claude account. The skills are then available on all devices of that account.
2. REA (only where you want it): follow [INSTALL-REA.md](INSTALL-REA.md).
3. Decompile skill: no install. When it runs, the skill copies itself into the connected folder. If there is no Java, see `skills-src/decompile-java-artifact/references/java-on-demand.md`.

To get the whole repo: `git clone https://github.com/Abhijit-17/claude-skills-plugins.git ~/Downloads/WORKSPACE/SkillsPlugins`

## Rules

- Use REA and the decompile skill only on software that you own or may examine.
- This repo is public. Do not commit company JAR or WAR files, their decompiled output, or secrets.
