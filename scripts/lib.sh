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

# --- Generate random status line (bilingual, programming-themed) ---
random_status() {
  if is_system_chinese; then
    local titles=(
      "🎉 本 AI 已下班"
      "✨ 你的专属码农上线了"
      "🏁 代码跑完了"
      "🔥 烧完了"
      "🎯 一击命中"
      "🥳 它好了你来了"
      "🛸 外星信号已处理"
      "🤖 AI 任务完成"
      "💻 代码已就绪"
      "⌨️ 键盘歇了"
      "📟 终端在召唤"
      "🧪 测试全绿了"
      "🏗️ 构建通过了"
      "📋 待办清零了"
      "⚡️ 任务已刷完"
      "📡 信号已解码"
      "🔌 AI 断线了"
      "🗑️ 垃圾已回收"
      "🔄 PR 等你来"
      "🧹 代码扫完了"
    )
    local subtitles=(
      "快来验收！"
      "回来看结果吧"
      "去终端看看吧"
      "去灭一下火"
      "这把稳了"
      "等你很久了"
      "回来解码吧"
      "请检阅成果"
      "趁热 review"
      "该你上场了"
      "快去接听"
      "一个都没挂"
      "去看看效果"
      "全部搞定"
      "回来看看吧"
      "请查收结果"
      "交还控制权"
      "内存干干净净"
      "帮忙 review 一下"
      "干净又卫生"
    )
  else
    local titles=(
      "🎉 Your AI clocked out"
      "✨ Your coder is ready"
      "🏁 Done and dusted"
      "🔥 Fired and finished"
      "🎯 Bullseye"
      "🥳 It's ready, you're up"
      "🛸 Alien signal processed"
      "🤖 Task complete"
      "💻 Code's ready"
      "⌨️ Keyboard's quiet"
      "📟 Terminal's calling"
      "🧪 Tests all green"
      "🏗️ Build passed"
      "📋 All done"
      "⚡️ Execution complete"
      "📡 Signal decoded"
      "🔌 AI disconnected"
      "🗑️ GC done"
      "🔄 PR is up"
      "🧹 Code cleaned up"
    )
    local subtitles=(
      "Come check the magic"
      "Go see what it made"
      "Dust it off and review"
      "Go put it out"
      "Right on target"
      "Been waiting for you"
      "Come decode the results"
      "AI is signing off"
      "Fresh off the keyboard"
      "Your turn to type"
      "Better answer it"
      "Not a single red"
      "Go see the build"
      "Nothing left on the list"
      "Output is waiting"
      "Message received"
      "You're back in control"
      "Memory's fresh again"
      "Come review the diff"
      "Squeaky clean"
    )
  fi
  echo "${titles[$RANDOM % ${#titles[@]}]}|${subtitles[$RANDOM % ${#subtitles[@]}]}"
}
