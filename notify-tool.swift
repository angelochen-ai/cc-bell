import Cocoa

// MARK: - Version

let toolVersion = "1.0.0"

// MARK: - Localization

func loc(_ key: String) -> String {
    let isCN = NSLocale.current.language.languageCode?.identifier.hasPrefix("zh") ?? false
    switch key {
    case "Dismiss All":    return isCN ? "全部清除" : "Dismiss All"
    case "Dismiss all notifications": return isCN ? "清除所有通知" : "Dismiss all notifications"
    case "Notification Center": return isCN ? "通知中心" : "Notification Center"
    case "Do Not Disturb":    return isCN ? "勿扰模式" : "Do Not Disturb"
    case "Sound":             return isCN ? "音效" : "Sound"
    case "Mute":              return isCN ? "静音" : "Mute"
    case "Unmute":            return isCN ? "取消静音" : "Unmute"
    case "Quit":              return isCN ? "退出" : "Quit"
    default:                  return key
    }
}

// MARK: - Error logging

func logErr(_ msg: String) {
    fputs("notify-tool: \(msg)\n", stderr)
}

// MARK: - Models

struct NotificationItem: Codable, Equatable {
    let project: String
    let ide: String
    let icon: String
    let path: String?
    let line1: String
    let line2: String
}

// MARK: - Main daemon

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var panel: NSPanel?
    var items: [NotificationItem] = []
    var fileWatcher: DispatchSourceFileSystemObject?
    var statusItem: NSStatusItem?

    let soundNames = ["Basso", "Blow", "Bottle", "Frog", "Funk", "Glass",
                      "Hero", "Morse", "Ping", "Pop", "Purr",
                      "Sosumi", "Submarine", "Tink"]
    let baseDir: String
    let pendingPath: String
    let lockPath: String
    let daemonPidPath: String
    let soundPrefPath: String
    let mutedPrefPath: String
    let dndPrefPath: String

    let winW: CGFloat = 420
    let itemH: CGFloat = 80
    let pad: CGFloat = 18
    let iconS: CGFloat = 48
    let btnArea: CGFloat = 40

    override init() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let envBase = ProcessInfo.processInfo.environment["NOTIFY_TOOL_HOME"]
        baseDir = envBase ?? "\(home)/.claude"
        pendingPath = "\(baseDir)/notify-pending.json"
        lockPath = "\(baseDir)/notify-pending.lock"
        daemonPidPath = "\(baseDir)/notify-daemon.pid"
        soundPrefPath = "\(baseDir)/notify-sound"
        mutedPrefPath = "\(baseDir)/notify-muted"
        dndPrefPath = "\(baseDir)/notify-dnd"
        super.init()
        ensureBaseDir()
    }

    /// Create base directory if it doesn't exist
    func ensureBaseDir() {
        var isDir: ObjCBool = false
        if !FileManager.default.fileExists(atPath: baseDir, isDirectory: &isDir) {
            do {
                try FileManager.default.createDirectory(atPath: baseDir, withIntermediateDirectories: true)
            } catch {
                logErr("failed to create base directory \(baseDir): \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        let myPID = ProcessInfo.processInfo.processIdentifier

        // Bail if another daemon is already running
        if let oldStr = try? String(contentsOfFile: daemonPidPath, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines),
           let oldPID = Int32(oldStr), kill(oldPID, 0) == 0 {
            logErr("another daemon is already running (PID \(oldPID)), exiting")
            NSApplication.shared.terminate(nil)
            return
        }
        try? String(myPID).write(toFile: daemonPidPath, atomically: true, encoding: .utf8)

        reloadItems()
        // Defer panel creation to allow NSScreen.main to become available
        // (accessory app launch race)
        if !items.isEmpty, !readDND() {
            DispatchQueue.main.async { [weak self] in self?.showPanel() }
        }
        startWatching()
        setupMenuBar()

        NotificationCenter.default.addObserver(
            self, selector: #selector(screenChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        try? FileManager.default.removeItem(atPath: daemonPidPath)
    }

    // MARK: - File operations (with flock)

    /// Read items from disk under an exclusive lock
    func reloadItems() {
        let fd = open(lockPath, O_CREAT | O_RDWR, 0o644)
        guard fd >= 0 else { logErr("reloadItems: open lock failed"); items = []; return }
        flock(fd, LOCK_EX)
        defer { flock(fd, LOCK_UN); close(fd) }

        guard let data = try? Data(contentsOf: URL(fileURLWithPath: pendingPath)),
              let decoded = try? JSONDecoder().decode([NotificationItem].self, from: data)
        else { items = []; return }
        items = decoded
    }

    /// Write empty array to disk
    func clearItems() {
        let fd = open(lockPath, O_CREAT | O_RDWR, 0o644)
        guard fd >= 0 else { logErr("clearItems: open lock failed"); return }
        flock(fd, LOCK_EX)
        try? "[]".write(toFile: pendingPath, atomically: true, encoding: .utf8)
        items = []
        updateStatusBadge()
        flock(fd, LOCK_UN); close(fd)
    }

    /// Append one item under lock
    func appendItem(_ item: NotificationItem) {
        let fd = open(lockPath, O_CREAT | O_RDWR, 0o644)
        guard fd >= 0 else { logErr("appendItem: open lock failed"); return }
        flock(fd, LOCK_EX)
        var list: [NotificationItem] = []
        if let data = try? Data(contentsOf: URL(fileURLWithPath: pendingPath)),
           let decoded = try? JSONDecoder().decode([NotificationItem].self, from: data) {
            list = decoded
        }
        list.append(item)
        if let data = try? JSONEncoder().encode(list) {
            try? data.write(to: URL(fileURLWithPath: pendingPath))
        }
        flock(fd, LOCK_UN); close(fd)
    }

    /// Check if a daemon process is already running via PID file
    func isDaemonRunning() -> Bool {
        guard let pidStr = try? String(contentsOfFile: daemonPidPath, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines),
              let pid = Int32(pidStr),
              kill(pid, 0) == 0
        else { return false }
        return true
    }

    /// Fork a background daemon process from notify mode
    func startDaemon() {
        guard !isDaemonRunning() else { return }
        let task = Process()
        task.launchPath = CommandLine.arguments[0]
        task.arguments = ["--daemon"]
        task.standardInput = FileHandle.nullDevice
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
        } catch {
            logErr("failed to start daemon: \(error.localizedDescription)")
        }
    }

    // MARK: - File watching

    /// Watch pending.json for changes via dispatch source + polling fallback
    func startWatching() {
        // Seed the file if absent
        if !FileManager.default.fileExists(atPath: pendingPath) {
            try? "[]".write(toFile: pendingPath, atomically: true, encoding: .utf8)
        }
        let fd = open(pendingPath, O_EVTONLY)
        guard fd >= 0 else { logErr("startWatching: open failed"); return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd, eventMask: .write, queue: .main)
        source.setEventHandler { [weak self] in self?.onFileChanged() }
        source.setCancelHandler { close(fd) }
        source.resume()
        fileWatcher = source

        // Poll as safety net (dispatch sources can miss rapid writes)
        Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.onFileChanged()
        }
    }

    /// Called when pending.json is modified (dispatch source + timer)
    func onFileChanged() {
        let oldItems = items
        reloadItems()
        updateStatusBadge()

        if items.isEmpty {
            panel?.orderOut(nil)
            return
        }

        guard !readDND() else { return }

        if items != oldItems || panel?.isVisible == false {
            if items != oldItems && panel != nil { rebuildPanel() } else { showPanel() }
        }
    }

    // MARK: - Panel

    func panelHeight() -> CGFloat {
        let n = items.count
        guard n > 0 else { return 0 }
        return pad + CGFloat(n) * itemH + CGFloat(n - 1) + btnArea + pad
    }

    func showPanel() {
        if panel == nil { createPanel() }
        if panel?.isVisible == false {
            panel?.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @objc func screenChanged() {
        guard let p = panel, let screen = NSScreen.main else { return }
        let sf = screen.visibleFrame
        let winH = panelHeight()
        p.setFrame(NSRect(x: sf.maxX - winW - 20, y: sf.minY + 20, width: winW, height: winH), display: true)
        if !items.isEmpty {
            p.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func createPanel() {
        guard let screen = NSScreen.main else {
            DispatchQueue.main.async { [weak self] in self?.showPanel() }
            return
        }
        let sf = screen.visibleFrame
        let winH = panelHeight()
        guard winH > 0 else { return }

        let x = sf.maxX - winW - 20
        let y = sf.minY + 20

        let p = NSPanel(
            contentRect: NSRect(x: x, y: y, width: winW, height: winH),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        p.titlebarAppearsTransparent = true
        p.isFloatingPanel = true
        p.level = .floating
        p.backgroundColor = NSColor.controlBackgroundColor
        p.hidesOnDeactivate = false
        p.delegate = self

        guard let cv = p.contentView else { return }

        // Dismiss All button (bottom-right)
        let da = NSButton(frame: NSRect(x: winW - pad - 100, y: pad, width: 100, height: 26))
        da.title = loc("Dismiss All")
        da.bezelStyle = .rounded
        da.controlSize = .small
        da.keyEquivalent = "\r"
        da.setAccessibilityLabel(loc("Dismiss all notifications"))
        da.action = #selector(dismissAll)
        da.target = self
        cv.addSubview(da)
        self.panel = p
        populate(cv: cv, height: winH)
        p.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    func rebuildPanel() {
        guard let p = panel, let cv = p.contentView else { return }
        let winH = panelHeight()
        guard winH > 0 else { return }
        guard let screen = NSScreen.main else { return }
        let sf = screen.visibleFrame

        p.setFrame(NSRect(x: sf.maxX - winW - 20, y: sf.minY + 20, width: winW, height: winH), display: true)

        // Remove content views but keep the Dismiss All button
        for sub in cv.subviews {
            if let btn = sub as? NSButton, btn.action == #selector(dismissAll) { continue }
            sub.removeFromSuperview()
        }

        populate(cv: cv, height: winH)
        p.orderFrontRegardless()
    }

    func populate(cv: NSView, height winH: CGFloat) {
        let txtX = pad + iconS + 12
        let txtW = winW - txtX - pad
        for (i, item) in items.enumerated() {
            let yBase = winH - pad - CGFloat(i + 1) * itemH - CGFloat(i) - pad

            // Separator line between rows
            if i > 0 {
                let sep = NSBox(frame: NSRect(x: pad + 4, y: yBase + itemH, width: winW - 2 * (pad + 4), height: 1))
                sep.boxType = .separator
                cv.addSubview(sep)
            }

            // IDE icon
            if !item.icon.isEmpty, let img = NSImage(contentsOfFile: item.icon) {
                let iv = NSImageView(frame: NSRect(x: pad, y: yBase + (itemH - iconS) / 2, width: iconS, height: iconS))
                img.size = NSSize(width: iconS, height: iconS)
                iv.image = img
                iv.imageScaling = .scaleProportionallyUpOrDown
                cv.addSubview(iv)
            }

            // Project name + IDE
            let title = makeLabel("\(item.project)  ·  \(item.ide)", size: 15, weight: .semibold)
            title.frame = NSRect(x: txtX, y: yBase + 44, width: txtW, height: 20)
            cv.addSubview(title)

            // Status text
            let sub = makeLabel("\(item.line1)  \(item.line2)", size: 13, color: .secondaryLabelColor)
            sub.frame = NSRect(x: txtX, y: yBase + 20, width: txtW, height: 18)
            cv.addSubview(sub)

            // Per-row dismiss button (×)
            let closeBtn = NSButton(frame: NSRect(x: winW - pad - 20, y: yBase + (itemH - 18) / 2, width: 18, height: 18))
            closeBtn.title = "×"
            closeBtn.bezelStyle = .circular
            closeBtn.controlSize = .small
            closeBtn.font = NSFont.systemFont(ofSize: 10)
            closeBtn.tag = i
            closeBtn.action = #selector(dismissItem(_:))
            closeBtn.target = self
            closeBtn.setAccessibilityLabel("Dismiss")
            cv.addSubview(closeBtn)

            // Invisible click target — opens project in IDE
            let clickArea = NSView(frame: NSRect(x: pad, y: yBase, width: winW - pad * 2 - 20, height: itemH))
            clickArea.identifier = NSUserInterfaceItemIdentifier("\(i)")
            clickArea.addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(openItem(_:))))
            cv.addSubview(clickArea)
        }
    }

    /// Persist current items to disk (used after mutations)
    func saveItems() {
        let fd = open(lockPath, O_CREAT | O_RDWR, 0o644)
        guard fd >= 0 else { logErr("saveItems: open lock failed"); return }
        flock(fd, LOCK_EX)
        if let data = try? JSONEncoder().encode(items) {
            try? data.write(to: URL(fileURLWithPath: pendingPath))
        }
        flock(fd, LOCK_UN); close(fd)
    }

    // MARK: - Actions

    @objc func dismissItem(_ sender: NSButton) {
        let idx = sender.tag
        guard idx >= 0, idx < items.count else { return }
        items.remove(at: idx)
        saveItems()
        updateStatusBadge()
        if items.isEmpty {
            panel?.orderOut(nil)
        } else {
            rebuildPanel()
        }
    }

    @objc func openItem(_ sender: NSGestureRecognizer) {
        guard let idStr = sender.view?.identifier?.rawValue,
              let idx = Int(idStr),
              idx >= 0, idx < items.count else { return }
        let item = items[idx]

        openProjectInIDE(item)

        // Remove all notifications for this project (older + current)
        items.removeAll { $0.project == item.project }
        saveItems()
        updateStatusBadge()

        if items.isEmpty {
            panel?.orderOut(nil)
        } else {
            rebuildPanel()
        }
    }

    /// Map IDE identifier to macOS app name and open the project path
    func openProjectInIDE(_ item: NotificationItem) {
        let appName: String
        switch item.ide {
        case "Cursor":     appName = "Cursor"
        case "VS Code":    appName = "Visual Studio Code"
        case "Trae":       appName = "Trae"
        case "Qoder":      appName = "Qoder"
        case "iTerm2":     appName = "iTerm"
        case "Warp":       appName = "Warp"
        case "Ghostty":    appName = "Ghostty"
        case "Kitty":      appName = "kitty"
        case "Alacritty":  appName = "Alacritty"
        case "WezTerm":    appName = "WezTerm"
        case "Terminal":   appName = "Terminal"
        default:           appName = item.ide
        }
        guard let path = item.path, !path.isEmpty else { return }
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = ["-a", appName, path]
        do {
            try task.run()
        } catch {
            logErr("failed to open \(path) with \(appName): \(error.localizedDescription)")
        }
    }

    @objc func dismissAll() {
        clearItems()
        updateStatusBadge()
        panel?.orderOut(nil)
    }

    // MARK: - Sound

    func readSavedSound() -> String {
        guard let saved = try? String(contentsOfFile: soundPrefPath, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines),
              soundNames.contains(saved)
        else { return "Glass" }
        return saved
    }

    func saveSound(_ name: String) {
        try? name.write(toFile: soundPrefPath, atomically: true, encoding: .utf8)
    }

    func playSound() {
        guard !readDND(), !readMuted() else { return }
        let name = readSavedSound()
        let task = Process()
        task.launchPath = "/usr/bin/afplay"
        task.arguments = ["/System/Library/Sounds/\(name).aiff"]
        do {
            try task.run()
        } catch {
            logErr("failed to play sound: \(error.localizedDescription)")
        }
    }

    // MARK: - Helpers

    func makeLabel(_ text: String, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = .labelColor) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        l.font = NSFont.systemFont(ofSize: size, weight: weight)
        l.textColor = color
        l.lineBreakMode = .byTruncatingTail
        return l
    }

    // MARK: - Menu Bar

    func setupMenuBar() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = createBellIcon(dnd: readDND())

        let menu = NSMenu()
        menu.autoenablesItems = false

        let titleItem = NSMenuItem(title: loc("Notification Center"), action: nil, keyEquivalent: "")
        titleItem.tag = 1
        menu.addItem(titleItem)
        menu.addItem(NSMenuItem.separator())

        // Do Not Disturb toggle
        let dndItem = NSMenuItem(title: loc("Do Not Disturb"), action: #selector(toggleDND), keyEquivalent: "d")
        dndItem.tag = 4
        menu.addItem(dndItem)
        menu.addItem(NSMenuItem.separator())

        // Sound submenu
        let soundItem = NSMenuItem(title: loc("Sound"), action: nil, keyEquivalent: "")
        let soundMenu = NSMenu()
        for s in soundNames {
            let mi = NSMenuItem(title: s, action: #selector(selectSound(_:)), keyEquivalent: "")
            mi.representedObject = s
            soundMenu.addItem(mi)
        }
        soundItem.submenu = soundMenu
        menu.addItem(soundItem)

        // Mute toggle
        let muteItem = NSMenuItem(title: loc("Mute"), action: #selector(toggleMute), keyEquivalent: "m")
        muteItem.tag = 2
        menu.addItem(muteItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: loc("Quit"), action: #selector(quitDaemon), keyEquivalent: "q"))
        item.menu = menu
        statusItem = item
        updateStatusBadge()
    }

    /// Draw the menu bar icon: bell with angle brackets, optional DND slash
    func createBellIcon(dnd: Bool = false) -> NSImage {
        let img = NSImage(size: NSSize(width: 20, height: 18))
        img.isTemplate = true
        img.lockFocus()
        defer { img.unlockFocus() }

        // Bell body — rounded arc top, straight sides
        let bell = NSBezierPath()
        bell.move(to: NSPoint(x: 5.5, y: 4))
        bell.line(to: NSPoint(x: 5.5, y: 10))
        bell.appendArc(withCenter: NSPoint(x: 10, y: 10), radius: 4.5,
                       startAngle: 180, endAngle: 0, clockwise: true)
        bell.line(to: NSPoint(x: 14.5, y: 4))
        bell.lineWidth = 1.5
        bell.lineCapStyle = .round
        bell.stroke()

        // Bottom rim
        let rim = NSBezierPath()
        rim.move(to: NSPoint(x: 7, y: 4))
        rim.line(to: NSPoint(x: 13, y: 4))
        rim.lineWidth = 1.5
        rim.lineCapStyle = .round
        rim.stroke()

        // Top nub (stem + knob)
        let nubStem = NSBezierPath()
        nubStem.move(to: NSPoint(x: 10, y: 14.5))
        nubStem.line(to: NSPoint(x: 10, y: 16))
        nubStem.lineWidth = 1.5
        nubStem.lineCapStyle = .round
        nubStem.stroke()

        let nubKnob = NSBezierPath(ovalIn: NSRect(x: 9.3, y: 16, width: 1.4, height: 1.4))
        nubKnob.fill()

        // Clapper
        let clap = NSBezierPath(ovalIn: NSRect(x: 9.3, y: 2, width: 1.4, height: 1.8))
        clap.fill()

        // Left angle bracket — outside bell body
        let lb = NSBezierPath()
        lb.move(to: NSPoint(x: 3, y: 12))
        lb.line(to: NSPoint(x: 1.8, y: 9.25))
        lb.line(to: NSPoint(x: 3, y: 6.5))
        lb.lineWidth = 1.1
        lb.lineCapStyle = .round
        lb.lineJoinStyle = .round
        lb.stroke()

        // Right angle bracket — outside bell body
        let rb = NSBezierPath()
        rb.move(to: NSPoint(x: 17, y: 12))
        rb.line(to: NSPoint(x: 18.2, y: 9.25))
        rb.line(to: NSPoint(x: 17, y: 6.5))
        rb.lineWidth = 1.1
        rb.lineCapStyle = .round
        rb.lineJoinStyle = .round
        rb.stroke()

        // DND: diagonal line across the icon
        if dnd {
            let slash = NSBezierPath()
            slash.move(to: NSPoint(x: 2, y: 16))
            slash.line(to: NSPoint(x: 18, y: 2))
            slash.lineWidth = 1.0
            slash.lineCapStyle = .round
            slash.stroke()
        }

        return img
    }

    func readMuted() -> Bool {
        guard let val = try? String(contentsOfFile: mutedPrefPath, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
        return val == "true"
    }

    @objc func toggleMute() {
        let newVal = !readMuted()
        try? (newVal ? "true" : "false").write(toFile: mutedPrefPath, atomically: true, encoding: .utf8)
        updateStatusBadge()
    }

    func readDND() -> Bool {
        guard let val = try? String(contentsOfFile: dndPrefPath, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
        return val == "true"
    }

    @objc func toggleDND() {
        let newVal = !readDND()
        try? (newVal ? "true" : "false").write(toFile: dndPrefPath, atomically: true, encoding: .utf8)
        if !newVal, !items.isEmpty { showPanel() }
        updateStatusBadge()
    }

    @objc func selectSound(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        saveSound(name)
        updateStatusBadge()
        // Preview the selected sound
        let task = Process()
        task.launchPath = "/usr/bin/afplay"
        task.arguments = ["/System/Library/Sounds/\(name).aiff"]
        try? task.run()
    }

    /// Refresh menu bar badge, icon, and menu item states
    func updateStatusBadge() {
        guard let btn = statusItem?.button, let menu = statusItem?.menu else { return }
        if items.isEmpty {
            btn.title = ""
            menu.item(withTag: 1)?.title = loc("Notification Center")
        } else {
            btn.title = " \(items.count)"
            menu.item(withTag: 1)?.title = "\(loc("Notification Center")) (\(items.count))"
        }

        let dnd = readDND()
        menu.item(withTag: 4)?.state = dnd ? .on : .off
        btn.image = createBellIcon(dnd: dnd)

        let muted = readMuted()
        menu.item(withTag: 2)?.title = muted ? loc("Unmute") : loc("Mute")
        menu.item(withTag: 2)?.state = muted ? .on : .off

        let currentSound = readSavedSound()
        if let soundItem = menu.item(withTitle: loc("Sound")),
           let sub = soundItem.submenu {
            for mi in sub.items {
                mi.state = (mi.representedObject as? String) == currentSound ? .on : .off
            }
        }
    }

    @objc func quitDaemon() {
        NSApplication.shared.terminate(nil)
    }

    func windowWillClose(_ notification: Notification) {
        clearItems()
    }
}

// MARK: - Entry point

let delegate = AppDelegate()
let args = CommandLine.arguments

if args.contains("--version") || args.contains("-v") {
    print("notify-tool version \(toolVersion)")
    exit(0)
}

if args.contains("--help") || args.contains("-h") {
    print("""
notify-tool v\(toolVersion) — macOS notification center in your menu bar

Usage:
  notify-tool --daemon              Run as background daemon
  notify-tool --project <name> ...  Send a notification (notify mode)

Notify mode arguments:
  --project <name>   Project name (required)
  --ide     <name>   IDE identifier (Cursor, VS Code, Trae, iTerm2, etc.)
  --icon    <path>   Path to .icns file for the IDE icon
  --path    <dir>    Project directory path (click to open in IDE)
  --line1   <text>   First status line
  --line2   <text>   Second status line

Environment:
  NOTIFY_TOOL_HOME   Data directory (default: ~/.claude/)

See README.md for full documentation.
""")
    exit(0)
}

let isDaemon = args.contains("--daemon")

if isDaemon {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    app.delegate = delegate
    app.run()
} else {
    // Notify mode: write item, start daemon if needed, play sound, exit
    let project = delegate.getArg("project") ?? "Unknown"
    let ide     = delegate.getArg("ide") ?? "Terminal"
    let icon    = delegate.getArg("icon") ?? ""
    let path    = delegate.getArg("path") ?? ""
    let line1   = delegate.getArg("line1") ?? "Task completed"
    let line2   = delegate.getArg("line2") ?? "Come check it out"

    let item = NotificationItem(project: project, ide: ide, icon: icon, path: path, line1: line1, line2: line2)
    delegate.appendItem(item)
    delegate.startDaemon()
    delegate.playSound()

    // Brief pause so the daemon's file watcher picks up the change
    Thread.sleep(forTimeInterval: 0.2)
    exit(0)
}

// MARK: - Arg helper

extension AppDelegate {
    func getArg(_ key: String) -> String? {
        let a = CommandLine.arguments
        for i in 0..<a.count-1 where a[i] == "--\(key)" { return a[i+1] }
        return nil
    }
}
