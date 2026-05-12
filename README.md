# notify-tool

A lightweight macOS menu bar notification daemon for developer workflows.
Shows a floating panel with project notifications — click to open in your IDE.

```
Normal              Do Not Disturb
 🔔                  🔔̶
```

## Features

- **Floating panel** — appears bottom-right, shows project + IDE + status
- **Click to open** — any row opens the project in its IDE
- **Smart clearing** — opening one notification removes all earlier ones for the same project
- **Do Not Disturb** — suppresses panel and sounds, distinct icon
- **Sound alerts** — 14 macOS system sounds, pick from the menu
- **Badge count** — unread count next to the bell icon
- **Dark mode** — respects system appearance automatically

## Installation

```bash
git clone https://github.com/your-username/notify-tool.git
cd notify-tool
make install
```

This compiles the binary, copies it to `/usr/local/bin/notify-tool`, and
loads the LaunchAgent for auto-start on login.

### Requirements

- macOS 11 Big Sur or later
- Xcode Command Line Tools (`xcode-select --install`)

## Usage

### From scripts / CI

```bash
notify-tool \
  --project "my-app" \
  --ide "Cursor" \
  --icon "/Applications/Cursor.app/Contents/Resources/Cursor.icns" \
  --path "/Users/me/projects/my-app" \
  --line1 "Build passed" \
  --line2 "All 42 tests green"
```

Or use the included helper:

```bash
./scripts/notify.sh --project "my-app" --ide "Cursor" ...
```

### Arguments

| Argument     | Required | Default            | Description                          |
|--------------|----------|--------------------|--------------------------------------|
| `--project`  | yes      | `Unknown`          | Project name shown in the panel      |
| `--ide`      | no       | `Terminal`         | IDE identifier (Cursor, VS Code...)  |
| `--icon`     | no       | (none)             | Path to `.icns` for the IDE icon     |
| `--path`     | no       | (none)             | Project path — click to open in IDE  |
| `--line1`    | no       | `Task completed`   | First status line                    |
| `--line2`    | no       | `Come check it out`| Second status line                   |

### Menu bar controls

| Action                | Shortcut |
|-----------------------|----------|
| Toggle Do Not Disturb | `Cmd+D`  |
| Toggle Mute           | `Cmd+M`  |
| Quit                  | `Cmd+Q`  |

## Configuration

Data is stored in `~/.claude/` by default. Override with:

```bash
export NOTIFY_TOOL_HOME="$HOME/Library/Application Support/notify-tool"
```

## Claude Code Integration

If you use [Claude Code](https://claude.ai/code), add a Stop hook to
auto-notify when tasks finish:

1. Copy `scripts/claude-hook.sh` to `~/.claude/notify-done.sh`
2. Add to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "Stop": [{
      "hooks": [{
        "type": "command",
        "command": "~/.claude/notify-done.sh"
      }]
    }]
  }
}
```

## Supported IDEs

Cursor, VS Code, Trae, Qoder, iTerm2, Warp, Ghostty, Kitty, Alacritty,
WezTerm, Terminal — or any app name via the `--ide` argument.

## Uninstall

```bash
make uninstall
```

## Project structure

```
notify-tool/
├── notify-tool.swift       # Main program
├── Makefile                # Build, install, uninstall
├── com.notify-tool.plist   # LaunchAgent for auto-start
├── scripts/
│   ├── notify.sh           # CLI frontend
│   └── claude-hook.sh      # Claude Code integration example
├── README.md
├── LICENSE                 # MIT
└── CLAUDE.md               # Development conventions
```

## License

MIT
