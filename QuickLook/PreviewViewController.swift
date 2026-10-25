// PreviewViewController.swift — the Quick Look preview extension (Space on a .md file in Finder).
// Renders with the same PageBuilder/HTML/JS/CSS as the app (Shared/), but as a static, sidebar-less page.
// Flow: Finder -> macOS launches this sandboxed extension -> preparePreviewOfFile -> WKWebView shows the page.

import Cocoa
import QuickLookUI
import WebKit

/// View-based Quick Look preview controller hosting a WKWebView.
final class PreviewViewController: NSViewController, QLPreviewingController, WKNavigationDelegate {
    /// Preview cap: huge files would make the web view slow; beyond this a "truncated" note is shown.
    private static let maxBytes = 2 * 1024 * 1024

    private var webView: WKWebView!
    private var loadContinuation: CheckedContinuation<Void, Never>?

    override func loadView() {
        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 800, height: 600), configuration: WKWebViewConfiguration())
        webView.navigationDelegate = self
        view = webView
    }

    /// Called by Quick Look with the file to preview. Completes only once the page has loaded so macOS
    /// doesn't show a blank frame first.
    func preparePreviewOfFile(at url: URL) async throws {
        let loaded = TextLoader.load(url, maxBytes: Self.maxBytes) ?? (text: "Could not read this file.", truncated: false)
        // No baseFolder: the extension sandbox can't read the file's neighbours, so relative images stay broken.
        // We deliberately do not weaken the sandbox to fix that.
        let html = PageBuilder.html(baseFolder: nil, markdown: loaded.text, sidebar: false, preview: true, truncated: loaded.truncated)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            loadContinuation = continuation
            webView.loadHTMLString(html, baseURL: nil)
            // Safety net: never leave Quick Look spinning if the web view fails to report back.
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in self?.finish() }
        }
    }

    /// Links inside a preview do nothing: only the initial load may happen.
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(action.navigationType == .other ? .allow : .cancel)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { finish() }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { finish() }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { finish() }

    private func finish() { loadContinuation?.resume(); loadContinuation = nil }
}
