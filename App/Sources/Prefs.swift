// Prefs.swift — the few persisted, app-wide settings (UserDefaults): zoom, sidebar visibility, window size.
// Window controllers listen for `Prefs.changed` so a change made in one window applies to all.

import AppKit

enum Prefs {
    /// Posted after zoom or sidebar visibility changes.
    static let changed = Notification.Name("MarkDwainPrefsChanged")
    private static let defaults = UserDefaults.standard

    /// Page zoom in percent, 50...300. Global on purpose (spec): every window uses the same level.
    static var zoomPercent: Int {
        get { let v = defaults.integer(forKey: "zoomPercent"); return v == 0 ? 100 : min(300, max(50, v)) }
        set { defaults.set(min(300, max(50, newValue)), forKey: "zoomPercent"); NotificationCenter.default.post(name: changed, object: nil) }
    }

    /// TOC sidebar visibility. Defaults to collapsed (bool(forKey:) is false until first set).
    static var sidebarVisible: Bool {
        get { defaults.bool(forKey: "sidebarVisible") }
        set { defaults.set(newValue, forKey: "sidebarVisible"); NotificationCenter.default.post(name: changed, object: nil) }
    }

    /// Last window content size, shared by all files ("per app, not per file").
    static var windowSize: NSSize {
        get {
            let w = defaults.double(forKey: "windowWidth"), h = defaults.double(forKey: "windowHeight")
            return w > 200 && h > 200 ? NSSize(width: w, height: h) : NSSize(width: 800, height: 900)
        }
        set { defaults.set(newValue.width, forKey: "windowWidth"); defaults.set(newValue.height, forKey: "windowHeight") }
    }
}
