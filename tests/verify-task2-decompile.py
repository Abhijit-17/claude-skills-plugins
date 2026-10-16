#!/usr/bin/env python3
"""verify-task2-decompile.py  (build 2026-10-16.1)

Compares the output of the decompile-java-artifact skill with the original
source of the 2 Spring PetClinic samples (task2-samples/answer-key/).

Usage:
  python3 verify-task2-decompile.py <task2-samples-folder> <output-folder>
  <output-folder> has petclinic-boot/ and petclinic-mvc/ (decompile.sh output).

Exit code 0 = all checks PASS. 1 = one or more FAIL.
"""
import os, re, sys

APPS = [("petclinic-boot", "spring-petclinic"),
        ("petclinic-mvc", "spring-framework-petclinic")]
# Maven resource filtering puts real values into these files at build time.
# A difference here is correct (the decompile shows the deployed values).
FILTERED = {"spring/datasource-config.xml", "spring/data-access.properties",
            "spring/business-config.xml"}
EXTRA_OK = {"git.properties"}  # made by the build (git-commit-id plugin)
ANNOTATIONS = ["@Query", "@Table", "@Column", "@OneToMany", "@ManyToOne",
               "@ManyToMany", "@Transactional", "@Cacheable", "@Controller",
               "@RestController", "@Service", "@Repository", "@Entity"]
MAPPING = re.compile(r"@(Get|Post|Put|Delete|Patch|Request)Mapping\b")
fails = 0

def files(root, sub, ext=""):
    base = os.path.join(root, sub); out = set()
    for d, _, fs in os.walk(base):
        for f in fs:
            if f.endswith(ext):
                out.add(os.path.relpath(os.path.join(d, f), base))
    return out

def code(path):
    """Java text without comments. String and char literals stay as they are
    (a path such as "/owners/*/pets" is not a comment)."""
    t = open(path, encoding="utf-8", errors="replace").read()
    out, i, n = [], 0, len(t)
    while i < n:
        c = t[i]
        if t.startswith('"""', i):                       # text block
            j = t.find('"""', i + 3); j = n if j < 0 else j + 3
            out.append(t[i:j]); i = j
        elif c in "\"'":                                # string or char literal
            j = i + 1
            while j < n and t[j] != c and t[j] != "\n":
                j += 2 if t[j] == "\\" else 1
            out.append(t[i:j + 1]); i = j + 1
        elif t.startswith("//", i):
            j = t.find("\n", i); i = n if j < 0 else j
        elif t.startswith("/*", i):
            j = t.find("*/", i + 2); i = n if j < 0 else j + 2
        else:
            out.append(c); i += 1
    return "".join(out)

def check(ok, text):
    global fails
    print(("  PASS  " if ok else "  FAIL  ") + text)
    if not ok: fails += 1

def method_mappings(root):
    n = 0
    for f in files(root, "src/main/java", ".java"):
        t = code(os.path.join(root, "src/main/java", f))
        for m in MAPPING.finditer(t):
            # Class-level prefix: the text up to the next "{" (after the
            # annotation arguments) declares a class or interface.
            rest = t[m.end():]
            if rest.startswith("("):
                depth = 0
                for i, ch in enumerate(rest):
                    depth += ch == "("; depth -= ch == ")"
                    if depth == 0: rest = rest[i + 1:]; break
            head = rest.split("{", 1)[0]
            if not re.search(r"\b(class|interface)\b", head):
                n += 1
    return n

def inventory_endpoints(out):
    m = re.search(r"## HTTP endpoints \((\d+)\)", open(os.path.join(out, "INVENTORY.md")).read())
    return int(m.group(1)) if m else -1

if len(sys.argv) != 3:
    sys.exit(__doc__)
samples, outroot = sys.argv[1], sys.argv[2]
for app, key in APPS:
    out = os.path.join(outroot, app); src = os.path.join(samples, "answer-key", key)
    print(f"\n== {app}")
    if not os.path.isdir(out):
        check(False, f"output folder missing: {out}"); continue
    rep = open(os.path.join(out, "DECOMPILE-REPORT.txt")).read()
    check("Done." in rep, "DECOMPILE-REPORT.txt ends with Done.")
    for name in ["pom.xml", "pom-reconstructed.xml", "DEPENDENCIES.md", "INVENTORY.md", "RISKS.md"]:
        check(os.path.isfile(os.path.join(out, name)), f"{name} exists")
    dj, sj = files(out, "src/main/java", ".java"), files(src, "src/main/java", ".java")
    check(dj == sj, f"Java files: decompiled {len(dj)}, source {len(sj)}, missing {sorted(sj - dj)}, extra {sorted(dj - sj)}")
    for sub in ["src/main/resources", "src/main/webapp"]:
        a, b = files(out, sub), files(src, sub)
        if not a and not b: continue
        check(b <= a and (a - b) <= EXTRA_OK, f"{sub}: decompiled {len(a)}, source {len(b)}, missing {sorted(b - a)[:5]}, extra {sorted(a - b)[:5]}")
        diff = sorted(f for f in a & b if open(os.path.join(out, sub, f), "rb").read() != open(os.path.join(src, sub, f), "rb").read())
        check(set(diff) <= FILTERED, f"{sub}: {len(a & b) - len(diff)}/{len(a & b)} byte-identical; different: {diff} (Maven-filtered files are allowed)")
    se, ie = method_mappings(src), inventory_endpoints(out)
    check(se == ie, f"HTTP endpoints: source {se}, INVENTORY.md {ie}")
    for ann in ANNOTATIONS:
        s = sum(len(re.findall(re.escape(ann) + r"\b", code(os.path.join(src, "src/main/java", f)))) for f in sj)
        d = sum(len(re.findall(re.escape(ann) + r"\b", code(os.path.join(out, "src/main/java", f)))) for f in dj)
        if s or d:
            check(s == d, f"{ann}: source {s}, decompiled {d}")
    for line in rep.splitlines():
        if line.startswith(("Classes:", "Libs:", "Inventory:", "Risks:")):
            print("  INFO  " + line)

print(f"\nResult: {'ALL PASS' if fails == 0 else str(fails) + ' FAIL'}")
sys.exit(1 if fails else 0)
