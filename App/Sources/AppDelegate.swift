// AppDelegate.swift — app lifecycle, the registry of open windows (one per file) and all menu actions.
// Entry points for files: Finder/Dock/terminal (`application(_:open:)`), File > Open, Open Recent, link clicks.
// Menus themselves are built in MainMenu.swift.

import AppKit
import UniformTypeIdentifiers

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation, NSMenuDelegate {
    /// Convenience for window controllers that need to open other files.
    static var shared: AppDelegate { NSApp.delegate as! AppDelegate }

    /// Scratch folder for the generated page shells (see ViewerWindowController.loadPage).
    static let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("MarkDwain", isDirectory: true)

    /// Open windows keyed by the file's canonical path, so the same file is never opened twice.
    private var controllers: [String: ViewerWindowController] = [:]

    // MARK: - Lifecycle

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false // spec: no tabs anywhere
        try? FileManager.default.removeItem(at: Self.tempDirectory) // leftovers from a crash
        NSApp.mainMenu = MainMenu.build(target: self)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // When launched by double-clicking a file, macOS delivers `application(_:open:)` around this moment.
        // Wait a beat before deciding that nothing was requested and showing the Open dialog.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [self] in
            if controllers.isEmpty { showOpenPanel(quitIfCancelled: true) }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showOpenPanel(quitIfCancelled: false) }
        return false
    }

    func application(_ application: NSApplication, open urls: [URL]) { urls.forEach { open($0) } }

    // MARK: - Opening files

    /// Opens `url` in its own window, or focuses the existing window if it is already open.
    /// - Parameter anchor: heading id to scroll to (from links like `guide.md#install`).
    func open(_ url: URL, anchor: String? = nil) {
        let key = url.resolvingSymlinksInPath().standardizedFileURL.path
        if let existing = controllers[key] {
            existing.window?.makeKeyAndOrderFront(nil)
            if let anchor { existing.scroll(to: anchor) }
        } else {
            let controller = ViewerWindowController(url: url, anchor: anchor)
            controller.onClose = { [weak self] in self?.controllers[key] = nil }
            controllers[key] = controller
            controller.present()
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func openDocument(_ sender: Any?) { showOpenPanel(quitIfCancelled: false) }

    private func showOpenPanel(quitIfCancelled: Bool) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        var types = MarkdownTypes.extensions.compactMap { UTType(filenameExtension: $0) }
        if let md = UTType("net.daringfireball.markdown") { types.append(md) }
        types.append(.plainText)
        panel.allowedContentTypes = types
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK {
            panel.urls.forEach { open($0) }
        } else if quitIfCancelled && controllers.isEmpty {
            NSApp.terminate(nil)
        }
    }

    @objc func openRecent(_ sender: NSMenuItem) {
        if let url = sender.representedObject as? URL { open(url) }
    }

    @objc func clearRecents(_ sender: Any?) { NSDocumentController.shared.clearRecentDocuments(nil) }

    /// Rebuilds the Open Recent submenu on demand. Done by hand because NSDocumentController's automatic
    /// menu would try to create NSDocument objects, which this app doesn't use.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        for url in NSDocumentController.shared.recentDocumentURLs {
            let item = NSMenuItem(title: url.lastPathComponent, action: #selector(openRecent(_:)), keyEquivalent: "")
            item.target = self; item.representedObject = url
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let clear = NSMenuItem(title: "Clear Menu", action: #selector(clearRecents(_:)), keyEquivalent: "")
        clear.target = self
        menu.addItem(clear)
    }

    // MARK: - Current-window actions

    private var current: ViewerWindowController? { NSApp.keyWindow?.windowController as? ViewerWindowController }

    @objc func revealInFinder(_ sender: Any?) {
        if let url = current?.fileURL { NSWorkspace.shared.activateFileViewerSelecting([url]) }
    }

    /// Lets the user pick an application to open the current file with. A plain "open in default app" would
    /// loop back here whenever MarkDwain itself is the default Markdown viewer.
    @objc func openWith(_ sender: Any?) {
        guard let url = current?.fileURL else { return }
        let panel = NSOpenPanel()
        panel.message = "Choose an application to open \(url.lastPathComponent)"
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let appURL = panel.url else { return }
        NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration())
    }

    @objc func toggleTOC(_ sender: Any?) { Prefs.sidebarVisible.toggle() }

    // MARK: - Zoom (global, see Prefs)

    @objc func zoomIn(_ sender: Any?) { Prefs.zoomPercent += 10 }
    @objc func zoomOut(_ sender: Any?) { Prefs.zoomPercent -= 10 }
    @objc func zoomReset(_ sender: Any?) { Prefs.zoomPercent = 100 }

    // MARK: - Help

    @objc func showHelp(_ sender: Any?) {
        if let url = Bundle.main.url(forResource: "Help", withExtension: "md") { open(url) }
    }

    // MARK: - Menu validation

    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        switch item.action {
        case #selector(revealInFinder(_:)), #selector(openWith(_:)), #selector(toggleTOC(_:)): return current != nil
        default: return true
        }
    }
}
