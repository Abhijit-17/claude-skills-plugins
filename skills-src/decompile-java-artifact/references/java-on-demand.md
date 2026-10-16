# Java on demand

CFR is compiled for Java 6, so any Java 8 or later runs it. It also decompiles class files from newer Java versions (tested: Java 17 bytecode on a Java 11 runtime).

## How the script finds Java (in this order)

1. `DJA_JAVA`, then `JAVA_HOME`, then `java` on the PATH (only if it really runs: the macOS `/usr/bin/java` stub without a JDK does not count).
2. macOS: `/usr/libexec/java_home`, Homebrew `openjdk*` (`/opt/homebrew/opt`, `/usr/local/opt`).
3. A JRE already unpacked in `<skill>/cache/jre/`.
4. A JRE archive (`*.tar.gz`, for this OS and CPU) in `<skill>/jre/` or `<skill>/cache/`. The script unpacks it.
5. Download: Temurin 21 JRE from `api.adoptium.net` into `<skill>/cache/` (about 50 MB). No admin rights, no system change. `DJA_NO_DOWNLOAD=1` turns this off.
6. Exit code 3 with the message `NEED_JRE <os-arch>`.

## When you get exit code 3

| Where | Fix |
|---|---|
| Mac, desktop Code tab or Terminal | `brew install openjdk@21` (no sudo), or let the script download (check that `api.adoptium.net` is reachable), then run again. |
| Desktop Linux VM (no internet) | The VM needs a **Linux** JRE. A Mac JRE does not run there. Get one with A or B, below. |
| Cloud sandbox | Use its JDK. If there is none, the network policy decides; do not route around a block. |

A. On the Mac (desktop Code tab or Terminal, with internet), download a Linux JRE into the connected folder:
```bash
bash <folder>/.decompile-java-artifact/scripts/decompile.sh --fetch-jre linux-x64 <folder>/.decompile-java-artifact/jre
```
(Use `linux-aarch64` if `uname -m` in the VM says `aarch64`.)

B. Ask the user to download the Temurin 21 **JRE** for **Linux x64** (`.tar.gz`) from https://adoptium.net/temurin/releases/?package=jre and save it in `<folder>/.decompile-java-artifact/jre/`.

Then run the decompile again. The script unpacks the archive into `cache/` and uses it from then on.

## Do not

- Do not install Java with `sudo`, `apt`, or a system installer.
- Do not use a JDK from an unknown site. Use Temurin (Adoptium) or Homebrew.
