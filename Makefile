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
	@sed "s|__HOME__|$(HOME)|g" $(PLIST) > $(LAUNCH_AGENTS_DIR)/$(PLIST)
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
	@rm -f $(HOME)/.claude/$(BINARY)
	@rm -f $(HOME)/.claude/notify-done.sh
	@rm -f $(HOME)/.claude/lib.sh
	@rm -f $(HOME)/.claude/codex-hook.sh
	@rm -f $(HOME)/.claude/notify-pending.json
	@rm -f $(HOME)/.claude/notify-pending.lock
	@rm -f $(HOME)/.claude/notify-daemon.pid
	@rm -f $(HOME)/.claude/notify-sound
	@rm -f $(HOME)/.claude/notify-muted
	@rm -f $(HOME)/.claude/notify-dnd
	@# System-wide binary — needs sudo, do last so everything else is already cleaned up
	@sudo rm -f $(PREFIX)/$(BINARY) 2>/dev/null; \
	  if [ $$? -ne 0 ]; then \
	    echo "  (skipped /usr/local/bin/cc-bell — re-run with sudo or delete manually)"; \
	  fi
	@echo "cc-bell uninstalled"

reinstall: uninstall install

clean:
	rm -rf $(BUILD_DIR)
