#!/usr/bin/env bash
# decompile.sh  (skill decompile-java-artifact, build 2026-10-15.1)
#
# Decompiles a deployed Java artifact (Spring Boot fat JAR, WAR, EAR-less plain
# JAR) into a repo-like folder, then makes an inventory and a risk scan.
# Runs fully local. It uses the network only to download a JRE when no Java is
# found, and to query OSV for CVEs (both optional, both fail safe).
#
# Usage:
#   bash decompile.sh <artifact.jar|war> <output-folder>
#   bash decompile.sh --fetch-jre <linux-x64|linux-aarch64|mac-x64|mac-aarch64> <dest-folder>
#   bash decompile.sh --check            (print the Java that will be used, then exit)
#
# Environment (all optional):
#   DJA_JAVA=/path/to/java   use this java
#   DJA_NO_DOWNLOAD=1        never download a JRE
#   DJA_NO_OSV=1             never query OSV
#   KEEP_WORK=1              keep <out>/_work/ (unpacked archive) for debugging
#   XMX=2g                   CFR heap
#
# Exit codes: 0 ok, 1 error, 3 no Java (see references/java-on-demand.md)
#
# Output:
#   pom.xml                  embedded Maven pom (if the archive has one)
#   pom-reconstructed.xml    made from lib/ (resolved list, also transitive)
#   DEPENDENCIES.md          each library: group, artifact, version, data source
#   INVENTORY.md / .json     classes by role, HTTP endpoints, wiring, messaging, config keys
#   RISKS.md                 secrets (masked), config hardening, code risks, library CVEs
#   DECOMPILE-REPORT.txt     counts, tool versions, warnings
#   src/main/java            decompiled app classes (CFR)
#   src/main/resources       config, SQL, i18n, templates (as is)
#   src/main/webapp          WAR only: JSP, tags, static files (as is)
#   _meta/                   MANIFEST.MF, build-info, git.properties, SBOM, layers, tool logs
#
# WARNING: the output shows all strings in the code and config (passwords,
# keys, URLs). Keep it on the local machine.

set -euo pipefail
export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS_KEEP:-}"   # remove proxy-agent noise in sandboxes

HERE="$(cd "$(dirname "$0")" && pwd -P)"
ROOT="$(cd "$HERE/.." && pwd -P)"
CFR_JAR="$ROOT/tools/cfr-0.152.jar"
CACHE="${DJA_CACHE:-$ROOT/cache}"
XMX="${XMX:-2g}"
BUILD="2026-10-15.1"

stop() { printf 'STOP: %s\n' "$*" >&2; exit 1; }

# ---- Java: find one, or get one ---------------------------------------------
os_arch() {
  local os arch
  case "$(uname -s)" in Darwin) os=mac;; Linux) os=linux;; *) os=unknown;; esac
  case "$(uname -m)" in x86_64|amd64) arch=x64;; arm64|aarch64) arch=aarch64;; *) arch=unknown;; esac
  echo "$os-$arch"
}
works() { [ -n "${1:-}" ] && [ -x "$1" ] && "$1" -version >/dev/null 2>&1; }

find_java() {
  local c
  for c in "${DJA_JAVA:-}" "${JAVA_HOME:+$JAVA_HOME/bin/java}"; do works "$c" && { echo "$c"; return 0; }; done
  c="$(command -v java 2>/dev/null || true)"; works "$c" && { echo "$c"; return 0; }
  if [ -x /usr/libexec/java_home ]; then
    c="$(/usr/libexec/java_home 2>/dev/null || true)"; works "$c/bin/java" && { echo "$c/bin/java"; return 0; }
  fi
  for c in /opt/homebrew/opt/openjdk*/bin/java /usr/local/opt/openjdk*/bin/java \
           "$CACHE"/jre/*/bin/java "$CACHE"/jre/*/Contents/Home/bin/java; do
    works "$c" && { echo "$c"; return 0; }
  done
  return 1
}

unpack_jre() {  # unpack_jre <tar.gz>  -> into $CACHE/jre
  mkdir -p "$CACHE/jre"
  tar -xzf "$1" -C "$CACHE/jre" || return 1
}

adoptium_url() {  # adoptium_url <os-arch>
  local os="${1%-*}" arch="${1#*-}"
  echo "https://api.adoptium.net/v3/binary/latest/21/ga/$os/$arch/jre/hotspot/normal/eclipse"
}

fetch_jre() {  # fetch_jre <os-arch> <dest-file>  (no admin rights: user folders only)
  command -v curl >/dev/null 2>&1 || return 1
  curl -fsSL --connect-timeout 10 -m 600 -o "$2.part" "$(adoptium_url "$1")" && mv "$2.part" "$2"
}

get_java() {
  local j oa f
  if j="$(find_java)"; then echo "$j"; return 0; fi
  oa="$(os_arch)"
  # 1. A JRE archive already put next to the skill or in the cache.
  for f in "$ROOT"/jre/*.tar.gz "$CACHE"/*.tar.gz; do
    [ -f "$f" ] || continue
    case "$f" in *"${oa%-*}"*) ;; *) continue;; esac   # OS must match
    case "$f" in *"${oa#*-}"*) ;; *) continue;; esac   # CPU must match
    echo "Java: unpacking $f" >&2
    unpack_jre "$f" && j="$(find_java)" && { echo "$j"; return 0; }
  done
  # 2. Download Temurin 21 JRE into the cache (no admin rights).
  if [ "${DJA_NO_DOWNLOAD:-0}" != 1 ]; then
    mkdir -p "$CACHE"
    echo "Java: no Java found. Downloading Temurin 21 JRE ($oa) into $CACHE ..." >&2
    if fetch_jre "$oa" "$CACHE/temurin21-jre-$oa.tar.gz"; then
      unpack_jre "$CACHE/temurin21-jre-$oa.tar.gz" && j="$(find_java)" && { echo "$j"; return 0; }
    fi
  fi
  cat >&2 <<EOF
NEED_JRE $oa
No working Java was found, and the download failed or is off.
Any Java 8 or later is enough (CFR needs Java 6+).
Get a JRE for $oa with ONE of these:
  a) Put a Temurin JRE .tar.gz for $oa in: $ROOT/jre/   (browser: https://adoptium.net/temurin/releases/?package=jre)
     or direct link: $(adoptium_url "$oa")
  b) On a Mac with internet (desktop Code tab or Terminal), run:
     bash $HERE/decompile.sh --fetch-jre $oa $ROOT/jre
  c) Set DJA_JAVA=/path/to/bin/java
Then run this command again.
EOF
  exit 3
}

# ---- Modes ---------------------------------------------------------------
if [ "${1:-}" = "--fetch-jre" ]; then
  [ $# -eq 3 ] || stop "usage: $0 --fetch-jre <os-arch> <dest-folder>"
  mkdir -p "$3"
  fetch_jre "$2" "$3/temurin21-jre-$2.tar.gz" || stop "download failed: $(adoptium_url "$2")"
  echo "OK: $3/temurin21-jre-$2.tar.gz"; exit 0
fi
if [ "${1:-}" = "--check" ]; then
  J="$(get_java)"; echo "java: $J"; "$J" -version 2>&1 | grep -v JAVA_TOOL_OPTIONS | head -1
  command -v python3 >/dev/null && python3 -c 'print("python3: ok")' || echo "python3: MISSING"
  exit 0
fi

[ $# -eq 2 ] || stop "usage: $0 <artifact> <output-folder>   (or --fetch-jre, --check)"
ART="$(cd "$(dirname "$1")" && pwd -P)/$(basename "$1")"
OUT="$2"
[ -f "$ART" ] || stop "no file: $ART"
[ -e "$OUT" ] && stop "$OUT exists. Give a new output folder."
[ -f "$CFR_JAR" ] || stop "CFR not found: $CFR_JAR"
command -v python3 >/dev/null 2>&1 && python3 -c 'import zipfile,json' 2>/dev/null \
  || stop "python3 not found. On a Mac: xcode-select --install (or brew install python)."
command -v unzip >/dev/null 2>&1 || stop "unzip not found"
JAVA="$(get_java)"

mkdir -p "$OUT"; OUT="$(cd "$OUT" && pwd -P)"
WORK="$OUT/_work"; mkdir -p "$WORK/unpacked" "$OUT/_meta"
REPORT="$OUT/DECOMPILE-REPORT.txt"
log() { printf '%s\n' "$*" | tee -a "$REPORT"; }

log "Skill:    decompile-java-artifact build $BUILD"
log "Artifact: $ART"
log "SHA-256:  $( (sha256sum "$ART" 2>/dev/null || shasum -a 256 "$ART") | cut -d' ' -f1)"
log "Date:     $(date '+%Y-%m-%d %H:%M:%S %Z')"
log "Java:     $JAVA ($("$JAVA" -version 2>&1 | grep -v JAVA_TOOL_OPTIONS | head -1))"
log "CFR:      0.152"

( cd "$WORK/unpacked" && unzip -q -o "$ART" ) || stop "unzip failed. Is it a JAR or WAR?"
U="$WORK/unpacked"

# ---- 1. Layout -----------------------------------------------------------
if   [ -d "$U/BOOT-INF/classes" ]; then KIND=boot; CLS="$U/BOOT-INF/classes"; LIB="$U/BOOT-INF/lib"
elif [ -d "$U/WEB-INF" ]; then KIND=war; CLS="$U/WEB-INF/classes"; LIB="$U/WEB-INF/lib"; mkdir -p "$CLS"
else KIND=jar; CLS="$U"; LIB=""
fi
log "Layout:   $KIND"

# ---- 2. App classes into one JAR (CFR input) ------------------------------
APPJAR="$WORK/app-classes.jar"
( cd "$CLS" && find . -name '*.class' -not -path './org/springframework/boot/loader/*' \
    -not -path './META-INF/*' | sed 's|^\./||' > "$WORK/classes.txt" )
[ -s "$WORK/classes.txt" ] || stop "no app classes found in $CLS"
( cd "$CLS" && python3 - "$WORK/classes.txt" "$APPJAR" <<'PY'
import sys, zipfile
names = [l.strip() for l in open(sys.argv[1]) if l.strip()]
with zipfile.ZipFile(sys.argv[2], 'w', zipfile.ZIP_DEFLATED) as z:
    for n in names: z.write(n, n)
PY
)
NCLS=$(wc -l < "$WORK/classes.txt" | tr -d ' ')
NTOP=$(grep -vc '\$' "$WORK/classes.txt" || true)
log "Classes:  $NCLS app classes ($NTOP top-level)"

CP=""
[ -n "$LIB" ] && [ -d "$LIB" ] && CP="$(find "$LIB" -name '*.jar' | sort | tr '\n' ':')"

# ---- 3. Decompile (CFR) ---------------------------------------------------
mkdir -p "$OUT/src/main/java"
log ""
log "[CFR] start $(date +%H:%M:%S)"
"$JAVA" -Xmx"$XMX" -jar "$CFR_JAR" "$APPJAR" --outputdir "$WORK/cfr" --silent true \
  --caseinsensitivefs true ${CP:+--extraclasspath "$CP"} > "$WORK/cfr.log" 2>&1 \
  || log "[CFR] exit code $? (see _meta/cfr.log)"
[ -d "$WORK/cfr" ] && ( cd "$WORK/cfr" && find . -name '*.java' | while read -r f; do
    mkdir -p "$OUT/src/main/java/$(dirname "$f")"; cp "$f" "$OUT/src/main/java/$f"; done )
[ -f "$WORK/cfr/summary.txt" ] && cp "$WORK/cfr/summary.txt" "$OUT/_meta/cfr-summary.txt"
log "[CFR] done  $(date +%H:%M:%S): $(find "$OUT/src/main/java" -name '*.java' | wc -l | tr -d ' ') .java files"

# ---- 4. Resources and web files (as is) -----------------------------------
mkdir -p "$OUT/src/main/resources"
( cd "$CLS" && find . -type f -not -name '*.class' -not -path './META-INF/*' \
    -not -path './org/springframework/boot/loader/*' | while read -r f; do
    [ "$KIND" = jar ] && case "$f" in ./BOOT-INF/*|./WEB-INF/*) continue;; esac
    mkdir -p "$OUT/src/main/resources/$(dirname "$f")"; cp "$f" "$OUT/src/main/resources/$f"; done )
if [ "$KIND" = war ]; then
  mkdir -p "$OUT/src/main/webapp"
  ( cd "$U" && find . -type f -not -path './WEB-INF/classes/*' -not -path './WEB-INF/lib/*' \
      -not -path './META-INF/*' | while read -r f; do
      mkdir -p "$OUT/src/main/webapp/$(dirname "$f")"; cp "$f" "$OUT/src/main/webapp/$f"; done )
fi
for f in META-INF/MANIFEST.MF META-INF/build-info.properties META-INF/sbom BOOT-INF/layers.idx BOOT-INF/classpath.idx; do
  [ -e "$U/$f" ] && cp -R "$U/$f" "$OUT/_meta/"
done
[ -f "$OUT/src/main/resources/git.properties" ] && cp "$OUT/src/main/resources/git.properties" "$OUT/_meta/"

# ---- 5. pom.xml and dependencies ------------------------------------------
EMB="$(find "$U/META-INF/maven" -name pom.xml 2>/dev/null | head -1 || true)"
if [ -n "$EMB" ]; then cp "$EMB" "$OUT/pom.xml"; log "pom.xml:  embedded Maven pom found"
else log "pom.xml:  no embedded pom. Use pom-reconstructed.xml."; fi
python3 "$HERE/deps.py" "${LIB:-}" "$OUT" "$U" | tee -a "$REPORT"

# ---- 6. Inventory and risk scan -------------------------------------------
python3 "$HERE/inventory.py" "$OUT" | tee -a "$REPORT"
DJA_NO_OSV="${DJA_NO_OSV:-0}" python3 "$HERE/risk_scan.py" "$OUT" | tee -a "$REPORT"

# ---- 7. Warnings and clean-up ---------------------------------------------
log ""
log "CFR warnings (methods or classes that failed or are approximate):"
grep -rl -E 'Decompilation failed|Unable to fully structure|WARNING - ' "$OUT/src/main/java" 2>/dev/null \
  | sed "s|$OUT/||; s|^|  |" | tee -a "$REPORT" || true
cp "$WORK/cfr.log" "$OUT/_meta/" 2>/dev/null || true
if [ "${KEEP_WORK:-0}" = 1 ]; then log "Done. _work/ kept (KEEP_WORK=1)."
else rm -rf "$WORK"; log "Done. _work/ deleted."; fi
