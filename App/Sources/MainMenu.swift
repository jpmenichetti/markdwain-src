// MainMenu.swift — builds the whole menu bar in code (App, File, Edit, View, Window, Help).
// Items with a `target` go to AppDelegate; nil-target items (Copy, Find, Close...) use the responder chain,
// which reaches the focused WKWebView or the key window.

import AppKit

enum MainMenu {
    private static var name: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "MarkDwain" }

    /// Adds an item to `menu`. `target` nil means "send down the responder chain".
    @discardableResult
    private static func add(_ menu: NSMenu, _ title: String, _ action: Selector?, _ key: String = "",
                            _ mods: NSEvent.ModifierFlags = .command, target: AnyObject? = nil, tag: Int = 0) -> NSMenuItem {
        let item = menu.addItem(withTitle: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = mods
        item.target = target
        item.tag = tag
        return item
    }

    private static func submenu(_ bar: NSMenu, _ title: String) -> NSMenu {
        let menu = NSMenu(title: title)
        bar.addItem(withTitle: title, action: nil, keyEquivalent: "").submenu = menu
        return menu
    }

    /// - Parameter target: the AppDelegate.
    static func build(target t: AppDelegate) -> NSMenu {
        let bar = NSMenu()

        let app = submenu(bar, name)
        add(app, "About \(name)", #selector(NSApplication.orderFrontStandardAboutPanel(_:)))
        app.addItem(.separator())
        add(app, "Hide \(name)", #selector(NSApplication.hide(_:)), "h")
        add(app, "Hide Others", #selector(NSApplication.hideOtherApplications(_:)), "h", [.command, .option])
        add(app, "Show All", #selector(NSApplication.unhideAllApplications(_:)))
        app.addItem(.separator())
        add(app, "Quit \(name)", #selector(NSApplication.terminate(_:)), "q")

        let file = submenu(bar, "File")
        add(file, "Open…", #selector(AppDelegate.openDocument(_:)), "o", target: t)
        let recent = NSMenu(title: "Open Recent")
        recent.delegate = t
        file.addItem(withTitle: "Open Recent", action: nil, keyEquivalent: "").submenu = recent
        file.addItem(.separator())
        add(file, "Close", #selector(NSWindow.performClose(_:)), "w")
        file.addItem(.separator())
        add(file, "Reveal in Finder", #selector(AppDelegate.revealInFinder(_:)), "r", [.command, .shift], target: t)
        add(file, "Open With…", #selector(AppDelegate.openWith(_:)), target: t)

        let edit = submenu(bar, "Edit")
        add(edit, "Copy", #selector(NSText.copy(_:)), "c")
        add(edit, "Select All", #selector(NSText.selectAll(_:)), "a")
        edit.addItem(.separator())
        // Find is a custom bar in the viewer window (WKWebView has no built-in text-finder menu support).
        let find = submenu(edit, "Find")
        add(find, "Find…", #selector(AppDelegate.showFind(_:)), "f", target: t)
        add(find, "Find Next", #selector(AppDelegate.findNext(_:)), "g", target: t)
        add(find, "Find Previous", #selector(AppDelegate.findPrevious(_:)), "g", [.command, .shift], target: t)

        let view = submenu(bar, "View")
        add(view, "Toggle Table of Contents", #selector(AppDelegate.toggleTOC(_:)), "s", [.command, .control], target: t)
        view.addItem(.separator())
        add(view, "Zoom In", #selector(AppDelegate.zoomIn(_:)), "+", target: t)
        // ⌘= is the same physical key as ⌘+ on US keyboards; keep both working (hidden duplicate).
        let alt = add(view, "Zoom In", #selector(AppDelegate.zoomIn(_:)), "=", target: t)
        alt.isHidden = true; alt.allowsKeyEquivalentWhenHidden = true
        add(view, "Zoom Out", #selector(AppDelegate.zoomOut(_:)), "-", target: t)
        add(view, "Actual Size", #selector(AppDelegate.zoomReset(_:)), "0", target: t)

        let window = submenu(bar, "Window")
        add(window, "Minimize", #selector(NSWindow.performMiniaturize(_:)), "m")
        add(window, "Zoom", #selector(NSWindow.performZoom(_:)))
        window.addItem(.separator())
        add(window, "Bring All to Front", #selector(NSApplication.arrangeInFront(_:)))
        NSApp.windowsMenu = window

        let help = submenu(bar, "Help")
        add(help, "\(name) Help", #selector(AppDelegate.showHelp(_:)), "?", target: t)
        NSApp.helpMenu = help

        return bar
    }
}
