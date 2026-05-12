#!/bin/bash
# setup.sh — Configure Claude Code hook for cc-bell
# Run after `make install`:  make setup  or  ./scripts/setup.sh

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
HOOK_SRC="$SCRIPT_DIR/claude-hook.sh"
LIB_SRC="$SCRIPT_DIR/lib.sh"
CODEX_SRC="$SCRIPT_DIR/codex-hook.sh"
SETTINGS="$HOME/.claude/settings.json"
HOOK_DST="$HOME/.claude/notify-done.sh"
LIB_DST="$HOME/.claude/lib.sh"
CODEX_DST="$HOME/.claude/codex-hook.sh"

echo "==> Installing hook scripts to ~/.claude/..."
cp "$HOOK_SRC" "$HOOK_DST"
chmod +x "$HOOK_DST"
cp "$LIB_SRC" "$LIB_DST"
chmod +x "$LIB_DST"
cp "$CODEX_SRC" "$CODEX_DST"
chmod +x "$CODEX_DST"
echo "    notify-done.sh installed"
echo "    codex-hook.sh installed"

echo "==> Configuring Claude Code Stop hook..."
mkdir -p "$HOME/.claude"

if [ -f "$SETTINGS" ]; then
  # Check if cc-bell hook is already configured
  if grep -q "notify-done.sh" "$SETTINGS" 2>/dev/null; then
    echo "    cc-bell hook already present in settings.json, skipping."
  else
    # Merge hook config into existing settings.json using Python
    python3 -c "
import json, sys
with open('$SETTINGS') as f:
    conf = json.load(f)
hooks = conf.setdefault('hooks', {})
stop = hooks.setdefault('Stop', [])
# Check if any existing Stop entry already has our hook
for entry in stop:
    for h in entry.get('hooks', []):
        if 'notify-done.sh' in h.get('command', ''):
            print('    cc-bell hook already present, skipping.')
            sys.exit(0)
stop.append({'hooks': [{'type': 'command', 'command': '~/.claude/notify-done.sh'}]})
with open('$SETTINGS', 'w') as f:
    json.dump(conf, f, indent=2)
print('    settings.json updated.')
"
  fi
else
  cat > "$SETTINGS" <<- JSONEOF
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/notify-done.sh"
          }
        ]
      }
    ]
  }
}
JSONEOF
  echo "    settings.json created."
fi

echo ""
echo "Done! cc-bell will now notify you when Claude Code finishes a task."
echo ""
echo "For Codex CLI integration, add to ~/.codex/config.toml:"
echo '  notify = ["~/.claude/codex-hook.sh", "turn-ended"]'
