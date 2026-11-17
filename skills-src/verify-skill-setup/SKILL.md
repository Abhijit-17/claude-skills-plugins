---
name: verify-skill-setup
description: Makes a `verify` skill for one repo, so that Claude can start the app, use it end to end and check the result before each commit, with a stop rule after three failed fix rounds and an optional diff-triggered reliability checklist. Use when the user asks for verify setup, a verify skill or a verification loop for a repo, or starts agent work on a repo that has no fast end-to-end check.
license: MIT
metadata:
  build: "2026-11-17.1"
  source: "Addy Osmani, How the Claude Code team thinks about verification (claude.dev, 2026-11); approved as content-triage Proposal S-20261117-1"
---

# Verify skill setup

This skill makes one or more `verify` skills inside a repo. A `verify` skill is the smoke test that Claude runs before each commit: it starts the app, drives it like a user, checks the result, and reports. Written in ASD-STE100.

## Rules

1. **Ask before you write in the repo.** Show the plan (step 3) first. Write files only after the user says yes.
2. **No secrets in files.** A verify skill reads credentials from environment variables. Write `<REDACTED>` in each output that you show.
3. **Read-only on shared systems.** The verify skill runs the app on the local machine or in a test environment. It never writes to production data.
4. **Do not weaken checks.** Never skip, retry or add sleeps to a flaky check to make it pass. Find the cause. If you cannot find it, remove the check and record why.

## Step 1. Learn how the app runs

1. Read `README*`, `CLAUDE.md`, `GLOSSARY.md`, the build files (`package.json`, `pom.xml`, `build.gradle`, `Makefile`, `pyproject.toml`, `Cargo.toml`), `docker-compose*`, `.env.example` and the CI workflow files.
2. Find out: the kind of app (backend service, web app, mobile app, desktop app, CLI, library), the command that starts it, the port or the device, the signal that it is ready (a health URL, a log line), and its dependencies (database, queue, other services).
3. Find the tests that exist: unit, integration, end-to-end. Note how long each suite takes.
4. In a monorepo, do steps 1 to 3 for each app that a change can touch. Each app gets its own verify skill.

## Step 2. Choose how to drive the app

| Kind of app | Drive it with |
|---|---|
| Backend service | Start it locally; call its API with `curl` or a short script; check the status, the body and the logs. |
| Web app | A browser tool of this session (Claude in Chrome, the built-in browser) or a headless script (Playwright). Check the page, the console and the network. |
| Mobile app | The iOS simulator or the Android emulator, with a simulator MCP if the session has one. |
| Desktop app | Computer use, if the session has it. |
| CLI or library | Run it with fixture inputs and compare the output with a known-good snapshot. |

If more than one way fits, ask the user one question with the choices.

## Step 3. Show the plan

Tell the user, in a few lines:
- where each verify skill goes (`.claude/skills/verify/` at the repo root, or `<app>/.claude/skills/verify/` near the code in a monorepo);
- the cheap checks, the start command, the user flows to drive (2 to 5 of the most important ones), and the checks for each flow;
- the expected run time;
- which optional parts you propose (steps 6 and 7).

Wait for the yes.

## Step 4. Write the verify skill

Write `.claude/skills/verify/SKILL.md` with this shape (fill in the real commands):

```md
---
name: verify
description: Smoke test for <app>. Use before each commit, and when the user asks to verify a change.
---

# Verify <app>

1. Cheap checks first: <build>, <lint>, <unit tests>. Stop at the first failure and report it.
2. Start: <start command>. Wait until <ready signal> (maximum <N> seconds).
3. Drive these flows and check each one:
   - <flow 1>: <steps>. Expected: <result>.
   - <flow 2>: ...
4. Stop the app: <stop command>. Remove temporary data.
5. Report: one line for each check (pass or fail), the failing output (redacted), and the total time.

Stop rule: if a check still fails after 3 fix rounds, stop and ask a person. Do not change a check to make it pass.
```

Put long helper scripts in `.claude/skills/verify/scripts/`. Keep each script runnable by itself.

## Step 5. Make it fast and stable

1. Run the verify skill 3 times on the unchanged code. All 3 runs must pass with the same result.
2. If a run fails or the result changes, fix the cause (a fixed port, a wait for the ready signal, a fixed seed, a clean test database). Run 3 times again.
3. Make it fast: reuse a started dependency, narrow each flow to its key step, run the cheap checks first. Record the run time in the skill.
4. Make one change that breaks a flow on purpose, and check that the verify skill fails on it. Then undo the change.

## Step 6. Optional: the reliability checklist

Use it for a repo with past incidents. Write `.claude/verify/CHECKLIST.md`. Each item has three parts:

```md
- Trigger: <what Claude can see in a diff, for example "a new field in the session record">
  Check: <what to test, for example "an old session without the field still loads">
  Source: <incident or PR link>
```

Add to the verify skill: "Read the diff. Run only the checklist items whose trigger matches the diff (usually 3 to 10)."

**Protect the checks:** a change must not edit the checks that judge it. Tell the verify skill to read the checklist from the base branch (`git show origin/<base>:.claude/verify/CHECKLIST.md`), and to stop if the diff changes the checklist or the verify skill. A person reviews changes to the checks in a separate PR.

Add an item only for a mistake that showed in 2 or more PRs and that a diff can show.

## Step 7. Optional: use it every time

After the user's yes:
- Add one line to `CLAUDE.md`: "Run the verify skill before each commit. Write `Verified: <how>` (or `Verified: none`) in the commit message."
- If the user wants it enforced, propose a hook that blocks a commit when the session has no verify run. Start the hook in a mode that only logs.

## Step 8. Suggest the next tests

Tell the user which tests would make the verify skill stronger:
- **End-to-end tests** first: they check real user flows and are hard to fool.
- **Property tests** for rules that must always hold: a round trip of an encoding, a balance that is never negative, an idempotent operation, an optimized function that must equal a simple one. Tools: fast-check, Hypothesis, jqwik (Java), proptest.
- **Differential tests** for a migration: run the old and the new code on the same inputs and report each difference, with a list of approved differences.

## Done

Report: the files written, the 3 test runs and their times, the result of the break test (step 5.4), and the optional parts that you did not do. Suggest that the user commits the files.
