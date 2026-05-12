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
	@sudo cp $(BUILD_DIR)/$(BINARY) $(PREFIX)/$(BINARY) 2>/dev/null || true
	@# Fallback: copy to ~/.claude/ if sudo unavailable (e.g. CI, non-interactive)
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
	@sudo rm -f $(PREFIX)/$(BINARY) 2>/dev/null || true
	@rm -f $(HOME)/.claude/notify-done.sh
	@rm -f $(HOME)/.claude/lib.sh
	@rm -f $(HOME)/.claude/codex-hook.sh
	@echo "cc-bell uninstalled"

reinstall: uninstall install

clean:
	rm -rf $(BUILD_DIR)
