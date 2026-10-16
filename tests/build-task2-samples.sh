#!/usr/bin/env bash
# build-task2-samples.sh
# Build 2026-10-15.1
#
# Makes the 2 sample files for task 2 (reverse engineering), from open-source
# code (Apache License 2.0):
#
#   deployed/petclinic-boot.jar  Spring Boot executable ("fat") JAR.
#                                Same packaging as an app in an AKS container.
#                                Source: github.com/spring-projects/spring-petclinic
#   deployed/petclinic-mvc.war   Classic Spring MVC WAR for Tomcat or Jetty.
#                                Same packaging as an on-prem app server deploy.
#                                Source: github.com/spring-petclinic/spring-framework-petclinic
#
# It also keeps the original source in answer-key/. We use it ONLY to check
# the decompiled result. Claude must not read answer-key/ during the test.
#
# Usage:  bash build-task2-samples.sh [target-folder]
# Default target: ~/Downloads/WORKSPACE/SkillsPlugins/task2-samples
# Needs: git, a JDK 17 or later, and internet (GitHub and Maven Central).
# Time: approximately 5-10 minutes the first time (Maven downloads libraries).
# It writes only in the target folder and in ~/.m2 (the normal Maven cache).
# Works with the macOS default bash (3.2).

set -euo pipefail

TARGET="${1:-$HOME/Downloads/WORKSPACE/SkillsPlugins/task2-samples}"
JAR_REPO="https://github.com/spring-projects/spring-petclinic.git"
WAR_REPO="https://github.com/spring-petclinic/spring-framework-petclinic.git"

say()  { printf '%s\n' "$*"; }
stop() { printf 'STOP: %s\n' "$*" >&2; exit 1; }

case "$TARGET" in *" "*) stop "the target path has a space: $TARGET" ;; esac
[ -e "$TARGET" ] && stop "$TARGET exists. Move it away, or give a different target folder."
command -v git >/dev/null 2>&1 || stop "git is not installed."

# ---- Find a JDK 17 or later -------------------------------------------------
pick_jdk() {
  if [ -x /usr/libexec/java_home ]; then
    for v in 25 21 17; do
      h="$(/usr/libexec/java_home -v "$v" 2>/dev/null || true)"
      if [ -n "$h" ] && [ -x "$h/bin/javac" ]; then echo "$h"; return 0; fi
    done
    h="$(/usr/libexec/java_home -v 17+ 2>/dev/null || true)"
    if [ -n "$h" ] && [ -x "$h/bin/javac" ]; then echo "$h"; return 0; fi
  fi
  if [ -n "${JAVA_HOME:-}" ] && [ -x "$JAVA_HOME/bin/javac" ]; then echo "$JAVA_HOME"; return 0; fi
  return 1
}
JDK="$(pick_jdk || true)"
[ -n "$JDK" ] || stop "no JDK found. Install one, for example: brew install --cask temurin@21"
MAJOR="$("$JDK/bin/java" -version 2>&1 | sed -n 's/.*version "\([0-9]*\).*/\1/p' | head -1)"
[ "${MAJOR:-0}" -ge 17 ] || stop "the JDK at $JDK is version $MAJOR. Version 17 or later is necessary. Install one, for example: brew install --cask temurin@21"
export JAVA_HOME="$JDK"
export PATH="$JAVA_HOME/bin:$PATH"

mkdir -p "$TARGET/deployed" "$TARGET/answer-key" "$TARGET/logs"
TARGET="$(cd "$TARGET" && pwd -P)"
say "Target:   $TARGET"
say "JDK:      $JAVA_HOME (Java $MAJOR)"
say ""

MVN_FLAGS="-B -q -DskipTests -Dcheckstyle.skip=true -Dspring-javaformat.skip=true"

build() {  # build <name> <repo-url> <artifact-glob> <output-name>
  name="$1"; url="$2"; glob="$3"; out="$4"
  src="$TARGET/answer-key/$name"
  say "[$name] $(date +%H:%M:%S) clone"
  git clone -q --depth 1 "$url" "$src"
  sha="$(git -C "$src" rev-parse --short HEAD)"
  say "[$name] $(date +%H:%M:%S) build (commit $sha). This can take some minutes."
  ( cd "$src" && chmod +x mvnw && ./mvnw $MVN_FLAGS package ) > "$TARGET/logs/$name-build.log" 2>&1 \
    || stop "the $name build failed. See $TARGET/logs/$name-build.log (last lines below).
$(tail -25 "$TARGET/logs/$name-build.log")"
  art=""
  for f in $src/target/$glob; do
    case "$f" in *-plain.jar|*-sources.jar|*-javadoc.jar|*.original) continue ;; esac
    [ -f "$f" ] && { art="$f"; break; }
  done
  [ -n "$art" ] || stop "no $glob found in $src/target. See $TARGET/logs/$name-build.log"
  cp "$art" "$TARGET/deployed/$out"
  echo "$name $url $sha $(basename "$art")" >> "$TARGET/answer-key/SOURCES.txt"
  say "[$name] $(date +%H:%M:%S) done: deployed/$out"
}

build spring-petclinic           "$JAR_REPO" "*.jar" petclinic-boot.jar
build spring-framework-petclinic "$WAR_REPO" "*.war" petclinic-mvc.war

# ---- Summary ----------------------------------------------------------------
summ() {  # summ <file> <expected-folder>
  f="$TARGET/deployed/$1"
  size="$(du -h "$f" | cut -f1)"
  sum="$(shasum -a 256 "$f" 2>/dev/null | cut -c1-16 || sha256sum "$f" | cut -c1-16)"
  classes="$(unzip -l "$f" | grep -c '\.class$' || true)"
  libs="$(unzip -l "$f" | grep -cE '/lib/[^/]+\.jar$' || true)"
  layout="no"; unzip -l "$f" | grep -q " $2" && layout="yes"
  printf '%-20s size %-6s sha256 %s...  %s present: %s  app+lib classes in archive: %s  library jars: %s\n' \
    "$1" "$size" "$sum" "$2" "$layout" "$classes" "$libs"
}
say ""
say "Samples are ready in: $TARGET/deployed"
summ petclinic-boot.jar BOOT-INF/
summ petclinic-mvc.war  WEB-INF/
say ""
say "Original source (answer key, do not give it to the decompile test): $TARGET/answer-key"
cat "$TARGET/answer-key/SOURCES.txt"
