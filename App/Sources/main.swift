// main.swift — program entry point. Plain AppKit start-up (no SwiftUI App) because this app is all about
// custom menus, one window per file and open-URL events, which AppKit expresses most directly.

import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
