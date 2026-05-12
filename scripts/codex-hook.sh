#!/bin/bash
# codex-hook.sh — Codex CLI integration for cc-bell
#
# Configure in ~/.codex/config.toml:
#   notify = ["/path/to/codex-hook.sh", "turn-ended"]
#
# Or inline without a wrapper script (single-line version):
#   notify = ["/usr/local/bin/cc-bell", "--project", "$(basename \"$PWD\")", "--line1", "Task completed", "turn-ended"]
#
# Note: Inline $(basename "$PWD") expansion depends on your shell.
# The wrapper script is more reliable.

PROJECT=$(basename "$PWD")
BINARY="${NOTIFY_TOOL_BINARY:-/usr/local/bin/cc-bell}"

if [ ! -x "$BINARY" ]; then
  echo "[codex-hook.sh] cc-bell not found at $BINARY" >&2
  exit 0  # soft exit — don't break Codex
fi

# Detect IDE from parent process tree (Codex runs via terminal)
detect_ide() {
  local pid=$$ max=30
  while [ $max -gt 0 ] && [ "$pid" != "1" ] && [ -n "$pid" ]; do
    local cmd; cmd=$(ps -o command= -p "$pid" 2>/dev/null | head -1)
    [ -z "$cmd" ] && break
    local exe="${cmd%% *}"; exe="${exe##*/}"
    case "$exe" in bash|zsh|sh|dash|fish|nu)
      pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' '); max=$((max - 1)); continue ;;
    esac
    case "$cmd" in
      *"Cursor.app"*)                echo "Cursor";    return ;;
      *"Visual Studio Code"*|*"Code.app"*) echo "VS Code";  return ;;
      *iTerm*)                       echo "iTerm2";   return ;;
      *Apple_Terminal*)              echo "Terminal"; return ;;
      *Warp*)                        echo "Warp";      return ;;
      *Ghostty*)                     echo "Ghostty";   return ;;
    esac
    pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' '); max=$((max - 1))
  done
  echo "Terminal"
}

IDE=$(detect_ide)

# Status messages
TITLES=("Completed" "Done" "Finished" "Ready" "All set" "Wrapped up")
SUBTITLES=("Take a look" "Check it out" "Come see" "Ready for review" "All done here")
HL=${TITLES[$RANDOM % ${#TITLES[@]}]}
SF=${SUBTITLES[$RANDOM % ${#SUBTITLES[@]}]}

"$BINARY" \
  --project "$PROJECT" \
  --ide "$IDE" \
  --path "$PWD" \
  --line1 "$HL" \
  --line2 "$SF"
