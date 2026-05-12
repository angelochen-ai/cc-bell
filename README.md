# CC Bell

> **Coding Companion Bell** — a macOS menu bar notification daemon for AI coding assistants.

When your AI assistant finishes a task, CC Bell pops a floating panel in
the corner of your screen — showing the project name, IDE, and status. Click
any notification to jump straight to the project.

```
Normal              Do Not Disturb
 🔔                  🔔̶
```

## Features

- **Floating panel** — bottom-right, shows project + IDE + status at a glance
- **Click to open** — any row opens the project in its IDE
- **Smart clearing** — opening one notification removes older ones for the same project
- **Do Not Disturb** — suppresses panel and sounds, distinct icon
- **Sound alerts** — 14 macOS system sounds, pick from the menu
- **Badge count** — unread count next to the bell icon
- **Dark mode** — respects system appearance automatically

## Integrations

CC Bell works with any AI coding tool that can run a shell command.
Pre-built integrations:

| AI Tool | Event | Setup |
|---------|-------|-------|
| [Claude Code](https://claude.ai/code) | Stop hook (task complete) | [Guide](#claude-code-integration) |
| [Codex CLI](https://github.com/openai/codex) | notify turn-ended | [Guide](#codex-cli-integration) |
| Any CLI / CI | Script or pipe | [Guide](#from-scripts--ci) |

## Installation

```bash
git clone https://github.com/an3397016259-debug/cc-bell.git
cd cc-bell
make install
```

This compiles the binary, copies it to `/usr/local/bin/cc-bell`, and
loads the LaunchAgent for auto-start on login.

### Requirements

- macOS 11 Big Sur or later
- Xcode Command Line Tools (`xcode-select --install`)

## Usage

### From scripts / CI

```bash
cc-bell \
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
export NOTIFY_TOOL_HOME="$HOME/Library/Application Support/cc-bell"
```

## Claude Code Integration

Add a Stop hook to auto-notify when Claude Code finishes a task:

1. Copy the hook script:

```bash
cp scripts/claude-hook.sh ~/.claude/notify-done.sh
```

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

## Codex CLI Integration

Configure the `notify` setting in `~/.codex/config.toml`:

```toml
notify = ["/path/to/cc-bell/scripts/codex-hook.sh", "turn-ended"]
```

Or inline without the wrapper:

```toml
notify = ["/usr/local/bin/cc-bell", "--project", "my-project", "--line1", "Done", "turn-ended"]
```

The array must end with `"turn-ended"` — everything before it is the
command and its arguments.

## Supported IDEs

Cursor, VS Code, Trae, Qoder, iTerm2, Warp, Ghostty, Kitty, Alacritty,
WezTerm, Terminal — or any app name via the `--ide` argument.

## Uninstall

```bash
make uninstall
```

## Project structure

```
cc-bell/
├── cc-bell.swift           # Main program
├── Makefile                # Build, install, uninstall
├── com.cc-bell.plist       # LaunchAgent for auto-start
├── scripts/
│   ├── notify.sh           # CLI frontend
│   ├── claude-hook.sh      # Claude Code integration example
│   └── codex-hook.sh       # Codex CLI integration example
├── README.md
├── LICENSE                 # MIT
└── CLAUDE.md               # Development conventions
```

## License

MIT
