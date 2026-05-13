# CC Bell

> **Coding Companion Bell** — macOS menu bar notifications for AI coding assistants.

When your AI assistant finishes a task, CC Bell pops a floating panel in
the corner of your screen — showing the project name, IDE, and status. Click
a notification to jump straight to the project.

```
Normal              Do Not Disturb
 🔔                  🔔̶
```

## Quick Start

```bash
git clone https://github.com/an3397016259-debug/cc-bell.git
cd cc-bell
make install
```

That's one command. It compiles the binary, installs it to `/usr/local/bin/cc-bell`,
starts the daemon in your menu bar, and configures Claude Code to
automatically notify you when a task finishes.

You'll be prompted for your **macOS password** — this is needed to install
the binary to `/usr/local/bin/` so you can run `cc-bell` from anywhere in
your terminal. Everything else (daemon, hooks, autostart) runs as your user.

The daemon starts automatically at login. From now on, when your
AI assistant finishes a task, you'll see a notification.

## Features

- **Floating panel** — bottom-right, shows project + IDE + status at a glance
- **Click to open** — any row opens the project in its IDE
- **Smart clearing** — opening one notification removes older ones for the same project
- **Do Not Disturb** — suppresses panel and sounds, distinct icon
- **Sound alerts** — 14 macOS system sounds, pick from the menu
- **Badge count** — unread count next to the bell icon
- **Dark mode** — respects system appearance automatically

## Installation

Requirements: macOS 11 Big Sur or later, Xcode Command Line Tools
(`xcode-select --install`).

```bash
make install
```

### Codex CLI Integration

Add to `~/.codex/config.toml`:

```toml
notify = ["~/.claude/codex-hook.sh", "turn-ended"]
```

The hook script is already installed by `make install`.

## Usage

### From scripts / CI

```bash
cc-bell \
  --project "my-app" \
  --ide "Cursor" \
  --path "/Users/me/projects/my-app" \
  --line1 "Build passed" \
  --line2 "All 42 tests green"
```

Or use the helper script:

```bash
~/.claude/notify-done.sh
```

### Arguments

| Argument     | Required | Default            | Description                          |
|--------------|----------|--------------------|--------------------------------------|
| `--project`  | no       | `Unknown`          | Project name shown in the panel      |
| `--ide`      | no       | `Terminal`         | IDE identifier (Cursor, VS Code...)  |
| `--icon`     | no       | (auto-detected)    | Path to `.icns` for the IDE icon     |
| `--path`     | no       | (none)             | Project path — click to open in IDE  |
| `--line1`    | no       | `Task completed`   | First status line                    |
| `--line2`    | no       | `Come check it out`| Second status line                   |

Only `--project` is really needed — everything else has sensible defaults.
The hook scripts auto-detect IDE, icon, and project name.

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

Environment variables for hook scripts:

| Variable             | Default                  | Description                     |
|----------------------|--------------------------|---------------------------------|
| `NOTIFY_TOOL_BINARY` | `/usr/local/bin/cc-bell` | Path to cc-bell binary          |
| `NOTIFY_TOOL_HOME`   | `~/.claude/`             | Data directory for notifications|

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
│   ├── lib.sh              # Shared functions (IDE detection, icons)
│   ├── setup.sh            # One-shot Claude Code integration
│   ├── claude-hook.sh      # Claude Code hook (installed by make install)
│   ├── codex-hook.sh       # Codex CLI hook (installed by make install)
│   └── notify.sh           # CLI frontend
├── README.md               # This file
├── LICENSE                 # MIT
└── CLAUDE.md               # Development conventions
```

## License

MIT
