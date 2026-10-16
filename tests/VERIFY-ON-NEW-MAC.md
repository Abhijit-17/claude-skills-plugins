# Verify everything on a new Mac without Claude Code CLI

Use this list on a Mac that has Claude Desktop but no Claude Code CLI (for example the MacBook Air M5). It covers the work of 2026-10-15 and 2026-10-16. Written in ASD-STE100.

Without the CLI, these do not work: `tests/run-skill-tests.sh` (it uses `claude -p`), `claude mcp list`, `claude mcp get rea`. This list gives a replacement for each one.

## 0. Get the repo

```bash
git clone https://github.com/Abhijit-17/claude-skills-plugins.git ~/Downloads/WORKSPACE/SkillsPlugins
cd ~/Downloads/WORKSPACE/SkillsPlugins
```

## 1. Skills (claude.ai account)

The skills are on your claude.ai account. You do not install them again on each Mac.

| # | Do this | Correct result |
|---|---|---|
| 1.1 | In Claude Desktop, new chat: *"List the skills that you have, with their names only."* | The list has: `grill-with-docs`, `grilling`, `domain-modeling`, `codebase-design`, `improve-codebase-architecture`, `two-axis-review`, `pr`, `handoff`, `decompile-java-artifact`, `reverse-engineer-anything`. |
| 1.2 | In Terminal: `for z in skills/*.zip; do printf '%-45s ' $z; unzip -p $z '*/SKILL.md' \| grep -o 'build: "[^"]*"' \| head -1; done` | The 8 Matt Pocock skills show `build: "2026-10-15.1"`. |

## 2. Matt Pocock skills (replaces `run-skill-tests.sh`)

1. Make the test repos (no Claude Code needed): `bash tests/setup-skill-test-fixtures.sh` (target: `~/skills-test`).
2. In Claude Desktop, connect the folder `~/skills-test` (**+**, then **Add folder**).
3. Follow `tests/mattpocock-skills-test-plan.md`. Send each prompt in a new chat, in the correct fixture folder. The prompts of the automated run, for reference:

| ID | Folder in `~/skills-test` | Prompt |
|---|---|---|
| R01 | `review-fixture` | `/anthropic-skills:two-axis-review main` |
| R02 | `review-fixture-shallow` | `/anthropic-skills:two-axis-review main use no sub-agents` |
| R03 | `review-fixture` | `Write a PR body for this branch.` |
| R04 | `review-fixture` | `/anthropic-skills:handoff next session fixes the review findings` |
| R05 | `grill-fixture` | `/anthropic-skills:grill-with-docs grill the plan in PLAN.md` |
| R06 | `legacy-glossary-fixture` | `/anthropic-skills:grill-with-docs grill the plan in PLAN.md` |
| R07 | `arch-fixture` | `What do you think of the architecture of this code? Answer in 5 lines.` (the architecture skill must NOT start) |
| R08 | `arch-fixture` | `I must stop now. What do I do next time? Answer in 3 lines.` (the handoff skill must NOT start) |
| R09 | `handoff-fixture` | `/anthropic-skills:handoff next session reviews the discount branch` |

Grade each answer with the expected result in the test plan.

## 3. REA server (Claude Desktop only)

1. Follow `INSTALL-REA.md`. The script finds that Claude Code is not installed and sets up Claude Desktop only.
2. Do checks 1, 2, 3 and 5 in `INSTALL-REA.md` ("Check the installation"). Skip check 4 (Claude Code).
3. At the end of the script output, the line for `claude_desktop_config.json` must show `OK`.

## 4. decompile-java-artifact skill

Follow `tests/TASK2-SAMPLES.md`:
1. `bash tests/build-task2-samples.sh` (needs a JDK 17+).
2. Decompile with Claude Desktop (connect the `SkillsPlugins` folder), or with the scripts in Terminal.
3. `python3 tests/verify-task2-decompile.py task2-samples task2-samples/skill-test-YYYYMMDD` must show `Result: ALL PASS`.
4. On this Mac, Terminal has internet. Also run the CVE check (step 5 in `TASK2-SAMPLES.md`). It did not run on the Intel Mac.

## 5. Report

For each section, note PASS or FAIL. For a FAIL, keep the full output or a screenshot, and give it to Claude in the "Skills Plugins and More" Project.
