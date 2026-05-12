#!/bin/bash
# claude-hook.sh — Claude Code Stop hook for cc-bell
# Install: link or copy to ~/.claude/notify-done.sh, then add to
#   ~/.claude/settings.json as a Stop hook.
#
# Settings snippet:
#   "hooks": {
#     "Stop": [{ "hooks": [{ "type": "command", "command": "~/.claude/notify-done.sh" }] }]
#   }

PROJECT=$(basename "$PWD")
BINARY="${NOTIFY_TOOL_BINARY:-/usr/local/bin/cc-bell}"

# Use ~/.claude/ binary as fallback (legacy install)
if [ ! -x "$BINARY" ]; then
  BINARY="$HOME/.claude/cc-bell"
fi

[ ! -x "$BINARY" ] && exit 0

# --- Skip compaction-triggered Stop events ---
if [ -f "$HOME/.claude/.is-compacting" ]; then
  rm -f "$HOME/.claude/.is-compacting"
  exit 0
fi

# --- Detect IDE from parent process tree ---
detect_ide() {
  local pid=$$ max=30
  while [ $max -gt 0 ] && [ "$pid" != "1" ] && [ -n "$pid" ]; do
    local cmd; cmd=$(ps -o command= -p "$pid" 2>/dev/null | head -1)
    [ -z "$cmd" ] && break
    local exe="${cmd%% *}"; exe="${exe##*/}"
    case "$exe" in bash|zsh|sh|dash|fish|nu|claude|node)
      pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' '); max=$((max - 1)); continue ;;
    esac
    case "$cmd" in
      *"Cursor.app"*)                echo "Cursor";    return ;;
      *"Trae.app"*)                  echo "Trae";      return ;;
      *"Qoder.app"*)                 echo "Qoder";     return ;;
      *"Visual Studio Code"*|*"Code.app"*) echo "VS Code";  return ;;
      *iTerm*)                       echo "iTerm2";   return ;;
      *Apple_Terminal*)              echo "Terminal"; return ;;
      *Warp*)                        echo "Warp";      return ;;
      *Ghostty*)                     echo "Ghostty";   return ;;
      *kitty*)                       echo "Kitty";     return ;;
      *Alacritty*)                   echo "Alacritty"; return ;;
      *WezTerm*)                     echo "WezTerm";   return ;;
    esac
    pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' '); max=$((max - 1))
  done
  echo "$GIT_ASKPASS" | grep -qi "cursor" && echo "Cursor" && return
  echo "$GIT_ASKPASS" | grep -qi "trae"   && echo "Trae"   && return
  echo "$GIT_ASKPASS" | grep -qi "qoder"  && echo "Qoder"  && return
  [ "$TERM_PROGRAM" = "vscode" ] && echo "VS Code" && return
  echo "Terminal"
}

# --- Resolve IDE icon ---
find_app_icon() {
  local app_name="$1"; local icon_name="${2:-AppIcon}"
  local app_path; app_path=$(mdfind "kMDItemFSName == '${app_name}.app'" 2>/dev/null | head -1)
  [ -z "$app_path" ] && app_path="/Applications/${app_name}.app"
  [ ! -d "$app_path" ] && return 1
  for name in "${icon_name}" "AppIcon" "${app_name}"; do
    local ico="$app_path/Contents/Resources/${name}.icns"
    [ -f "$ico" ] && echo "$ico" && return 0
  done
  local any; any=$(find "$app_path/Contents/Resources" -name "*.icns" -maxdepth 1 2>/dev/null | head -1)
  [ -n "$any" ] && echo "$any" && return 0
  return 1
}

get_icon() {
  case "$1" in
    Cursor) echo "/Applications/Cursor.app/Contents/Resources/Cursor.icns" ;;
    Trae)   find_app_icon "Trae" "Trae" || true ;;
    Qoder)  find_app_icon "Qoder" "Qoder" || true ;;
    "VS Code") find_app_icon "Visual Studio Code" "Code" || true ;;
    iTerm2) find_app_icon "iTerm" "AppIcon" || true ;;
    Terminal) echo "/System/Applications/Utilities/Terminal.app/Contents/Resources/AppIcon.icns" ;;
    Warp)   find_app_icon "Warp" "AppIcon" || true ;;
    Kitty)  find_app_icon "Kitty" "AppIcon" || true ;;
    *)      echo "" ;;
  esac
}

# --- Skip if in a meeting ---
case "$(/usr/bin/osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true' 2>/dev/null)" in
  *[Zz]oom*|*[Tt]eams*|*[Ff]ace[Tt]ime*|*[Kk]eynote*|*[Pp]ower[Pp]oint*) exit 0 ;;
esac

IDE=$(detect_ide)
ICON=$(get_icon "$IDE")

# Status messages
TITLES=("Completed" "Done" "Finished" "Ready" "All set" "Wrapped up")
SUBTITLES=("Take a look" "Check it out" "Come see" "Ready for review" "All done here")
HL=${TITLES[$RANDOM % ${#TITLES[@]}]}
SF=${SUBTITLES[$RANDOM % ${#SUBTITLES[@]}]}

"$BINARY" \
  --project "$PROJECT" \
  --ide "$IDE" \
  --icon "$ICON" \
  --path "$PWD" \
  --line1 "$HL" \
  --line2 "$SF"
