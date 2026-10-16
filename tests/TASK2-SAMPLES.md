# Java decompile test: samples and how to run the test

This guide tells you where the 2 test samples come from, how to make them on a different Mac (for example a MacBook Air M5), how to run the `decompile-java-artifact` test, and how to verify the result. Written in ASD-STE100.

## 1. The samples

The samples are open-source Spring PetClinic apps (Apache License 2.0). There is no direct download of the JAR or WAR. The script `tests/build-task2-samples.sh` gets the source from GitHub and builds the 2 files with Maven. The script uses fixed commits, so each Mac gets the same code.

| File | Type | Source repo | Commit |
|---|---|---|---|
| `deployed/petclinic-boot.jar` | Spring Boot executable ("fat") JAR (`BOOT-INF/`) | https://github.com/spring-projects/spring-petclinic | `500158f732419217507c7656904b8e6aa1bcc0d6` (2026-09-29) |
| `deployed/petclinic-mvc.war` | Classic Spring MVC WAR with JSP (`WEB-INF/`) | https://github.com/spring-petclinic/spring-framework-petclinic | `cf392920cdbe9cd07689f1f4b603271940bac957` (2026-10-05) |

The script also keeps the original source in `answer-key/`. Use it only to verify the result. Do not give it to Claude during the decompile test.

Default folder: `~/Downloads/WORKSPACE/SkillsPlugins/task2-samples/`. The `task2-samples/` folder is not in this repo (`.gitignore`), because it is large (about 115 MB).

Files on the Intel Mac (built 2026-10-15), for reference:

| File | Size | SHA-256 |
|---|---|---|
| `petclinic-boot.jar` | 66 MB | `f6962e35413512ec303676b244281a4d0fc5917b8712462cb733d674dfe3e420` |
| `petclinic-mvc.war` | 51 MB | `6dafcec3739636dca18c6b43008e93fe53a0cdcb117c652f8b4b183fc4ab1f02` |

A new build gives a different SHA-256, because Maven puts the build time in the files. This is correct. Use the counts in section 4 to compare.

## 2. Before you start (new Mac)

| Item | Requirement |
|---|---|
| git | `git --version` |
| JDK 17 or later | Only to build the samples. `/usr/libexec/java_home -V` shows the JDKs. If there is none, install Temurin 21 (Apple silicon `.pkg` from https://adoptium.net, or `brew install --cask temurin@21`). |
| python3 | `python3 --version`. The decompile skill and the verify script need it. |
| Network | GitHub and Maven Central (`repo.maven.apache.org`). |
| Time | 5 to 10 minutes for the first build. Each decompile: about 15 seconds. |

The decompile itself runs with any Java 8 or later. If there is no Java, the skill can download one (see `skills-src/decompile-java-artifact/references/java-on-demand.md`).

## 3. Steps

1. Get the repo:
   ```bash
   git clone https://github.com/Abhijit-17/claude-skills-plugins.git ~/Downloads/WORKSPACE/SkillsPlugins
   cd ~/Downloads/WORKSPACE/SkillsPlugins
   ```
   If you have it already: `cd ~/Downloads/WORKSPACE/SkillsPlugins && git pull`.
2. Build the samples. The target folder must not exist:
   ```bash
   bash tests/build-task2-samples.sh
   ```
   At the end, the script shows the 2 files and `answer-key/SOURCES.txt` with the 2 commits from section 1.
3. Decompile. Use one of these:
   - **With Claude** (full skill test): in Claude Desktop, connect the `SkillsPlugins` folder and ask: *"Decompile task2-samples/deployed/petclinic-boot.jar and task2-samples/deployed/petclinic-mvc.war with the decompile-java-artifact skill. Put the output in task2-samples/skill-test-YYYYMMDD/petclinic-boot and .../petclinic-mvc. Do not read answer-key/."*
   - **Only the scripts** (fast check of the tools):
     ```bash
     D=task2-samples/skill-test-$(date +%Y%m%d)
     mkdir -p "$D"
     bash skills-src/decompile-java-artifact/scripts/decompile.sh task2-samples/deployed/petclinic-boot.jar "$D/petclinic-boot"
     bash skills-src/decompile-java-artifact/scripts/decompile.sh task2-samples/deployed/petclinic-mvc.war  "$D/petclinic-mvc"
     ```
4. Verify:
   ```bash
   python3 tests/verify-task2-decompile.py task2-samples "$D"
   ```
   The last line must be `Result: ALL PASS`. The exit code is 0.
5. Optional, CVE check (needs internet):
   ```bash
   python3 skills-src/decompile-java-artifact/scripts/risk_scan.py "$D/petclinic-boot" --osv-only
   python3 skills-src/decompile-java-artifact/scripts/risk_scan.py "$D/petclinic-mvc"  --osv-only
   ```

## 4. Expected results

From the run on the Intel Mac on 2026-10-16 (skill build 2026-10-15.1, Java 11, CFR 0.152). The verify script showed `ALL PASS`.

| Item | petclinic-boot.jar | petclinic-mvc.war |
|---|---|---|
| Layout | `boot` | `war` |
| App classes | 30 (30 top-level) | 49 (47 top-level) |
| Java files, decompiled = source | 30 = 30 | 47 = 47 |
| Resources | 50 of 50 byte-identical, plus `git.properties` | 21 present, 18 byte-identical (see section 5) |
| Web files (JSP, CSS, images) | none | 40 of 40 byte-identical |
| HTTP endpoints (INVENTORY.md = source) | 17 | 18 |
| Entities | 6 | 6 |
| Library JARs (with exact coordinates) | 93 (92) | 64 (34) |
| Risks before the CVE check | HIGH 1, MEDIUM 2, LOW 0, INFO 2 | HIGH 0, MEDIUM 2, LOW 1, INFO 6 |
| JPA and Spring annotations (`@Entity`, `@Query`, `@Transactional`, ...) | same count as source | same count as source |

The risk counts can be higher after the CVE check (step 5), because the CVE check adds library findings.

## 5. Differences that are correct

- **3 config files in the WAR** (`spring/datasource-config.xml`, `spring/data-access.properties`, `spring/business-config.xml`): the source has `${jdbc.url}` and similar. The WAR has the real values (H2 in-memory database), because Maven resource filtering puts them in at build time. The decompile shows what is deployed.
- **`git.properties` in the JAR**: the build makes it. It is not in the source.
- **The HIGH risk in the JAR** (`management.endpoints.web.exposure.include=*`): this line is in the source too. It is a real finding.
- **The CFR warning on `CallMonitoringAspect`** ("Removed try catching itself"): the decompiled method has the same behavior as the source.
- Normal decompile limits: no comments, `this.` is added, ternary instead of `if`/`else`, `1L` instead of `1`, casts after generic calls. The behavior is the same.

## 6. If a check fails

| Symptom | What to do |
|---|---|
| `STOP: ... exists` from the build script | The samples are there already. Go to step 3, or move the folder away. |
| `cannot get commit ...` | Network, or the repo history changed. Use `JAR_COMMIT=HEAD WAR_COMMIT=HEAD bash tests/build-task2-samples.sh`. The counts in section 4 can then change. |
| Decompile exit code 3 | No Java found. See `skills-src/decompile-java-artifact/references/java-on-demand.md`. |
| `FAIL` in the verify script | Send the full output of the verify script and the `DECOMPILE-REPORT.txt` of that app. |
