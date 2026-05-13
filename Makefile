VERSION := 1.0.0
BINARY  := cc-bell
PREFIX  := /usr/local/bin
PLIST   := com.cc-bell.plist
LAUNCH_AGENTS_DIR := $(HOME)/Library/LaunchAgents
BUILD_DIR := .build
SWIFT_FLAGS := -O

.PHONY: build install uninstall reinstall clean setup

build:
	@mkdir -p $(BUILD_DIR)
	swiftc $(SWIFT_FLAGS) -o $(BUILD_DIR)/$(BINARY) cc-bell.swift

install: build
	@bash scripts/setup.sh
	@echo ""
	@echo "==> Installing binary to /usr/local/bin/cc-bell..."
	@echo "    (sudo required — /usr/local/bin/ is system-wide, needs root permission)"
	@sudo cp $(BUILD_DIR)/$(BINARY) $(PREFIX)/$(BINARY)
	@# Fallback: copy to ~/.claude/ too (so hooks can find it even if /usr/local/bin/ is missing)
	@cp $(BUILD_DIR)/$(BINARY) $(HOME)/.claude/$(BINARY) 2>/dev/null || true
	@chmod +x $(HOME)/.claude/$(BINARY) 2>/dev/null || true
	@cp $(PLIST) $(LAUNCH_AGENTS_DIR)/$(PLIST)
	@launchctl unload $(LAUNCH_AGENTS_DIR)/$(PLIST) 2>/dev/null || true
	@launchctl load $(LAUNCH_AGENTS_DIR)/$(PLIST)
	@echo "cc-bell v$(VERSION) installed and configured"
	@echo "  binary: $(PREFIX)/$(BINARY)"
	@echo "  plist:  $(LAUNCH_AGENTS_DIR)/$(PLIST)"

setup:
	@bash scripts/setup.sh

uninstall:
	@launchctl unload $(LAUNCH_AGENTS_DIR)/$(PLIST) 2>/dev/null || true
	@rm -f $(LAUNCH_AGENTS_DIR)/$(PLIST)
	@# Try user-accessible paths first, then system-wide
	@rm -f $(HOME)/.claude/$(BINARY) 2>/dev/null || true
	@sudo rm -f $(PREFIX)/$(BINARY)
	@rm -f $(HOME)/.claude/notify-done.sh
	@rm -f $(HOME)/.claude/lib.sh
	@rm -f $(HOME)/.claude/codex-hook.sh
	@echo "cc-bell uninstalled"

reinstall: uninstall install

clean:
	rm -rf $(BUILD_DIR)
