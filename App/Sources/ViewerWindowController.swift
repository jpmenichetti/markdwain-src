// ViewerWindowController.swift — one window showing one Markdown file: WKWebView, live reload, link routing.
// Created and tracked by AppDelegate (one per distinct file). Uses PageBuilder/TextLoader (shared),
// FileWatcher (live reload) and Prefs (zoom, sidebar). The page's JS talks back via the "mdw" message handler.

import AppKit
import WebKit

/// WKWebView that accepts dropped files and hands them to the app instead of navigating to them.
private final class DropWebView: WKWebView {
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        sender.draggingPasteboard.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) ? .copy : []
    }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        urls.forEach { AppDelegate.shared.open($0) }
        return !urls.isEmpty
    }
}

/// Breaks the retain cycle WKUserContentController -> handler -> controller -> webView -> configuration.
private final class WeakScriptHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?
    init(_ target: WKScriptMessageHandler) { self.target = target }
    func userContentController(_ c: WKUserContentController, didReceive m: WKScriptMessage) { target?.userContentController(c, didReceive: m) }
}

/// Window controller for a single Markdown file.
final class ViewerWindowController: NSWindowController, NSWindowDelegate, WKNavigationDelegate, WKScriptMessageHandler, NSToolbarDelegate, NSSearchFieldDelegate {
    let fileURL: URL
    /// Called when the window closes so AppDelegate can forget it.
    var onClose: (() -> Void)?

    private let webView: WKWebView
    private var watcher: FileWatcher?
    private var pageURL: URL?
    private var pageLoaded = false
    private var reloadPending = false
    private var missing = false
    private var findAccessory: NSTitlebarAccessoryViewController?
    private lazy var findField: NSSearchField = {
        let field = NSSearchField()
        field.placeholderString = "Find in page"
        field.delegate = self
        field.target = self
        field.action = #selector(findSubmitted(_:))
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return field
    }()
    private static let toggleTOCItem = NSToolbarItem.Identifier("toggleTOC")

    // MARK: - Setup

    init(url: URL, anchor: String?) {
        fileURL = url
        let config = WKWebViewConfiguration()
        webView = DropWebView(frame: .zero, configuration: config)
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: Prefs.windowSize),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        super.init(window: window)
        window.title = url.lastPathComponent
        window.representedURL = url // proxy icon; ⌘-click on the title shows the path
        window.tabbingMode = .disallowed
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = webView
        webView.registerForDraggedTypes([.fileURL])
        webView.underPageBackgroundColor = .textBackgroundColor // avoids a white flash in dark mode
        webView.navigationDelegate = self
        webView.configuration.userContentController.add(WeakScriptHandler(self), name: "mdw")
        webView.pageZoom = CGFloat(Prefs.zoomPercent) / 100

        let toolbar = NSToolbar(identifier: "viewer")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        window.toolbar = toolbar

        NotificationCenter.default.addObserver(self, selector: #selector(prefsChanged), name: Prefs.changed, object: nil)
        loadPage(anchor: anchor)
        watcher = FileWatcher(url: url, onChange: { [weak self] in self?.fileChanged() },
                              onMissing: { [weak self] in self?.fileMissing() })
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    /// Shows the window, cascaded from the frontmost viewer so new windows don't stack exactly on top.
    func present() {
        guard let window else { return }
        if let front = NSApp.windows.first(where: { $0 !== window && $0.isVisible && $0.windowController is ViewerWindowController }) {
            window.setFrameTopLeftPoint(window.cascadeTopLeft(from: NSPoint(x: front.frame.minX, y: front.frame.maxY)))
        } else {
            window.center()
        }
        showWindow(nil)
        window.makeFirstResponder(webView) // so ⌘F/⌘G and keyboard scrolling go to the page
    }

    // MARK: - Loading and live reload

    /// Loads the page shell with the current file text. Written to a temp file and loaded with read access to "/"
    /// because the app is not sandboxed and the document's relative images/links live in arbitrary folders.
    private func loadPage(anchor: String?) {
        let text = TextLoader.load(fileURL)?.text ?? ""
        let html = PageBuilder.html(baseFolder: fileURL.deletingLastPathComponent(), markdown: text,
                                    sidebar: Prefs.sidebarVisible, preview: false, anchor: anchor)
        let dir = AppDelegate.tempDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let page = dir.appendingPathComponent(UUID().uuidString + ".html")
        do { try html.write(to: page, atomically: true, encoding: .utf8) } catch { return }
        pageURL = page
        webView.loadFileURL(page, allowingReadAccessTo: URL(fileURLWithPath: "/"))
    }

    private func fileChanged() {
        missing = false
        guard pageLoaded else { reloadPending = true; return }
        let text = TextLoader.load(fileURL)?.text ?? ""
        js("MarkDwain.setMissing(false); MarkDwain.update(\(Self.jsLiteral(text)));")
    }

    private func fileMissing() {
        missing = true
        js("MarkDwain.setMissing(true);")
    }

    private func js(_ script: String) { webView.evaluateJavaScript(script, completionHandler: nil) }

    /// Encodes a Swift string as a JavaScript string literal.
    private static func jsLiteral(_ s: String) -> String {
        let data = try? JSONSerialization.data(withJSONObject: s, options: [.fragmentsAllowed, .withoutEscapingSlashes])
        return data.map { String(decoding: $0, as: UTF8.self) } ?? "\"\""
    }

    /// Scrolls the existing page to a heading id (used when a link targets an already-open file).
    func scroll(to anchor: String) { js("MarkDwain.scrollToId(\(Self.jsLiteral(anchor)));") }

    @objc private func prefsChanged() {
        webView.pageZoom = CGFloat(Prefs.zoomPercent) / 100 // pageZoom (not CSS zoom) keeps layout and find working
        js("MarkDwain.setSidebar(\(Prefs.sidebarVisible));")
    }

    // MARK: - Actions (reached via the responder chain from menu items)

    @objc func toggleTOC(_ sender: Any?) { Prefs.sidebarVisible.toggle() }

    // MARK: - Find
    // WKWebView on macOS does not implement the standard NSTextFinder menu actions, so ⌘F is a small native bar
    // in the titlebar area that drives WKWebView.find (which highlights, selects and scrolls to each match).

    /// Shows the find bar (⌘F) and focuses its field; if already visible, just refocuses it.
    func showFind() {
        guard let window else { return }
        if findAccessory == nil {
            let prev = NSButton(image: NSImage(systemSymbolName: "chevron.up", accessibilityDescription: "Previous match")!, target: self, action: #selector(findPreviousAction(_:)))
            let next = NSButton(image: NSImage(systemSymbolName: "chevron.down", accessibilityDescription: "Next match")!, target: self, action: #selector(findNextAction(_:)))
            let done = NSButton(title: "Done", target: self, action: #selector(hideFindAction(_:)))
            [prev, next].forEach { $0.bezelStyle = .texturedRounded }
            let stack = NSStackView(views: [findField, prev, next, done])
            stack.orientation = .horizontal
            stack.spacing = 8
            stack.edgeInsets = NSEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
            let accessory = NSTitlebarAccessoryViewController()
            accessory.layoutAttribute = .bottom
            accessory.view = stack
            window.addTitlebarAccessoryViewController(accessory)
            findAccessory = accessory
        }
        window.makeFirstResponder(findField)
        findField.selectText(nil)
    }

    /// Finds the next/previous match of the field's text (wraps around, case-insensitive). Red text = no match.
    func find(backwards: Bool) {
        let query = findField.stringValue
        guard !query.isEmpty else { return }
        let config = WKFindConfiguration()
        config.backwards = backwards
        config.wraps = true
        webView.find(query, configuration: config) { [weak self] result in
            self?.findField.textColor = result.matchFound ? .labelColor : .systemRed
        }
    }

    private func hideFind() {
        guard let accessory = findAccessory, let window else { return }
        if let index = window.titlebarAccessoryViewControllers.firstIndex(of: accessory) {
            window.removeTitlebarAccessoryViewController(at: index)
        }
        findAccessory = nil
        window.makeFirstResponder(webView)
    }

    /// Return in the field = next match, ⇧Return = previous.
    @objc private func findSubmitted(_ sender: Any?) { find(backwards: NSEvent.modifierFlags.contains(.shift)) }
    @objc private func findNextAction(_ sender: Any?) { find(backwards: false) }
    @objc private func findPreviousAction(_ sender: Any?) { find(backwards: true) }
    @objc private func hideFindAction(_ sender: Any?) { hideFind() }

    func controlTextDidChange(_ obj: Notification) { find(backwards: false) } // search as you type

    /// Esc closes the bar.
    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        guard selector == #selector(NSResponder.cancelOperation(_:)) else { return false }
        hideFind()
        return true
    }

    // MARK: - Links

    func userContentController(_ c: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], body["type"] as? String == "link",
              let href = body["href"] as? String else { return }
        route(href: href)
    }

    /// Decides what a clicked link does. Relative hrefs resolve against the Markdown file's folder.
    private func route(href: String) {
        guard let url = URL(string: href, relativeTo: fileURL.deletingLastPathComponent())?.absoluteURL else { return }
        switch url.scheme?.lowercased() {
        case "http", "https", "mailto":
            NSWorkspace.shared.open(url)
        case "file":
            let target = URL(fileURLWithPath: url.path)
            if MarkdownTypes.extensions.contains(target.pathExtension.lowercased()) {
                AppDelegate.shared.open(target, anchor: url.fragment)
            } else {
                NSWorkspace.shared.open(target)
            }
        default:
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - WKNavigationDelegate

    /// The WebView must never leave the rendered document: only our own page may load in the main frame;
    /// any other navigation (e.g. a link that slipped past the JS handler) is cancelled and routed instead.
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard action.targetFrame?.isMainFrame ?? true else { decisionHandler(.allow); return }
        if action.request.url == pageURL { decisionHandler(.allow); return }
        if action.navigationType == .linkActivated, let url = action.request.url { route(href: url.absoluteString) }
        decisionHandler(.cancel)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        pageLoaded = true
        webView.pageZoom = CGFloat(Prefs.zoomPercent) / 100
        if missing { fileMissing() }
        if reloadPending { reloadPending = false; fileChanged() } // change arrived while the page was still loading
    }

    // MARK: - NSWindowDelegate

    func windowDidResize(_ notification: Notification) {
        if let size = window?.contentView?.frame.size, window?.isVisible == true { Prefs.windowSize = size }
    }

    func windowWillClose(_ notification: Notification) {
        watcher?.stop()
        NotificationCenter.default.removeObserver(self)
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "mdw")
        if let pageURL { try? FileManager.default.removeItem(at: pageURL) }
        onClose?()
    }

    // MARK: - NSToolbarDelegate

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { [Self.toggleTOCItem, .flexibleSpace] }
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { [.flexibleSpace, Self.toggleTOCItem] }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier id: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        guard id == Self.toggleTOCItem else { return nil }
        let item = NSToolbarItem(itemIdentifier: id)
        item.label = "Contents"
        item.toolTip = "Show or hide the table of contents (⌃⌘S)"
        item.image = NSImage(systemSymbolName: "sidebar.left", accessibilityDescription: "Table of contents")
        item.target = self
        item.action = #selector(toggleTOC(_:))
        return item
    }
}
