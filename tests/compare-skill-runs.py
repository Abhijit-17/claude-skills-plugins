#!/usr/bin/env python3
# compare-skill-runs.py
# Build 2026-10-29.1. Written in ASD-STE100.
# 2026-10-29.1: expectation 2 is "not more RUNTIME.md reads" (the CLI already reads it once per session).
#
# Compares 2 runs of run-skill-tests.sh (prompt audit, Phase 3b).
# Usage: python3 compare-skill-runs.py <run A folder or results.json> <run B folder or results.json>
# Run A = baseline (claude.ai build). Run B = new build (--local).
# Output: a markdown table on stdout.
import json, os, sys

TOKENS_PER_READ = 1616  # one RUNTIME.md read, about 6,467 chars / 4

def load(p):
    if os.path.isdir(p):
        p = os.path.join(p, "results.json")
    with open(p) as f:
        return json.load(f)

if len(sys.argv) != 3:
    sys.exit("Usage: compare-skill-runs.py <run A> <run B>")
a, b = load(sys.argv[1]), load(sys.argv[2])

def by_test(d):
    return {r["test"]: r for r in d["results"]}

ra, rb = by_test(a), by_test(b)
order = list(ra) + [t for t in rb if t not in ra]
def npass(d):
    return sum(1 for r in d["results"] if r["result"] == "P")

out = ["# Phase 3b: A/B of the skill test kit\n",
       "| Item | Run A | Run B |", "|---|---|---|",
       "| Mode | %s | %s |" % (a["mode"], b["mode"] + (" (build %s)" % b.get("local_build") if b["mode"] == "local" else "")),
       "| Claude, model | %s, %s | %s, %s |" % (a.get("claude_version"), a.get("model"), b.get("claude_version"), b.get("model")),
       "| PASS results | %d | %d |" % (npass(a), npass(b)),
       "| Build mix in a run | %s | %s |" % ("YES" if a["any_mix"] else "no", "YES" if b["any_mix"] else "no"),
       "| RUNTIME.md Read calls, total | %d | %d |" % (a["total_runtime_reads"], b["total_runtime_reads"]),
       "", "## Tests\n", "| Test | Run A | Run B | Change |", "|---|---|---|---|"]
for t in order:
    x = ra.get(t, {}).get("result", "-")
    y = rb.get(t, {}).get("result", "-")
    ch = "same" if x == y else ("BETTER" if y == "P" else ("WORSE" if x == "P" else "changed"))
    out.append("| %s | %s | %s | %s |" % (t, x, y, ch))

out += ["", "## RUNTIME.md Read calls per run (measures H01)\n",
        "| Run | Run A | Run B | Difference |", "|---|---|---|---|"]
runs = sorted(set(a["runs"]) | set(b["runs"]))
for r in runs:
    x = len(a["runs"].get(r, {}).get("runtime_reads", []))
    y = len(b["runs"].get(r, {}).get("runtime_reads", []))
    out.append("| %s | %d | %d | %+d |" % (r, x, y, y - x))
diff = b["total_runtime_reads"] - a["total_runtime_reads"]
out.append("\nTotal difference: %+d reads, about %+d tokens over all runs." % (diff, diff * TOKENS_PER_READ))

worse = [t for t in order if ra.get(t, {}).get("result") == "P" and rb.get(t, {}).get("result") != "P"]
out.append("\n## Verdict\n")
if a["any_mix"] or b["any_mix"]:
    out.append("- INVALID: a run used the wrong build (see 'Build mix' in its results.md). Fix the setup and run again.")
out.append("- Expected 1 (same or more PASS results): %s (%d -> %d%s)." % (
    "MET" if npass(b) >= npass(a) and not worse else "NOT MET", npass(a), npass(b),
    "; worse: " + ", ".join(worse) if worse else ""))
out.append("- Expected 2 (not more RUNTIME.md reads in run B): %s (%d -> %d)." % (
    "MET" if b["total_runtime_reads"] <= a["total_runtime_reads"] else "NOT MET",
    a["total_runtime_reads"], b["total_runtime_reads"]))
print("\n".join(out))
