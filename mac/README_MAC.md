# macOS (and Linux)

Bijalog is plain Python - the same `bijalog.py` runs unmodified. Only the
double-click wrappers differ per platform:

| Windows | macOS / Linux |
|---|---|
| `bijalog.bat` | `mac/bijalog.sh` |
| `bijalog_watch.bat` | `mac/bijalog_watch.command` |

One-time setup:

    cd mac
    chmod +x bijalog.sh bijalog_watch.command

First double-click of `bijalog_watch.command`: right-click > Open (it is
unsigned, so Gatekeeper asks once). If no Python is installed, macOS offers
the command-line tools when the script first calls `python3` - accept, done.

The wrappers follow the same rules as the `.bat` files:

- If `BIJALOG_ROOT` is set in your environment, that folder is used.
  Set it permanently with a line in `~/.zshrc`, e.g.
  `export BIJALOG_ROOT="$HOME/Bijalog/projects"` - this is the macOS
  equivalent of what `bijalog_setup.bat` does on Windows.
- Otherwise everything lives next to the scripts: `projects/` for the
  decks, and an `inbox/` folder beside it for the watcher.

There is no drive letter anywhere: on macOS, Google Drive for desktop
mounts under `~/Library/CloudStorage/GoogleDrive-<email>/My Drive`, and
if you want your decks there, point `BIJALOG_ROOT` at it.

Verified: the full cycle (add, approve, verify, state, versioned deck on
disk) runs identically on POSIX with zero changes to the Python. Tested on
Linux; a real Mac should behave the same but has not been tried yet - if
you run it on one, the PASS/FAIL verdicts are worth reporting either way.
