#!/bin/sh
# bijalog_watch.command - double-clickable watcher for macOS (works on Linux too).
# Same rules as bijalog_watch.bat: uses $BIJALOG_ROOT if set, otherwise
# ./projects next to the scripts. The inbox lives beside the root's parent
# folder, e.g. root ~/Bijalog/projects -> inbox ~/Bijalog/inbox.
cd "$(dirname "$0")" || exit 1
[ -n "$BIJALOG_ROOT" ] || BIJALOG_ROOT="$(pwd)/projects"
mkdir -p "$BIJALOG_ROOT"
BIJALOG_HOME="$(cd "$BIJALOG_ROOT/.." && pwd)"
mkdir -p "$BIJALOG_HOME/inbox"
echo "root:  $BIJALOG_ROOT"
echo "inbox: $BIJALOG_HOME/inbox"
exec sh ./bijalog.sh --root "$BIJALOG_ROOT" watch --inbox "$BIJALOG_HOME/inbox"
