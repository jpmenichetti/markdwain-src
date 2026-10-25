// PageBuilder.swift — builds the complete HTML page (CSS + JS inlined) shown by the app and by Quick Look.
// Depends on the Web/ resource folder bundled into each target (Shared/Web, added as a folder reference).
// Fits in the flow: caller supplies Markdown text -> PageBuilder.html(...) -> WKWebView loads the result.

import Foundation

/// Anchor class so `Bundle(for:)` finds the bundle this file was compiled into (app or extension),
/// each of which carries its own copy of the Web/ folder.
private final class BundleToken {}

/// Shared constants for the Markdown file types MarkDwain handles.
enum MarkdownTypes {
    /// File extensions treated as Markdown (must match the document types in project.yml).
    static let extensions: Set<String> = ["md", "markdown", "mdown", "mkd"]
}

/// Generates the single HTML document that renders a Markdown file.
enum PageBuilder {
    /// Everything except the per-file part, read once from the bundle. JS/CSS are inlined (not referenced by
    /// URL) so the page works unchanged in the sandboxed Quick Look extension, which can't freely read files.
    private static let staticParts: (css: String, js: String, hljsLight: String, hljsDark: String) = {
        func read(_ name: String) -> String {
            let bundle = Bundle(for: BundleToken.self)
            guard let url = bundle.url(forResource: name, withExtension: nil, subdirectory: "Web"),
                  let text = try? String(contentsOf: url, encoding: .utf8) else { return "" }
            return text
        }
        // Order matters: libraries first, then render.js (uses them), then viewer.js (uses render.js).
        let libs = ["vendor/markdown-it.min.js", "vendor/markdownItAnchor.umd.js", "vendor/markdown-it-task-lists.min.js",
                    "vendor/markdown-it-footnote.min.js", "vendor/highlight.min.js", "vendor/purify.min.js",
                    "render.js", "viewer.js"]
        return (read("viewer.css"), libs.map(read).joined(separator: "\n;\n"),
                read("vendor/hljs-github.min.css"), read("vendor/hljs-github-dark.min.css"))
    }()

    /// Returns the full HTML page.
    /// - Parameters:
    ///   - baseFolder: folder of the Markdown file; becomes `<base href>` so relative images/links resolve there. Nil in Quick Look.
    ///   - markdown: initial document text (rendered by `MarkDwain.boot`).
    ///   - sidebar: whether the TOC sidebar starts visible.
    ///   - preview: true for Quick Look (no sidebar, no native bridge).
    ///   - truncated: shows the "truncated" note (Quick Look size cap).
    ///   - anchor: heading id to scroll to after the first render.
    static func html(baseFolder: URL?, markdown: String, sidebar: Bool, preview: Bool,
                     truncated: Bool = false, anchor: String? = nil) -> String {
        var config: [String: Any] = ["markdown": markdown, "sidebar": sidebar, "preview": preview, "truncated": truncated]
        if let anchor { config["anchor"] = anchor }
        let data = (try? JSONSerialization.data(withJSONObject: config, options: [.withoutEscapingSlashes])) ?? Data("{}".utf8)
        // Inside a <script> element "</script" and "<!--" would end/alter parsing, so neutralise them.
        let json = String(decoding: data, as: UTF8.self)
            .replacingOccurrences(of: "</", with: "<\\/")
            .replacingOccurrences(of: "<!--", with: "<\\!--")
        var base = ""
        if let baseFolder {
            // Trailing slash is required, otherwise the last path component is dropped when resolving.
            base = "<base href=\"\(URL(fileURLWithPath: baseFolder.path, isDirectory: true).absoluteString)\">"
        }
        let parts = staticParts
        return """
        <!DOCTYPE html><html><head><meta charset="utf-8">\(base)
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style media="(prefers-color-scheme: light)">\(parts.hljsLight)</style>
        <style media="(prefers-color-scheme: dark)">\(parts.hljsDark)</style>
        <style>\(parts.css)</style></head>
        <body><nav id="toc"><div id="toc-list"></div></nav>
        <main><div id="missing" class="banner" hidden>File no longer exists. Showing the last version; will refresh if it reappears.</div>
        <div id="truncated" class="banner" hidden>This file is large, so the preview is truncated.</div>
        <article id="content"></article></main><div id="linkbar" hidden></div>
        <script>\(parts.js)</script>
        <script>MarkDwain.boot(\(json));</script></body></html>
        """
    }
}
