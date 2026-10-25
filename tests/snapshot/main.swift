// snapshot.swift — developer tool: renders a Markdown file through the real PageBuilder in an offscreen
// WKWebView and writes a PNG, plus a few DOM facts to stdout. Needs no screen-recording permission.
// Build/run via tests/snapshot/run.sh. Usage: snapshot <file.md> <out.png> [light|dark] [sidebar] [js:<script>]
// A js: argument is evaluated after load (async-capable) and its result printed, e.g. to test scrolling.
import AppKit
import WebKit

final class Runner: NSObject, WKNavigationDelegate {
    let web: WKWebView, out: String, window: NSWindow
    init(md: String, base: URL, out: String, dark: Bool, sidebar: Bool) {
        self.out = out
        web = WKWebView(frame: NSRect(x: 0, y: 0, width: 1000, height: 900))
        window = NSWindow(contentRect: web.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        window.contentView = web
        super.init()
        web.navigationDelegate = self
        let html = PageBuilder.html(baseFolder: base, markdown: md, sidebar: sidebar, preview: false)
        let page = FileManager.default.temporaryDirectory.appendingPathComponent("snap-\(UUID().uuidString).html")
        try! html.write(to: page, atomically: true, encoding: .utf8)
        web.loadFileURL(page, allowingReadAccessTo: URL(fileURLWithPath: "/"))
    }
    func webView(_ w: WKWebView, didFinish n: WKNavigation!) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if let js = CommandLine.arguments.first(where: { $0.hasPrefix("js:") }) {
                self.web.callAsyncJavaScript(String(js.dropFirst(3)), arguments: [:], in: nil, in: .page) { r in print("js:", r) }
            }
            self.web.evaluateJavaScript("JSON.stringify({tables:document.querySelectorAll('table').length, checkboxes:document.querySelectorAll('input[type=checkbox]').length, hljs:document.querySelectorAll('code.hljs').length, toc:document.querySelectorAll('#toc-list a').length, scripts:document.querySelectorAll('#content script').length, imgOK:Array.from(document.images).map(i=>i.naturalWidth>0), details:document.querySelectorAll('details').length, bodyClass:document.body.className})") { r, _ in
                print(r ?? "nil")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self.web.takeSnapshot(with: nil) { img, _ in
                    if let img, let tiff = img.tiffRepresentation, let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
                        try? png.write(to: URL(fileURLWithPath: self.out))
                    }
                    exit(0)
                } }
            }
        }
    }
}
let a = CommandLine.arguments
let file = URL(fileURLWithPath: a[1])
let app = NSApplication.shared
let runner = Runner(md: TextLoader.load(file)!.text, base: file.deletingLastPathComponent(), out: a[2], dark: a.count > 3 && a[3] == "dark", sidebar: a.contains("sidebar"))
app.run()
