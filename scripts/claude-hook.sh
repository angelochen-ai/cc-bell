#!/bin/bash
# notify-done.sh — Claude Code Stop hook for cc-bell
# Auto-installed by `make install`. See README for details.

set -euo pipefail

# Locate lib.sh in the same directory as this script
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
[ -f "$SCRIPT_DIR/lib.sh" ] && source "$SCRIPT_DIR/lib.sh"

BINARY="${NOTIFY_TOOL_BINARY:-/usr/local/bin/cc-bell}"
# Fallback to ~/.claude/cc-bell (installed when sudo unavailable)
[ ! -x "$BINARY" ] && BINARY="$HOME/.claude/cc-bell"
[ ! -x "$BINARY" ] && exit 0

# Skip compaction-triggered Stop events
if [ -f "$HOME/.claude/.is-compacting" ]; then
  rm -f "$HOME/.claude/.is-compacting"
  exit 0
fi

PROJECT=$(basename "$PWD")
IDE=${IDE:-$(detect_ide)}
ICON=${ICON:-$(get_icon "$IDE")}

IFS='|' read -r HL SF <<< "$(random_status)"

exec "$BINARY" \
  --project "$PROJECT" \
  --ide "$IDE" \
  --icon "$ICON" \
  --path "$PWD" \
  --line1 "$HL" \
  --line2 "$SF"
