VERSION := 1.0.0
BINARY  := notify-tool
PREFIX  := /usr/local/bin
PLIST   := com.notify-tool.plist
LAUNCH_AGENTS_DIR := $(HOME)/Library/LaunchAgents
BUILD_DIR := .build
SWIFT_FLAGS := -O

.PHONY: build install uninstall reinstall clean

build:
	@mkdir -p $(BUILD_DIR)
	swiftc $(SWIFT_FLAGS) -o $(BUILD_DIR)/$(BINARY) notify-tool.swift

install: build
	@cp $(BUILD_DIR)/$(BINARY) $(PREFIX)/$(BINARY)
	@cp $(PLIST) $(LAUNCH_AGENTS_DIR)/$(PLIST)
	@launchctl unload $(LAUNCH_AGENTS_DIR)/$(PLIST) 2>/dev/null || true
	@launchctl load $(LAUNCH_AGENTS_DIR)/$(PLIST)
	@echo "notify-tool v$(VERSION) installed"
	@echo "  binary: $(PREFIX)/$(BINARY)"
	@echo "  plist:  $(LAUNCH_AGENTS_DIR)/$(PLIST)"

uninstall:
	@launchctl unload $(LAUNCH_AGENTS_DIR)/$(PLIST) 2>/dev/null || true
	@rm -f $(LAUNCH_AGENTS_DIR)/$(PLIST)
	@rm -f $(PREFIX)/$(BINARY)
	@rm -rf $(HOME)/Library/Application Support/com.notify-tool
	@echo "notify-tool uninstalled"

reinstall: uninstall install

clean:
	rm -rf $(BUILD_DIR)
