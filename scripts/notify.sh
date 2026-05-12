#!/bin/bash
# notify.sh — CLI frontend for notify-tool
# Usage: ./scripts/notify.sh --project "my-app" --ide "Cursor" [options...]

set -euo pipefail

BINARY="${NOTIFY_TOOL_BINARY:-/usr/local/bin/notify-tool}"

if [ ! -x "$BINARY" ]; then
    echo "[notify.sh] notify-tool not found at $BINARY" >&2
    echo "[notify.sh] Set NOTIFY_TOOL_BINARY or run 'make install' first." >&2
    exit 1
fi

if [ "$#" -eq 0 ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Usage: $0 --project <name> [--ide <ide>] [--icon <path>] [--path <dir>] [--line1 <text>] [--line2 <text>]" >&2
    echo "" >&2
    echo "Run 'notify-tool --help' for full argument documentation." >&2
    exit 0
fi

exec "$BINARY" "$@"
