#!/bin/bash
# codex-hook.sh — Codex CLI integration for cc-bell
# Auto-installed by `make install`. See README for details.
#
# Configure in ~/.codex/config.toml:
#   notify = ["~/.claude/codex-hook.sh", "turn-ended"]

set -euo pipefail

# Locate lib.sh in the same directory as this script
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
[ -f "$SCRIPT_DIR/lib.sh" ] && source "$SCRIPT_DIR/lib.sh"

BINARY="${NOTIFY_TOOL_BINARY:-/usr/local/bin/cc-bell}"
[ ! -x "$BINARY" ] && BINARY="$HOME/.claude/cc-bell"
[ ! -x "$BINARY" ] && exit 0

PROJECT=$(basename "$PWD")
IDE=${IDE:-$(detect_ide)}

IFS='|' read -r HL SF <<< "$(random_status)"

exec "$BINARY" \
  --project "$PROJECT" \
  --ide "$IDE" \
  --path "$PWD" \
  --line1 "$HL" \
  --line2 "$SF"
