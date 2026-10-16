#!/usr/bin/env bash
# run-skill-tests.sh
# Build 2026-10-15.1 (for skills build 2026-10-14.3)
#
# Runs the automatable tests of the adapted Matt Pocock skills with
# `claude -p` (headless mode), and grades the output.
#
# What it does:
#   1. Makes a FRESH set of fixtures in the run folder (it calls
#      setup-skill-test-fixtures.sh). Your ~/skills-test is not touched.
#   2. Runs 11 headless Claude sessions on those fixtures.
#   3. Grades each output against the answer keys, and writes
#      results.md and a ZIP of the full run.
#
# Safety:
#   - Claude can only use these tools: Skill, Read, Grep, Glob, Write, Edit,
#     and Bash for git and a few read-only commands. It cannot push,
#     use gh, open a browser, delete files, or use the web.
#   - Writes go to the run folder and to your temp folder only.
#
# Usage:
#   bash run-skill-tests.sh                 # all tests (approx. 20-40 min)
#   bash run-skill-tests.sh --skip-arch     # skip the long architecture run
#   MODEL=sonnet bash run-skill-tests.sh    # use a different model
#
# Works with the macOS default bash (3.2).

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd -P)"
SKIP_ARCH=0
for a in "$@"; do
  case "$a" in
    --skip-arch) SKIP_ARCH=1 ;;
    -h|--help) sed -n '2,25p' "$0"; exit 0 ;;
    *) echo "Unknown option: $a" >&2; exit 1 ;;
  esac
done

TIMEOUT_SECS="${TIMEOUT_SECS:-900}"
STAMP="$(date +%Y%m%d-%H%M%S)"
RESULTS_ROOT="${RESULTS_ROOT:-$HOME/skills-test-results}"
RUN="$RESULTS_ROOT/run-$STAMP"
FX="$RUN/fx"
RAW="$RUN/raw"
TMPD="${TMPDIR:-/tmp}"
TMPD="${TMPD%/}"

say() { printf '%s\n' "$*"; }
stop() { printf 'STOP: %s\n' "$*" >&2; exit 1; }

###########################################################################
# Preflight
###########################################################################
command -v claude  >/dev/null 2>&1 || stop "claude is not on PATH."
command -v git     >/dev/null 2>&1 || stop "git is not installed."
command -v zip     >/dev/null 2>&1 || stop "zip is not installed."
command -v perl    >/dev/null 2>&1 || stop "perl is not installed."
python3 -c 'import json' >/dev/null 2>&1 || stop "python3 does not work. Run: xcode-select --install"

FIXTURE_SCRIPT=""
for f in "$HERE/setup-skill-test-fixtures.sh" \
         "$HOME/Downloads/WORKSPACE/SkillsPlugins/tests/setup-skill-test-fixtures.sh" \
         "$HOME/Downloads/setup-skill-test-fixtures.sh"; do
  if [ -f "$f" ]; then FIXTURE_SCRIPT="$f"; break; fi
done
[ -n "$FIXTURE_SCRIPT" ] || stop "setup-skill-test-fixtures.sh not found. Put it next to this script."

case "$RUN" in *" "*) stop "The results path has a space: $RUN" ;; esac

mkdir -p "$RAW"
say "Run folder: $RUN"
say "Claude:     $(claude --version 2>/dev/null | head -1)"
say ""
say "Making fresh fixtures..."
bash "$FIXTURE_SCRIPT" "$FX" > "$RUN/fixtures.log" 2>&1 || stop "fixture script failed. See $RUN/fixtures.log"

###########################################################################
# Claude flags (one place)
###########################################################################
ALLOWED="Skill,Read,Grep,Glob,Write,Edit,Bash(git:*),Bash(ls:*),Bash(mktemp:*),Bash(date:*),Bash(pwd),Bash(cat:*),Bash(head:*),Bash(tail:*),Bash(wc:*),Bash(find:*),Bash(echo:*),Bash(printf:*),Bash(test:*),Bash(uname:*),Bash(mkdir:*),Bash(sed -n:*)"
DENIED="Bash(git push:*),Bash(gh:*),Bash(open:*),Bash(curl:*),Bash(rm:*),Bash(mv:*),WebFetch,WebSearch"

# run_claude <id> <dir> <prompt> [resume-session-id]
run_claude() {
  id="$1"; dir="$2"; prompt="$3"; resume="${4:-}"
  out="$RAW/$id"
  mkdir -p "$out"
  ls -1 "$TMPD" 2>/dev/null | grep -E '^(handoff-|architecture-review-)' | sort > "$out/tmp-before.txt"
  printf '%s\n' "$prompt" > "$out/prompt.txt"
  say "[$id] $(date +%H:%M:%S) start: $prompt"

  set -- -p "$prompt" --output-format stream-json --verbose \
         --permission-mode acceptEdits --add-dir "$TMPD" \
         --allowedTools "$ALLOWED" --disallowedTools "$DENIED"
  if [ -n "${MODEL:-}" ]; then set -- "$@" --model "$MODEL"; fi
  if [ -n "$resume" ]; then set -- "$@" --resume "$resume"; fi

  ( cd "$dir" && perl -e 'alarm shift; exec @ARGV' "$TIMEOUT_SECS" claude "$@" \
      > "$out/stream.jsonl" 2> "$out/stderr.txt" < /dev/null )
  echo "$?" > "$out/exit.txt"

  ls -1 "$TMPD" 2>/dev/null | grep -E '^(handoff-|architecture-review-)' | sort > "$out/tmp-after.txt"
  comm -13 "$out/tmp-before.txt" "$out/tmp-after.txt" > "$out/tmp-new.txt"
  # Keep a copy of each new temp file, for review.
  while IFS= read -r f; do
    [ -n "$f" ] && cp "$TMPD/$f" "$out/" 2>/dev/null
  done < "$out/tmp-new.txt"
  if git -C "$dir" rev-parse --git-dir >/dev/null 2>&1; then
    git -C "$dir" status --short > "$out/git-status.txt" 2>&1
    git -C "$dir" rev-parse --is-shallow-repository > "$out/git-shallow.txt" 2>&1
  fi
  ( cd "$dir" && ls -R ) > "$out/dir-after.txt" 2>&1
  say "[$id] $(date +%H:%M:%S) done (exit $(cat "$out/exit.txt"))"
}

session_id() {
  python3 - "$RAW/$1/stream.jsonl" <<'PY'
import json, sys
for line in open(sys.argv[1], errors="replace"):
    try:
        d = json.loads(line)
    except Exception:
        continue
    if d.get("session_id"):
        print(d["session_id"]); break
PY
}

###########################################################################
# Runs
###########################################################################
R="$FX/review-fixture"
run_claude R01-review   "$R" "/anthropic-skills:two-axis-review main"
run_claude R02-shallow  "$FX/review-fixture-shallow" "/anthropic-skills:two-axis-review main use no sub-agents"
run_claude R03-pr       "$R" "Write a PR body for this branch."
run_claude R04-handoff  "$R" "/anthropic-skills:handoff next session fixes the review findings"

run_claude R05-grill    "$FX/grill-fixture" "/anthropic-skills:grill-with-docs grill the plan in PLAN.md"
SID="$(session_id R05-grill)"
if [ -n "$SID" ]; then
  run_claude R05b-grill-yes "$FX/grill-fixture" "Yes. I accept all your recommended answers for this round." "$SID"
else
  mkdir -p "$RAW/R05b-grill-yes"; echo "no session id from R05" > "$RAW/R05b-grill-yes/stderr.txt"
fi

run_claude R06-legacy   "$FX/legacy-glossary-fixture" "/anthropic-skills:grill-with-docs grill the plan in PLAN.md"
run_claude R07-noarch   "$FX/arch-fixture" "What do you think of the architecture of this code? Answer in 5 lines."
run_claude R08-nohandoff "$FX/arch-fixture" "I must stop now. What do I do next time? Answer in 3 lines."
run_claude R09-handoff-own "$FX/handoff-fixture" "/anthropic-skills:handoff next session reviews the discount branch"
if [ "$SKIP_ARCH" -eq 0 ]; then
  run_claude R10-arch   "$FX/arch-fixture" "/anthropic-skills:improve-codebase-architecture"
fi

###########################################################################
# Grade
###########################################################################
cat > "$RUN/grade.py" <<'PY'
import json, os, re, sys, glob

RUN = sys.argv[1]
RAW = os.path.join(RUN, "raw")
TMPD = sys.argv[2].rstrip("/")
NAMES8 = ["grill-with-docs", "grilling", "domain-modeling", "codebase-design",
          "improve-codebase-architecture", "two-axis-review", "pr", "handoff"]

def rd(p):
    try:
        return open(p, errors="replace").read()
    except Exception:
        return ""

class Run:
    def __init__(self, rid):
        self.id = rid
        self.dir = os.path.join(RAW, rid)
        self.exists = os.path.isdir(self.dir)
        self.init = {}
        self.final = ""
        self.texts = []          # assistant text blocks
        self.user_texts = []     # injected text (slash-command skill bodies)
        self.tools = []          # (name, input)
        self.denied = []
        self.is_error = None
        self.cost = None
        for line in rd(os.path.join(self.dir, "stream.jsonl")).splitlines():
            try:
                d = json.loads(line)
            except Exception:
                continue
            t = d.get("type")
            if t == "system" and d.get("subtype") == "init":
                self.init = d
            elif t == "assistant":
                for c in (d.get("message") or {}).get("content") or []:
                    if c.get("type") == "text":
                        self.texts.append(c.get("text", ""))
                    elif c.get("type") == "tool_use":
                        self.tools.append((c.get("name", ""), c.get("input") or {}))
            elif t == "user":
                content = (d.get("message") or {}).get("content")
                if isinstance(content, str):
                    self.user_texts.append(content)
                for c in content if isinstance(content, list) else []:
                    if c.get("type") == "text":
                        self.user_texts.append(c.get("text", ""))
                    if c.get("type") == "tool_result" and c.get("is_error"):
                        body = c.get("content")
                        if isinstance(body, list):
                            body = " ".join(x.get("text", "") for x in body if isinstance(x, dict))
                        body = str(body)
                        if re.search(r"permission|not allowed|denied", body, re.I):
                            self.denied.append(body[:160])
            elif t == "result":
                self.final = d.get("result") or ""
                self.is_error = d.get("is_error")
                self.cost = d.get("total_cost_usd")
        self.all = "\n".join(self.texts + [self.final])
        self.stderr = rd(os.path.join(self.dir, "stderr.txt"))
        self.exit = rd(os.path.join(self.dir, "exit.txt")).strip()
        self.git_status = rd(os.path.join(self.dir, "git-status.txt")).strip()
        self.shallow = rd(os.path.join(self.dir, "git-shallow.txt")).strip()
        self.tmp_new = [x for x in rd(os.path.join(self.dir, "tmp-new.txt")).splitlines() if x.strip()]

    def tool_names(self):
        return [n for n, _ in self.tools]

    def bash(self):
        return [str(i.get("command", "")) for n, i in self.tools if n == "Bash"]

    def writes(self):
        return [str(i.get("file_path", "")) for n, i in self.tools if n in ("Write", "Edit")]

    def agents(self):
        return [n for n in self.tool_names() if n in ("Task", "Agent")]

    def asked(self):
        return [n for n in self.tool_names() if n == "AskUserQuestion"]

    def loaded(self, name):
        """True if skill `name` loaded: Skill tool call, SKILL.md read, or injected body."""
        for n, i in self.tools:
            if n == "Skill":
                s = str(i.get("skill") or i.get("command") or i.get("name") or "")
                if s == name or s.endswith(":" + name):
                    return True
            if n == "Read" and re.search(r"/%s/(SKILL|RUNTIME)\.md$" % re.escape(name), str(i.get("file_path", ""))):
                return True
        for u in self.user_texts:
            if re.search(r"(skills?[/:](\S*/)?|anthropic-skills:)%s\b" % re.escape(name), u):
                return True
        return False

    def ok(self):
        return self.exists and self.final.strip() != ""

RESULTS = []   # (test, surface, result, evidence)

def add(test, result, evidence, surface="CLI headless"):
    RESULTS.append((test, surface, result, evidence))

def need(run, test):
    if not run.exists:
        add(test, "-", "not run")
        return False
    if not run.ok():
        why = "no final output"
        if run.exit and run.exit != "0":
            why += ", exit %s" % run.exit
            if run.exit in ("142", "14"):
                why += " (timeout)"
        if run.stderr.strip():
            why += "; stderr: " + run.stderr.strip().splitlines()[-1][:160]
        add(test, "ERROR", why)
        return False
    return True

def has(pattern, text, flags=re.I | re.M):
    return re.search(pattern, text, flags) is not None

# ---------------------------------------------------------------- T01 (headless view)
r1 = Run("R01-review")
if r1.exists and r1.init:
    pool = []
    for key in ("skills", "slash_commands"):
        v = r1.init.get(key) or []
        for x in v:
            pool.append(x if isinstance(x, str) else str(x.get("name", x)))
    pool = sorted(set(pool))
    counts = {n: sum(1 for p in pool if p == n or p.endswith(":" + n)) for n in NAMES8}
    shown = ", ".join("%s=%d" % (n, c) for n, c in counts.items())
    if not pool:
        add("T01 Skill inventory", "CHECK", "init message has no skill list in this Claude version")
    elif all(c == 1 for c in counts.values()):
        add("T01 Skill inventory", "P", shown)
    else:
        add("T01 Skill inventory", "F", shown + " (each must be 1)")
else:
    add("T01 Skill inventory", "-", "R01 has no init message")

# ---------------------------------------------------------------- T09 + T10 (R01)
if need(r1, "T09 Agent mode, headless"):
    has_report = has(r"^#+\s*Standards", r1.final) and has(r"^#+\s*Spec", r1.final)
    said_mode = has(r"no[ -]?sub[ -]?agents?", r1.all)
    ev = "agents=%d, asked=%d, report=%s, says No sub-agents=%s" % (
        len(r1.agents()), len(r1.asked()), has_report, said_mode)
    if r1.agents() or not has_report:
        add("T09 Agent mode, headless", "F", ev)
    elif not said_mode:
        add("T09 Agent mode, headless", "CHECK", ev + " (first line must name the mode)")
    else:
        add("T09 Agent mode, headless", "P", ev)

if need(r1, "T10 two-axis-review result"):
    m = re.search(r"^#+\s*Spec\b", r1.final, re.M)
    s_std = r1.final[:m.start()] if m else r1.final
    s_spec = r1.final[m.start():] if m else ""
    S = {
        "S1 var": has(r"\bvar\b", s_std),
        "S2 JSDoc": has(r"jsdoc", s_std),
        "S3 console.log": has(r"console\.log", s_std),
        "S4 float money": has(r"float|fraction|non-?integer|part(ial)? cents?|round|integer cents", s_std),
    }
    P = {
        "P1 expiry date": has(r"expir", s_spec) and has(r">=|on the (expiry )?date|inclusive|off[- ]by[- ]one|same day|itself", s_spec),
        "P2 one code": has(r"ONE_CODE_ONLY|second code|one (discount )?code|R3", s_spec),
        "P3 receipt": has(r"receipt|R4", s_spec),
        "P4 shipping creep": has(r"shipping", s_spec),
    }
    spec_found = any("discount-codes.md" in str(i.get("file_path", "")) for n, i in r1.tools if n == "Read") \
        or "discount-codes.md" in r1.all
    ns, npp = sum(S.values()), sum(P.values())
    ev = "Standards %d/4 [%s]; Spec %d/4 [%s]; spec file found=%s; separate sections=%s" % (
        ns, ", ".join(k for k, v in S.items() if v), npp, ", ".join(k for k, v in P.items() if v),
        spec_found, bool(m))
    add("T10 two-axis-review result", "P" if (ns >= 3 and npp >= 3 and spec_found and m) else "F", ev)

# ---------------------------------------------------------------- T07b + T11 (R02)
r2 = Run("R02-shallow")
if need(r2, "T07b Agent mode named in request"):
    ev = "agents=%d, asked=%d" % (len(r2.agents()), len(r2.asked()))
    add("T07b Agent mode named in request", "F" if (r2.agents() or r2.asked()) else "P", ev)
if need(r2, "T11 Shallow-clone rule"):
    b = "\n".join(r2.bash())
    c1 = "is-shallow-repository" in b
    c2 = "--unshallow" in b
    c3 = has(r"fetch\s+(-\S+\s+)*origin\s+\+?main", b) or has(r"refs/remotes/origin/main", b)
    c4 = has(r"discount\.js", r2.final) and has(r"shipping\.js", r2.final)
    c5 = r2.shallow == "false"
    ev = "checked shallow=%s, unshallow=%s, fetched main=%s, both files in report=%s, repo now full=%s" % (c1, c2, c3, c4, c5)
    add("T11 Shallow-clone rule", "P" if all([c1, c2, c3, c4, c5]) else "F", ev)

# ---------------------------------------------------------------- T17 (R03)
r3 = Run("R03-pr")
if need(r3, "T17 pr skill"):
    auto = r3.loaded("pr")
    secs = all(has(p, r3.final) for p in (r"^#+\s*Summary", r"^#+\s*Evidence", r"^#+\s*Merge Danger"))
    door = has(r"Door", r3.final) and has(r"Blast Radius", r3.final)
    pushed = any(has(r"\bpush\b|gh\s+pr", c) for c in r3.bash())
    superp = [i.get("skill") for n, i in r3.tools if n == "Skill" and "superpowers" in str(i.get("skill", ""))]
    ev = "auto-load=%s, sections=%s, Door+Blast Radius=%s, push or PR=%s%s" % (
        auto, secs, door, pushed, (", superpowers loaded: %s" % superp) if superp else "")
    if pushed:
        add("T17 pr skill", "F", ev)
    elif auto and secs and door:
        add("T17 pr skill", "P", ev)
    elif secs and door:
        add("T17 pr skill", "CHECK", ev + " (format OK, but no auto-load: try /pr by hand)")
    else:
        add("T17 pr skill", "F", ev)

# ---------------------------------------------------------------- T14 (R04)
r4 = Run("R04-handoff")
if need(r4, "T14 Handoff, local"):
    files = [f for f in r4.tmp_new if f.startswith("handoff-")]
    body = rd(os.path.join(r4.dir, files[0])) if files else ""
    if not body:
        for w in r4.writes():
            if os.path.basename(w).startswith("handoff-"):
                body = rd(w)
    secs = {s: has(r"^#+.*%s" % s, body) or has(r"\*\*%s\*\*" % s, body)
            for s in ("Read order", "Do not redo", "Verify", "Suggested skills")}
    in_tmp = bool(files)
    clean = r4.git_status == ""
    path_told = any(TMPD in t or "/var/folders/" in t for t in [r4.all])
    ev = "file in temp folder=%s (%s), sections=%s, path given=%s, repo clean=%s" % (
        in_tmp, files[0] if files else "none", ",".join(k for k, v in secs.items() if v) or "none",
        path_told, clean)
    add("T14 Handoff, local", "P" if (in_tmp and all(secs.values()) and clean and path_told) else "F", ev)

# ---------------------------------------------------------------- T03 + T04 (R05, R05b)
r5 = Run("R05-grill")
if need(r5, "T03 Load chain"):
    lg = r5.loaded("grilling")
    ld = r5.loaded("domain-modeling")
    numbered = has(r"(^|\n)\s*(\*\*|#+\s*)?Q?1[\.\):]", r5.final)
    rec = ("➡" in r5.final) or has(r"recommend", r5.final)
    old = "CONTEXT.md" in r5.final
    install = has(r"Install the \S+ skill", r5.all)
    modeq = has(r"How do I run the steps that can use sub-agents", r5.all) or bool(r5.asked())
    ev = "grilling loaded=%s, domain-modeling loaded=%s, numbered questions=%s, recommendations=%s, mentions CONTEXT.md=%s, install msg=%s, agent-mode question=%s" % (
        lg, ld, numbered, rec, old, install, modeq)
    ok = lg and ld and numbered and rec and not old and not install and not modeq
    add("T03 Load chain", "P" if ok else "F", ev)

r5b = Run("R05b-grill-yes")
if need(r5b, "T04 Docs in a repo"):
    g = os.path.join(RUN, "fx", "grill-fixture", "GLOSSARY.md")
    adr = os.path.isdir(os.path.join(RUN, "fx", "grill-fixture", "docs", "adr"))
    gl = rd(g)
    ev = "GLOSSARY.md at root=%s (%d lines), docs/adr exists=%s" % (bool(gl), len(gl.splitlines()), adr)
    if gl and not adr:
        add("T04 Docs in a repo", "P", ev)
    elif gl and adr:
        add("T04 Docs in a repo", "CHECK", ev + " (an ADR is OK only if Claude offered one and you said yes)")
    else:
        add("T04 Docs in a repo", "CHECK", ev + " (no term settled yet? read raw/R05b-grill-yes)")

# ---------------------------------------------------------------- T06 (R06)
r6 = Run("R06-legacy")
if need(r6, "T06 Old CONTEXT.md glossary"):
    read_ctx = any("CONTEXT.md" in str(i.get("file_path", "")) for n, i in r6.tools if n == "Read") or "CONTEXT.md" in r6.all
    shelf = has(r"\bShelf\b", r6.all, re.M)
    article = has(r"\bArticle\b", r6.all, re.M)
    rename = has(r"renam", r6.all) and "GLOSSARY.md" in r6.all
    ev = "read CONTEXT.md=%s, uses Shelf=%s, uses Article=%s, offers rename to GLOSSARY.md=%s" % (read_ctx, shelf, article, rename)
    add("T06 Old CONTEXT.md glossary", "P" if all([read_ctx, shelf, article, rename]) else "F", ev)

# ---------------------------------------------------------------- T18 (R07, R08)
r7, r8 = Run("R07-noarch"), Run("R08-nohandoff")
if need(r7, "T18a No unasked architecture report") :
    bad = r7.loaded("improve-codebase-architecture") or any(w.endswith(".html") for w in r7.writes()) \
        or any(f.startswith("architecture-review-") for f in r7.tmp_new)
    add("T18a No unasked architecture report", "F" if bad else "P",
        "skill loaded or HTML written=%s, reply lines=%d" % (bad, len(r7.final.strip().splitlines())))
if need(r8, "T18b No unasked handoff"):
    bad = r8.loaded("handoff") or bool(r8.writes()) or any(f.startswith("handoff-") for f in r8.tmp_new)
    add("T18b No unasked handoff", "F" if bad else "P",
        "skill loaded or file written=%s, reply lines=%d" % (bad, len(r8.final.strip().splitlines())))

# ---------------------------------------------------------------- T15 (R09)
r9 = Run("R09-handoff-own")
if need(r9, "T15 Handoff with its own format"):
    saw = "COURSE-HANDOFF" in r9.all
    n_tmp = len([f for f in r9.tmp_new if f.startswith("handoff-")])
    course_changed = any(w.endswith("COURSE-HANDOFF.md") for w in r9.writes())
    both = n_tmp >= 1 and course_changed
    ev = "found COURSE-HANDOFF.md=%s, temp handoff files=%d, COURSE-HANDOFF.md changed=%s" % (saw, n_tmp, course_changed)
    if both or not saw:
        add("T15 Handoff with its own format", "F", ev)
    else:
        add("T15 Handoff with its own format", "P", ev + " (headless: no one can answer, so it must not write both)")

# ---------------------------------------------------------------- T12 headless (R10)
r10 = Run("R10-arch")
if not r10.exists:
    add("T12 Architecture report (headless)", "-", "skipped (--skip-arch)")
elif need(r10, "T12 Architecture report (headless)"):
    html_files = [f for f in r10.tmp_new if f.endswith(".html")]
    html = rd(os.path.join(r10.dir, html_files[0])) if html_files else ""
    if not html:
        for w in r10.writes():
            if w.endswith(".html"):
                html = rd(w)
    txt = html + "\n" + r10.all
    signs = {
        "1 hot spot src/order": has(r"src/order", txt),
        "2 deep Order module": has(r"handleOrder|placeOrder", txt) and has(r"deep", txt),
        "3 orderService middle man": has(r"orderService", txt),
        "4 PricingClient adapter": has(r"PricingClient", txt) and has(r"adapter", txt),
        "5 glossary words": all(has(w, txt, re.M) for w in (r"\bOrder\b", r"Line Item", r"\bQuote\b")),
        "6 vocabulary": all(has(w, txt) for w in (r"\bmodule\b", r"\binterface\b", r"\bseam\b")),
        "7 ADR-0001 respected": has(r"ADR[- ]?0*1|pricing-stays-remote", txt),
    }
    dark = has(r"theme['\"]?\s*:\s*['\"]dark|%%\{init.*dark|background(-color)?\s*:\s*#(0|1|2)", html)
    light_toggle = has(r"prefers-color-scheme\s*:\s*light|theme-?toggle|light mode", html)
    asked = has(r"which of these would you like to explore", r10.all)
    clean = r10.git_status == ""
    ev = "HTML in temp=%s; dark=%s; light toggle=%s; asks which to explore=%s; repo clean=%s; signs: %s" % (
        bool(html_files), dark, light_toggle, asked, clean,
        ", ".join(k for k, v in signs.items() if v) or "none")
    add("T12 Architecture report (headless)", "CHECK" if (html and dark and not light_toggle and clean) else "F",
        ev + " (Claude reviews the content by hand)")

# ---------------------------------------------------------------- Report
out = []
out.append("# Skill test results (headless)\n")
out.append("Run folder: `%s`  " % RUN)
init = r1.init or {}
out.append("Claude: %s, model: %s  " % (init.get("claude_code_version", "?"), init.get("model", "?")))
out.append("Skills build under test: 2026-10-14.3\n")
out.append("| Test | Surface | Result | Evidence |")
out.append("|---|---|---|---|")
for t, s, r, e in RESULTS:
    out.append("| %s | %s | **%s** | %s |" % (t, s, r, e.replace("|", "/")))
out.append("")
out.append("Result codes: P = pass, F = fail, CHECK = needs a person or Claude to read the raw output, ERROR = the run did not finish, - = not run.\n")
out.append("## Runs\n")
out.append("| Run | Exit | Cost (USD) | Tools used | Permission denials |")
out.append("|---|---|---|---|---|")
total = 0.0
for d in sorted(os.listdir(RAW)):
    r = Run(d)
    if r.cost:
        total += float(r.cost)
    tools = {}
    for n in r.tool_names():
        tools[n] = tools.get(n, 0) + 1
    out.append("| %s | %s | %s | %s | %s |" % (
        d, r.exit or "?", ("%.2f" % r.cost) if r.cost else "?",
        ", ".join("%s x%d" % kv for kv in sorted(tools.items())) or "none",
        ("; ".join(r.denied))[:200].replace("|", "/") or "none"))
out.append("\nTotal cost estimate: %.2f USD (on a subscription, this is usage, not a bill)." % total)
open(os.path.join(RUN, "results.md"), "w").write("\n".join(out) + "\n")
print("\n".join(out))
PY

say ""
say "Grading..."
python3 "$RUN/grade.py" "$RUN" "$TMPD"

( cd "$RESULTS_ROOT" && zip -qr "run-$STAMP.zip" "run-$STAMP" -x "run-$STAMP/fx/*/.git/*" )
say ""
say "Done."
say "Results: $RUN/results.md"
say "Send this ZIP to Claude in the Project: $RESULTS_ROOT/run-$STAMP.zip"
