#!/bin/bash
# lib.sh — shared functions for cc-bell hook scripts
# Source this from your hook script: source "$(dirname "$0")/lib.sh"

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
  [ "$TERM_PROGRAM" = "vscode" ] && echo "VS Code" && return
  echo "Terminal"
}

# --- Resolve IDE icon path ---
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

# --- Detect system language (macOS) ---
is_system_chinese() {
  local locale; locale=$(defaults read -g AppleLocale 2>/dev/null || echo "en-US")
  case "$locale" in zh*) return 0 ;; esac
  return 1
}

# --- Generate random status line (bilingual, with emoji) ---
random_status() {
  if is_system_chinese; then
    local titles=(
      "✅ 搞定了"
      "✨ 完工"
      "🎉 做好了"
      "🌟 任务完成"
      "🚀 搞定"
      "💪 完成了"
      "🎯 收工"
    )
    local subtitles=(
      "来看看吧"
      "去验收一下"
      "快来看看"
      "AI 喊你回来"
      "回来看看吧"
      "可以检查了"
      "等你来看"
    )
  else
    local titles=(
      "✅ Ready"
      "✨ Done"
      "🎉 All set"
      "🌟 Complete"
      "🚀 Finished"
      "💪 Wrapped up"
      "🎯 All done"
    )
    local subtitles=(
      "Come take a look"
      "Go check it out"
      "Come see what's new"
      "Your AI is ready"
      "Time to review"
      "Take a peek"
      "All finished up"
    )
  fi
  echo "${titles[$RANDOM % ${#titles[@]}]}|${subtitles[$RANDOM % ${#subtitles[@]}]}"
}
