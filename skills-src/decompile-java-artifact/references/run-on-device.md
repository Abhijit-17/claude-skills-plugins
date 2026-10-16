# Run on the user's computer from a cloud or desktop session

Use this when the JAR or WAR is in a connected folder on the user's computer and you have a device shell (`device_bash`), but this skill's files are where you are (for example a cloud sandbox).

## 1. Copy the skill into the folder once

Target: `<connected-folder>/.decompile-java-artifact/` (scripts/, tools/).

1. Check if it is there and current:
   `grep -m1 'build ' <connected-folder>/.decompile-java-artifact/scripts/decompile.sh`
   If it shows the same build as this SKILL.md, go to step 2.
2. Copy these files to a staging path that your file-copy tool accepts (for example `/mnt/user-data/outputs/dja/...`), then copy them to the computer (for example `device_commit_files`):
   - `scripts/decompile.sh`, `scripts/deps.py`, `scripts/inventory.py`, `scripts/risk_scan.py`
   - `tools/cfr-0.152.jar` (2 MB)
3. Do not edit a staged file and copy it in the same step: run the edit first, wait for the result, then copy. If a copy seems stale, use a new staging file name.
4. Verify on the computer: `sha256sum .decompile-java-artifact/tools/cfr-0.152.jar` must be
   `f686e8f3ded377d7bc87d216a90e9e9512df4156e75b06c655a16648ae8765b2`.

## 2. Run

```bash
cd "$HOME/mnt/<folder>"
bash .decompile-java-artifact/scripts/decompile.sh --check
bash .decompile-java-artifact/scripts/decompile.sh path/to/app.war app-decompiled-YYYYMMDD
```

Notes for the desktop Linux VM:
- It usually has no internet. The JRE download and the OSV query fail fast and safely.
- A background process can stop when the shell call ends. Run in the foreground. A shell call can last up to about 3 minutes; that is enough for most apps.
- `rm` can be off. The script needs to delete only its own `_work/` folder. If that fails, ask the user for delete permission on the folder, or leave `_work/` and tell the user.

## 3. Read and write

Read the output with the device shell (`cat`, `grep`, `sed -n`). Write `COMPONENTS.md` with the device shell too (for example a `python3` script or a heredoc), so the file stays on the computer.
