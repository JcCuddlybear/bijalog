#!/bin/sh
# bijalog.sh - macOS/Linux twin of bijalog.bat: find a Python, pass everything through.
# One-time on Mac: chmod +x bijalog.sh   (and right-click > Open the first time,
# because it is unsigned and Gatekeeper will ask.)
cd "$(dirname "$0")" || exit 1
# bijalog.py may sit beside this wrapper, or one level up (repo root)
BJ="./bijalog.py"; [ -f "$BJ" ] || BJ="../bijalog.py"
[ -f "$BJ" ] || { echo "bijalog.py not found next to or above this wrapper"; exit 1; }
if command -v python3 >/dev/null 2>&1; then exec python3 "$BJ" "$@"; fi
if command -v python  >/dev/null 2>&1; then exec python  "$BJ" "$@"; fi
echo "No Python found. On macOS run: xcode-select --install   (or install from python.org)"
exit 1
