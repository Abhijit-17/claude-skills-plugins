# Manual test plan: adapted Matt Pocock skills

| Item | Value |
|---|---|
| Build under test | 2026-10-14.3 (8 skills) |
| Upstream | mattpocock/skills, commit 49dd158 (2026-10-09) |
| Skills | grill-with-docs, grilling, domain-modeling, codebase-design, improve-codebase-architecture, two-axis-review, pr, handoff |
| Kit | `setup-skill-test-fixtures.sh`, `grill-with-docs-OLD-rollback.zip`, this file |
| Time | Minimum set: approximately 60 minutes. Full set: approximately 2 hours. |

## 1. Purpose

This plan tests the items that I could not test from the cloud sandbox. Each test gives the steps, the expected result, and the signs of a failure. Record each result in the table in Part F.

The plan tests these items:

1. The upload of the 8 skills to claude.ai.
2. The sync of the skills to each surface.
3. The load chain: grill-with-docs loads grilling and domain-modeling.
4. The agent-mode question with 3 choices.
5. File delivery on local surfaces and on cloud surfaces.
6. The shallow-clone rule.
7. The location of GLOSSARY.md and ADRs.
8. The handoff rules.
9. No unasked start of improve-codebase-architecture and handoff.
10. The name clash with the built-in `/code-review`.

## 2. Surfaces

| ID | Surface | How to open it |
|---|---|---|
| WEB | claude.ai chat in a web browser | claude.ai, then New chat |
| PRJ | Claude desktop app, a session in a Project | Desktop app, Projects, "Skills Plugins and More", new session |
| DCODE | Claude desktop app, Code tab, local session | Code tab, then select a folder on your Mac |
| CLI | Claude Code CLI in iTerm2 | `cd <folder>`, then `claude` |
| CLOUD | Optional: Code tab, cloud session on a GitHub repo | Code tab, then a cloud environment |

## 3. Safety

> **WARNING:** Use only the test repos from Part C. Do not test on work repos. Some tests write files and run `git fetch`.

> **CAUTION:** Sessions 1, 2, 6, 7 and 8 start reviews and sub-agents. They use your usage limit. Start them when your limit has space.

> **CAUTION:** Do not delete skill folders. This plan moves old folders to a backup folder.

**How to see that a skill loads:** Claude shows a tool line that names the skill, or a read of the skill's `SKILL.md`. Record the exact text that you see.

---

## Part A. Prepare (one time, approximately 10 minutes)

### A1. Check the Claude Code version

1. In iTerm2, type `claude --version`.
2. Make sure that the version is 2.1.273 or later.
3. If the version is earlier, type `claude update`.

Why: earlier versions do not sync claude.ai skills to the CLI.

### A2. Check the login method

1. Type `claude`, then type `/status`.
2. Make sure that you use your Claude account login, not an API key. An API key login does not sync skills.
3. Type `/exit`.

### A3. Move local copies of the 8 names to a backup folder

1. Type `ls ~/.claude/skills`.
2. Look for these names: `grill-with-docs`, `grilling`, `domain-modeling`, `codebase-design`, `improve-codebase-architecture`, `two-axis-review`, `code-review`, `pr`, `handoff`.
3. For each name that you find, move the folder. Example for one name:

   ```bash
   mkdir -p ~/skills-backup
   mv ~/.claude/skills/grill-with-docs ~/skills-backup/
   ```

4. Do not touch `~/.claude/skills/synced/`. The sync manages that folder.

Why: a local copy takes the short name. The new skill then shows only as `anthropic-skills:<name>`.

### A4. Disable the upstream Matt Pocock plugin, if it is installed

1. Type `claude plugin list`.
2. If the list shows `mattpocock-skills`, type `claude plugin disable <the id that the list shows>`.
3. In the desktop app, select **+** (next to the prompt box), then **Plugins**, then **Manage plugins**. If `mattpocock-skills` shows, disable it.

Why: the plugin adds a second copy of each skill.

### A5. Remove the old grill-with-docs from claude.ai

1. Open claude.ai, then **Settings**, then **Capabilities**.
2. Find `grill-with-docs`. The old description starts with "Relentless one-question-at-a-time interview".
3. Remove it. If it is part of a plugin, remove or disable that plugin.
4. Do not remove `teach-from-source`.
5. Keep `grill-with-docs-OLD-rollback.zip`. Use it only for a rollback (Part F.3).

### A6. Keep only the new ZIPs

1. Make a new folder, for example `~/Downloads/skills-build-2026-10-14.3/`.
2. Put the 8 ZIPs from build 2026-10-14.3 in that folder.
3. Delete all ZIPs from the earlier builds, including `code-review.zip` and `mattpocock-skills-adapted-ALL.zip`.

---

## Part B. Install (approximately 10 minutes)

### B1. Make sure that code execution is on

1. Open claude.ai, then **Settings**, then **Capabilities**.
2. Make sure that **Code execution and file creation** is on.

### B2 (test T00). Upload the 8 skills

1. In **Settings**, **Capabilities**, **Skills**, select **Upload skill**.
2. Upload the ZIPs in this order: `grilling`, `domain-modeling`, `codebase-design`, `grill-with-docs`, `improve-codebase-architecture`, `two-axis-review`, `pr`, `handoff`.
3. Turn on each skill after its upload.

Expected: claude.ai accepts each upload.

If an upload fails: stop. Copy the full error text. Send it to me with the ZIP name. (The ZIPs use the file name `SKILL.md`. The help page writes `Skill.md`. A failure here tells us which name the upload needs.)

### B3. Sync the skills to the CLI

1. In iTerm2, type `claude`. Wait 1 minute. Type `/exit`.
2. Type `claude` again. Type `/exit`.

Why: the CLI downloads account skills in the background when a session starts. The second session shows them.

---

## Part C. Make the test repos (approximately 2 minutes)

1. Put `setup-skill-test-fixtures.sh` in your Downloads folder.
2. Type `bash ~/Downloads/setup-skill-test-fixtures.sh`.
3. Make sure that the last lines show these values:
   - `review-fixture branch: feature/discount-codes`
   - `review-fixture-shallow shallow: true`
   - `arch-fixture commits: 8`
   - 4 ZIPs in `zips/`

The script writes only in `~/skills-test`. It does not change your git config, and it deletes nothing. If `~/skills-test` exists, the script stops.

| Folder | Used by |
|---|---|
| `review-fixture` | two-axis-review, pr, handoff |
| `review-fixture-shallow` | the shallow-clone rule |
| `arch-fixture` | improve-codebase-architecture |
| `grill-fixture` | grill-with-docs, with no glossary |
| `legacy-glossary-fixture` | grill-with-docs, with an old `CONTEXT.md` |
| `handoff-fixture` | handoff, in a folder with its own handoff file |
| `zips/` | the same repos as ZIPs (with `.git`), for WEB and PRJ |

---

## Part D. Test sessions

- **Minimum set:** Sessions 1, 3, 6 and 8.
- **Full set:** all sessions. Session 11 is optional.

Do the sessions in this order. Open a new session for each one.

### Session 1. CLI, review-fixture (T01, T02, T19, T07, T10, T17, T14)

Start: `cd ~/skills-test/review-fixture && claude`

**T01. Skill inventory**

1. Type `/skills`.
2. Expected: each of the 8 skills shows one time, in the **claude.ai sync** group.
3. Failure signs: a skill shows two times; the old grill-with-docs description shows; `code-review` from this set shows.

**T02. Synced files and build**

1. In a second iTerm2 tab, type:

   ```bash
   ls ~/.claude/skills/synced/
   ls ~/.claude/skills/synced/{grill-with-docs,grilling,domain-modeling,codebase-design,improve-codebase-architecture,two-axis-review,handoff}/RUNTIME.md | wc -l
   head -3 ~/.claude/skills/synced/grilling/RUNTIME.md
   ```

2. Expected: the list includes the 8 skill folders. (It can also include your other account skills.) The count is 7 (`pr` has no `RUNTIME.md`). Line 3 is `Build: 2026-10-14.3 (adapted from mattpocock/skills@49dd158)`.
3. Failure sign: the count is 0. Then the sync does not copy supporting files, and the skills cannot read their runtime rules.

**T19. Name clash with the built-in /code-review**

1. Type `/code-review`. Do not press Enter. Read the description in the menu. Then delete the text.
2. Type `/two-axis-review`. Do not press Enter. Read the description. Then delete the text.
3. Expected: `/code-review` shows the built-in bug review (it has effort levels). `/two-axis-review` shows "Two-axis review of the changes since a fixed point". Each one shows one time.

**T07. Agent mode: 3 choices, asked one time in each session**

1. Type `/two-axis-review main`.
2. Expected: before any sub-agent starts, Claude asks one question with 3 choices: **Parallel**, **One at a time**, **No sub-agents**.
3. Select **One at a time**.
4. Expected: Claude starts the Standards sub-agent. The Spec sub-agent starts only after the Standards sub-agent finishes. The CLI shows each sub-agent as an agent line.
5. When the review is done, type `/two-axis-review HEAD~1`. (This diff is small.)
6. Expected: Claude does not ask the agent-mode question again. It uses **One at a time**.

**T10. Review result**

1. Compare the first review with the answer key in Part E.1.
2. Expected:
   - The report has two sections, `## Standards` and `## Spec`. Claude does not merge them.
   - Standards finds 3 or more of S1 to S4.
   - Spec finds 3 or more of P1 to P4.
   - Claude finds the spec at `docs/specs/discount-codes.md` and does not ask you for it.
   - The last line gives the number of findings for each axis and the worst issue for each axis.

**T17. pr skill**

1. Type `Write a PR body for this branch.`
2. Expected: Claude loads the `pr` skill. It gives one markdown block with `## Summary`, `## Evidence` and `## Merge Danger` (Door and Blast Radius). It does not open a PR, and it does not push.
3. If Claude does not load the skill, record "no auto-load". Then type `/pr` and check the same items.

**T14. Handoff on a local machine**

1. Type `/handoff next session fixes the review findings`.
2. Expected:
   - Claude writes `handoff-<topic>-<timestamp>.md` in your temp folder (on macOS, a path under `/var/folders/`).
   - Claude gives you the absolute path.
   - The file has these sections: Read order, Do not redo, Verify, Suggested skills.
   - The file has no secrets.
3. In the second tab, type `git -C ~/skills-test/review-fixture status --short`.
4. Expected: no output. Claude wrote nothing in the repo.
5. Type `/exit`.

### Session 2. CLI, review-fixture-shallow (T07b, T11)

Start: `cd ~/skills-test/review-fixture-shallow && claude`

**T07b. Agent mode named in the request**

1. Type `/two-axis-review main use no sub-agents`.
2. Expected: Claude does not ask the agent-mode question. It uses **No sub-agents**.

**T11. Shallow-clone rule**

1. Use the same run as T07b.
2. Expected, in this order:
   - Claude runs `git rev-parse --is-shallow-repository`. The result is `true`. Then Claude runs `git fetch --unshallow`.
   - Claude finds that `main` is missing. It runs `git fetch origin main:refs/remotes/origin/main`.
   - Claude reviews `origin/main...HEAD`: 2 commits, and the files `src/discount.js` and `src/shipping.js`.
   - No sub-agent starts. The Standards report is complete before the Spec review starts.
3. Failure signs: Claude reviews only 1 commit, says "no diff", or stops with an "unknown revision" error.
4. Type `/exit`.

### Session 3. CLI, grill-fixture (T03, T04)

Start: `cd ~/skills-test/grill-fixture && claude`

**T03. Load chain**

1. Type `/grill-with-docs grill the plan in PLAN.md`.
2. Expected:
   - Claude loads grill-with-docs, then grilling, then domain-modeling.
   - There is no "Install the X skill" message.
   - The first reply is one round of numbered questions (Q1, Q2, and so on). Each question has a recommended answer (➡️).
   - Claude does not ask the agent-mode question at the start.
3. Failure signs: only one question (the old behaviour), the text "CONTEXT.md", or a "skill not found" error.

**T04. Docs in a repo**

1. Answer the first round. You can type `yes` to accept the recommendations.
2. Expected: when the first term is settled, Claude writes `GLOSSARY.md` at the repo root. The file has terms only, and no implementation details.
3. Expected: `docs/adr/` does not exist, unless you accepted an ADR.
4. In the second tab, type `ls ~/skills-test/grill-fixture` to check.
5. Type `/exit`.

### Session 4. CLI, legacy-glossary-fixture (T06)

Start: `cd ~/skills-test/legacy-glossary-fixture && claude`

**T06. Old CONTEXT.md glossary**

1. Type `/grill-with-docs grill the plan in PLAN.md`.
2. Expected:
   - Claude reads `CONTEXT.md` as the glossary.
   - Claude challenges "list" (the glossary term is **Shelf**) and "links" (the glossary term is **Article**).
   - Claude offers one time to rename `CONTEXT.md` to `GLOSSARY.md`.
3. Type `/exit`.

### Session 5. CLI, handoff-fixture (T15)

Start: `cd ~/skills-test/handoff-fixture && claude`

**T15. Handoff in a folder with its own handoff file**

1. Type `Read MISSION.md and tell me the mission in one line.`
2. Type `/handoff next session reviews the discount branch`.
3. Expected: Claude finds `COURSE-HANDOFF.md`. It asks which one you want: that file's format and place, or a temporary handoff document. It does not write both.
4. Type `/exit`.

### Session 6. CLI, arch-fixture (T18, T12)

Do T18 before T12, at the start of a new session.

Start: `cd ~/skills-test/arch-fixture && claude`

**T18. No unasked start**

1. Type `What do you think of the architecture of this code? Answer in 5 lines.`
2. Expected: Claude answers in the chat. It does not load improve-codebase-architecture. It writes no HTML report.
3. Type `I must stop now. What do I do next time? Answer in 3 lines.`
4. Expected: Claude answers in the chat. It does not load handoff. It writes no handoff file.
5. Type `/clear`.

**T12. Architecture report on a local machine**

1. Type `/improve-codebase-architecture`.
2. Expected: Claude asks the agent-mode question. Select **Parallel**.
3. Expected:
   - Claude reads `GLOSSARY.md` and `docs/adr/0001-pricing-stays-remote.md`.
   - Claude uses `git log` to find the hot spot: `src/order/` and `src/utils/`. It does not focus on `src/users/`.
   - Claude writes `architecture-review-<timestamp>.html` in your temp folder. It opens the file in your browser and gives you the absolute path.
   - The page is dark. It has no light-mode toggle.
   - Claude asks: "Which of these would you like to explore?"
4. Check the report with the answer key in Part E.2.
5. In the second tab, type `git -C ~/skills-test/arch-fixture status --short`. Expected: no output.
6. Optional: select a candidate. Expected: one round of numbered questions. Claude adds a term to `GLOSSARY.md` only when a new name is settled.
7. Type `/exit`.

### Session 7. CLI, non-interactive run (T09)

**T09. Agent mode when no one can answer**

1. Type:

   ```bash
   cd ~/skills-test/review-fixture
   claude -p "/two-axis-review main" --allowedTools "Bash(git:*)" "Read" "Grep" "Glob"
   ```

2. Expected: Claude does not stop to ask a question. The first line of the output says that it uses **No sub-agents**, and that you can name a mode in the request next time. The output has `## Standards` and `## Spec`.
3. Failure sign: the run ends with a question and no review.

### Session 8. WEB, claude.ai chat (T01, T03, T05, T08, T10, T13, T18)

Open claude.ai. Start a new chat for each test.

**T18. No unasked start** (do this first)

1. Type `I must stop now. What do I do next time? Answer in 3 lines.`
2. Expected: Claude does not load handoff. It makes no file.

**T01. Skill inventory**

1. Type: `List your skills named grill-with-docs, grilling, domain-modeling, codebase-design, improve-codebase-architecture, two-axis-review, pr and handoff. For each one, give the exact name that you see and the first 8 words of its description. Do not load them.`
2. Expected: 8 names, each one time. The grill-with-docs description starts with "A relentless interview to sharpen a plan or design".

**T03 and T05. Load chain, and docs with no repo**

1. Type: `Use grill-with-docs to grill this plan: Users can save an article to read later. Saved articles show in a list. Users can mark an article as read. Later, we may share lists with friends.`
2. Expected:
   - Claude loads the 3 skills. There is no "Install the X skill" message.
   - Claude tells you one time that the docs stay in the conversation until you save them.
   - The first reply is one round of numbered questions with recommendations.
3. Answer the round. You can type `yes` to accept the recommendations.
4. Expected: when a round settles one or more terms, Claude sends `GLOSSARY.md` as a file after that round. It sends the file one time for each round, not one time for each term.

**T08 and T10. Agent mode with no sub-agent tool, and the review result**

1. Attach `~/skills-test/zips/review-fixture.zip`.
2. Type `Unzip this repo. Then run two-axis-review against main.`
3. Expected: if this surface has no sub-agent tool, Claude does not ask the agent-mode question. It says in one line that it uses **No sub-agents**.
4. If Claude asks the question, record "this surface has a sub-agent tool". Then select **No sub-agents**.
5. Expected: the result passes the T10 checks (Part E.1).

**T13. Architecture report on a cloud surface**

1. Attach `~/skills-test/zips/arch-fixture.zip`.
2. Type `Unzip this repo. Then run improve-codebase-architecture on it.`
3. Expected: Claude sends the HTML report as a file. It does not publish an artifact or a web page. It can offer one time to publish it. Do not accept.
4. Download the file and open it. Expected: a dark page that passes Part E.2.

### Session 9. PRJ, desktop Project session (T01, T03, T05, T16)

Open the desktop app, then **Projects**, then **Skills Plugins and More**. Start a new session.

1. Do T01 with the same prompt as in Session 8.
2. Do T03 and T05 with the same prompt as in Session 8.
   - Extra expected result: grill-with-docs loads the other 2 skills with no error. (In this surface, the skill names can have the prefix `anthropic-skills:`.)
   - Extra expected result: Claude offers to save `GLOSSARY.md` to the Project.

**T16. Handoff on a cloud surface**

1. Type `Use the handoff skill. The next session continues this grilling.`
2. Expected: Claude sends the handoff as a file. It offers to save it to the Project. The file has the 4 sections from T14.

### Session 10. DCODE, desktop Code tab, local session (T01, T19, T03)

1. Open the Code tab. Select the folder `~/skills-test/grill-fixture`.
2. Type `/` and look for the 8 skills in the menu. Expected: each one shows one time.
3. Do T19 (the same steps as in Session 1).
4. Do T03: type `/grill-with-docs grill the plan in PLAN.md`. Expected: the same results as in Session 3. If `GLOSSARY.md` exists from Session 3, Claude reads it and does not make a new one. This is also a pass.

### Session 11 (optional). CLOUD, Code tab cloud session (T11)

Do this session only if you use cloud sessions.

1. Push the review repo to a new private GitHub repo:

   ```bash
   cd ~/skills-test/review-fixture
   gh repo create skills-test-review --private --source . --remote origin --push
   git push origin main
   ```

2. In the Code tab, start a cloud session on `skills-test-review`, branch `feature/discount-codes`.
3. Type `/two-axis-review main`.
4. Expected: Claude checks for a shallow clone, and fetches `main` if it is missing. The review shows 2 commits.
5. After the test, delete the GitHub repo if you do not need it.

---

## Part E. Answer keys

### E.1 review-fixture (two-axis-review)

**Standards** (rules from `CONTRIBUTING.md`):

| ID | Seeded defect | File |
|---|---|---|
| S1 | `var` is used (rule 1). | `src/discount.js` |
| S2 | Exported functions have no JSDoc (rule 2): `applyCode`, `discountedTotal`, `shippingCents`. | `src/discount.js`, `src/shipping.js` |
| S3 | `console.log` in `src/` (rule 3). | `src/discount.js` |
| S4 | Floating-point money: `total * (pct / 100)` can give part cents (rule 4). | `src/discount.js` |

Optional judgement calls: Primitive Obsession (codes and dates are plain strings). The `cart` parameter of `shippingCents` is not used.

**Spec** (`docs/specs/discount-codes.md`):

| ID | Seeded defect |
|---|---|
| P1 | R2 is wrong. `today >= entry.expires` rejects the code on its expiry date. The spec says that the code is valid on that date. |
| P2 | R3 is missing. A second code replaces the first code. There is no `ONE_CODE_ONLY` error. |
| P3 | R4 is missing. There is no receipt line. |
| P4 | Scope creep: free shipping in `src/shipping.js`. The spec says that shipping rules are out of scope. |

Pass: 3 or more of S1 to S4, and 3 or more of P1 to P4, in two separate reports.

### E.2 arch-fixture (improve-codebase-architecture)

Good signs:

1. The hot spot is `src/order/` and `src/utils/priceUtils.js`. `src/users/` is not a candidate.
2. A candidate makes Order intake one deep module behind one small interface. For example, it folds `OrderValidator`, `OrderMapper` and `priceUtils` behind `handleOrder` or `placeOrder`. Tests then call that interface.
3. A candidate removes `orderService.js` or folds it in. It is a pass-through (Middle Man).
4. `PricingClient` is an adapter at a seam: remote in production, in-memory in tests.
5. The text uses the glossary words Order, Line Item and Quote.
6. The text uses module, interface, seam, adapter, depth, leverage and locality. It does not use "component", "service" or "boundary" as a general word for a module. (File names such as `orderService.js` are correct.)
7. No candidate computes prices locally, because that contradicts ADR-0001. If a candidate does, its card must show a warning that names ADR-0001.

Pass: signs 1, 5, 6 and 7, and 2 or more of signs 2, 3 and 4.

---

## Part F. Results, failures and rollback

### F.1 Results

Write **P** (pass), **F** (fail) or **-** (not run) in each cell. A blank cell means that the test does not apply to that surface.

| Test | Item | WEB | PRJ | DCODE | CLI | CLOUD |
|---|---|---|---|---|---|---|
| T00 | Upload accepted (B2) | | | | | |
| T01 | Skill inventory | | | | | |
| T02 | Synced files and build | | | | | |
| T03 | Load chain | | | | | |
| T04 | Docs in a repo | | | | | |
| T05 | Docs with no repo | | | | | |
| T06 | Old CONTEXT.md glossary | | | | | |
| T07 | Agent mode: 3 choices, one time | | | | | |
| T07b | Agent mode named in the request | | | | | |
| T08 | Agent mode: no sub-agent tool | | | | | |
| T09 | Agent mode: non-interactive | | | | | |
| T10 | two-axis-review result | | | | | |
| T11 | Shallow-clone rule | | | | | |
| T12 | Architecture report, local | | | | | |
| T13 | Architecture report, cloud | | | | | |
| T14 | Handoff, local | | | | | |
| T15 | Handoff with its own format | | | | | |
| T16 | Handoff, cloud and Project | | | | | |
| T17 | pr skill | | | | | |
| T18 | No unasked start | | | | | |
| T19 | Name clash with /code-review | | | | | |

### F.2 If a test fails

1. Stop that session.
2. Record the test ID, the surface, the text that Claude showed, and a screenshot if you can.
3. Send these to me in this Project. I will fix the skill and make a new build.

### F.3 Rollback

Do these steps only if the new skills block your work.

1. In claude.ai **Settings**, **Capabilities**, turn off or remove the 8 skills.
2. Upload `grill-with-docs-OLD-rollback.zip`. This is your old grill-with-docs.
3. If you moved a local copy in A3, move it back. Example: `mv ~/skills-backup/grill-with-docs ~/.claude/skills/`

### F.4 Watch during normal use

These items have no test, because a test cannot cause them on purpose:

1. If a usage limit stops a sub-agent, Claude must check the real output before it uses it. It must tell you what is missing.
2. In a chat, Claude must not send the glossary file after each term.
