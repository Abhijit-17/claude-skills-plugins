---
name: decompile-java-artifact
description: Reverse engineer a deployed Java JAR or WAR (Spring Boot fat JAR, classic Spring MVC WAR, plain JAR) when the source code is not available. Decompiles it into a repo-like folder (src/main/java, resources, webapp, pom.xml, dependency list), maps endpoints and wiring, scans for secrets, config and code risks and library CVEs, and explains each component. Use when the user gives a .jar or .war and asks to decompile it, reverse engineer it, recover its source, explain how it works, or audit it.
metadata:
  build: "2026-10-15.1"
  tools: "CFR 0.152 (MIT, bundled)"
---

# Decompile a Java artifact

The user often has ONLY the deployed file (from DevOps, an app server or an AKS image). This skill turns it into readable source, a map, a risk report and an explanation.

## Rules

1. **Authorization.** Use this skill only on software that the user or the user's team owns or may examine. If this is not clear, ask once.
2. **Where it runs.** Run the decompile on the computer that has the file. Do not copy the user's real JAR or WAR into a cloud sandbox unless the user says so. (Open-source test files are an exception.)
3. **Secrets.** The output shows every string in the app. In chat and in documents, show secret values only masked, as `RISKS.md` does. Never print a full password, key or token.
4. **Language.** Write the explanation in the user's standard writing style (for example ASD-STE100, if the user's preferences say so).

## Step 1. Find where to run

| Situation | What to do |
|---|---|
| Claude Code or the desktop Code tab (local shell) | Run `bash ${CLAUDE_SKILL_DIR}/scripts/decompile.sh <file> <out>` directly. |
| The file is in a connected folder on the user's computer, and you have a device shell (`device_bash`) | Copy this skill folder into that folder once, then run it there. See [references/run-on-device.md](references/run-on-device.md). |
| Chat with the file attached (cloud sandbox only) | Ask first: "The file will be decompiled in the cloud sandbox. OK?" Run only after a yes. |

Before the first run in a place, run `bash <skill>/scripts/decompile.sh --check`. It prints the Java and python3 that it will use.

## Step 2. Decompile

```bash
bash <skill>/scripts/decompile.sh <artifact.jar|war> <output-folder>
```

- The output folder must not exist. Use a name like `<app>-decompiled-<YYYYMMDD>` next to the artifact.
- It takes seconds for small apps and a few minutes for very large ones. If a tool call has a time limit, run it in the background and wait for `DECOMPILE-REPORT.txt` to show `Done.`.
- **Exit code 3** means that no Java was found and none could be downloaded. Follow [references/java-on-demand.md](references/java-on-demand.md). Any Java 8 or later is enough.
- The script deletes its temporary `_work/` folder at the end (`KEEP_WORK=1` keeps it).

Output: `pom.xml` (embedded original, if any), `pom-reconstructed.xml`, `DEPENDENCIES.md`, `INVENTORY.md`, `RISKS.md`, `DECOMPILE-REPORT.txt`, `src/main/java`, `src/main/resources`, `src/main/webapp` (WAR only), `_meta/` (manifest, git.properties, SBOM, JSON data, tool logs).

## Step 3. Read in this order

Do not read every class of a large app. Use the map first.

1. `DECOMPILE-REPORT.txt`: counts, layout, warnings.
2. `_meta/MANIFEST.MF`, `_meta/git.properties`, `_meta/build-info.properties`: start class, framework and Java versions, exact commit and build time.
3. `INVENTORY.md`: roles, packages, endpoints, wiring (fan-in), entities, listeners, scheduled jobs, outbound HTTP, config keys, XML beans.
4. `RISKS.md`: confirm each HIGH finding in the code. Remove false positives from your summary.
5. Config: `application*.properties|yml`, Spring XML, `web.xml`, and profile files. Find the active profile and the data source.
6. Code, by priority: the entry point and config classes, then the controllers, then the services with the highest fan-in, then the repositories and entities, then the cross-cutting classes (aspects, filters, interceptors, security).

## Step 4. Write COMPONENTS.md

Write `<out>/COMPONENTS.md` from [references/components-template.md](references/components-template.md). It must have:
- what the artifact is (table, each fact with its source file),
- one architecture view (text diagram),
- each component group with its role,
- risks and failure modes that you found in the code (not generic advice),
- what the decompile cannot show (see the template).

## Step 5. CVE check

`RISKS.md` part D has two layers: a built-in list of well-known bad versions (always runs), and an OSV query (needs internet).
- If OSV says `FAILED (no network?)`, the check was not done. Tell the user. Offer to run `python3 <skill>/scripts/risk_scan.py <out> --osv-only` where internet works (for example the desktop Code tab on a Mac). It updates `RISKS.md` in place.
- Libraries without a group ID (no SBOM, no pom.properties) are not in the OSV query. Say how many.

## Step 6. Report to the user

Keep it short:
- counts (classes, endpoints, entities, libraries with exact coordinates),
- the top risks (confirmed only, values masked),
- the CVE status,
- what is missing from the artifact (tests, comments, CI, deployment files, server-provided libraries, runtime config such as environment variables, JNDI, Kubernetes secrets),
- the paths of the output files.

## Known limits of the decompiled code

Behavior is the same as the source, but: comments and Javadoc are lost; text blocks become `\n` strings; constant names at the place of use become values; generic types of local variables can become raw; parameter names of interface methods become `var1`; Lombok annotations become plain code; Kotlin or Scala classes decompile to unusual Java; obfuscated code keeps meaningless names. Maven resource filtering can put real values (database URL, user, password) into the deployed config, where the source has `${...}`.
