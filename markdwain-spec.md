# MarkDwain — Build Spec

> Hand this file to Claude Code, in a folder that also contains the `Assets/` folder delivered with it. Build the app end to end, run it, and verify against the acceptance checklist at the bottom. Where this spec says "decide", pick the simplest option and note it in the README.

## 1. Goal

**MarkDwain** is a tiny, native, **read-only** Markdown viewer for macOS. Double-click a `.md` file in Finder and get a clean, fast preview in its own window. Pressing Space on a `.md` file in Finder shows the same rendering (Quick Look). Personal use, installed on two Macs.

**Non-goals (do not build):** editing, tabs, PDF export, printing, math/LaTeX, Mermaid, cloud sync, App Store distribution, cross-platform support.

## 2. Tech stack

- **Swift + SwiftUI** app shell, **AppKit** where SwiftUI falls short.
- **WKWebView** for rendering.
- **Markdown → HTML:** bundle `markdown-it` (with `markdown-it-anchor`, `markdown-it-task-lists`) and `highlight.js` as **local resources** inside the app. No network access at runtime. Rendering runs inside the WebView, so the app and the Quick Look extension share the exact same pipeline. Put shared code and web assets in a shared framework/folder used by both targets.
- Sanitize rendered HTML with a bundled **DOMPurify** (READMEs often contain raw HTML like `<img>` and `<details>`, which should work; `<script>` must not).
- **Project generation:** use **XcodeGen** (`project.yml`) so the Xcode project is reproducible from the command line. Commit `project.yml`, not a hand-edited `.xcodeproj`, unless XcodeGen proves problematic.
- Minimum macOS: **14 (Sonoma)**. Both of the user's Macs meet this.
- No third-party Swift packages unless truly needed.

## 3. Targets

1. **MarkDwain** — the viewer app.
2. **MarkDwain Quick Look** — Quick Look Preview Extension, view-based (`QLPreviewingController`) with a WKWebView, reusing the shared renderer.

## 4. App behavior

### 4.1 Opening files
- Supports File > Open (⌘O), drag a file onto the Dock icon or an open window, Finder "Open With", double-click (when set as default), and `open file.md` from the terminal.
- **Every file opens in its own new window.** No tabs: disable automatic window tabbing (`NSWindow.allowsAutomaticWindowTabbing = false`) and remove tab-related menu items.
- If the same file is already open, bring its existing window to front instead of opening a duplicate.
- File > Open Recent works.
- Launching with no file shows the Open dialog (no empty untitled document).
- Closing the last window quits the app.
- Window title = file name; use the proxy icon (represented URL) so ⌘-click on the title shows the path.
- Remember window size per app (not per file), with a sensible default (~800×900).

### 4.2 Default viewer for Markdown
- Declare document types for Markdown: UTI `net.daringfireball.markdown` (with fallback conformance to `public.plain-text`), extensions `md`, `markdown`, `mdown`, `mkd`.
- Role: Viewer. `LSHandlerRank = Default`.
- The user sets it as default through Finder > Get Info > Open with > Change All. Document this in the README. Do not rely on unsupported hacks.

### 4.3 Live reload
- Watch the open file and re-render automatically when it changes on disk.
- **Handle atomic saves**: many editors write a temp file and rename over the original, which kills a naive file watcher. Watch the parent directory or re-establish the watcher after rename/delete events. Debounce ~150 ms.
- **Preserve scroll position** across reloads.
- If the file is deleted or moved: keep the last rendering and show a small, non-modal banner ("File no longer exists"). Resume automatically if it reappears.
- Read as UTF-8; fall back to a lossy decode rather than failing.

### 4.4 Rendering
- GitHub-flavored Markdown: tables, task lists (checkboxes, read-only), strikethrough, autolinks, footnotes if cheap, fenced code blocks, blockquotes, horizontal rules, nested lists.
- Syntax highlighting in fenced code blocks (highlight.js, common languages bundle is enough).
- **Automatic light/dark** following system appearance (`prefers-color-scheme`), including highlight theme. GitHub-like typography: system font, ~15–16 px base, max content width ~900 px centered, comfortable line height, styled tables with borders and zebra rows, inline code styling.
- YAML front matter at the top of a file: render as a muted, collapsed block rather than as broken Markdown.
- **Relative images** resolve against the file's folder (local images must display). Because the app is not sandboxed (see section 9), load via `loadFileURL(_:allowingReadAccessTo:)` pointing at a generated HTML file, or a custom URL scheme handler. Pick the more robust option.
- Remote images (`https://`) load normally.

### 4.5 Links
- `#anchor` links scroll within the page (headings get GitHub-style slug ids).
- Relative links to Markdown files (`./other.md`, `docs/guide.md#section`) open in a **new viewer window** (or focus the existing one), then scroll to the anchor if present.
- `http(s)://` and `mailto:` links open in the default browser/app.
- Relative links to any other local file open with the system default app (`NSWorkspace.open`).
- Never navigate the WebView itself away from the rendered document.
- Hovering a link shows the destination in a small status bar at the bottom (nice to have).

### 4.6 Table of contents
- Toggleable **left sidebar** built from `h1`–`h4` headings, indented by level.
- Click an entry to scroll to the heading. Highlight the current section while scrolling.
- Toggle with **⌃⌘S** and a toolbar button; remember the open/closed state globally (UserDefaults). Hidden automatically if the document has no headings.
- Collapsed by default the first time.

### 4.7 Zoom
- **⌘+** zoom in, **⌘−** zoom out, **⌘0** reset. Also available in the View menu.
- Range 50%–300%, step 10%. Use `WKWebView.pageZoom`.
- Zoom level is **global** and persisted (UserDefaults), applied to all windows.

### 4.8 Find in page (required)
- **⌘F** find-in-page using WKWebView's built-in find, with ⌘G / ⇧⌘G for next/previous match.

### 4.9 Menus and shortcuts
- Standard app menu, File (Open, Open Recent, Close, Reveal in Finder, Open With…), Edit (Copy, Select All, Find), View (Toggle Sidebar, Zoom In/Out/Actual Size), Window, Help.
- **File > Open With…** shows a standard app chooser for the current file, so the user can jump to an editor. Do not offer a plain "open in default app" item, since MarkDwain itself may be the default and it would loop.
- Text is selectable and copyable.

## 5. Quick Look extension

- Registers for the same Markdown content types.
- Renders with the **same HTML/CSS/JS pipeline** as the app (shared code), light/dark aware.
- Static preview is enough: no live reload and no sidebar needed. A fixed-width, scrollable rendering is fine.
- Local relative images may not load due to the extension sandbox; acceptable limitation. Do not weaken the sandbox to fix it. Note it in the README.
- Must not crash on large files: cap preview at ~2 MB of text and show a "truncated" note beyond that.
- If another installed app already claims Markdown previews, document how to verify and reset (`qlmanage -r`, `qlmanage -p file.md`).

## 6. App icon

The icon is already designed and provided in the `Assets/` folder next to this spec:

- `Assets/AppIcon.appiconset/` — complete macOS icon set with `Contents.json`. Copy it into the app target's asset catalog (`Assets.xcassets/AppIcon.appiconset`) and set it as the app icon.
- `Assets/MarkDwain-icon.svg` — editable master (white "M" on navy with an amber down-arrow growing from its vertex).
- `Assets/AppIcon.icns` and `Assets/MarkDwain-icon-1024.png` — extras, in case they are needed.

Do not redesign or recolor it. Use the same icon for the Quick Look extension if it needs one. Confirm it appears correctly in Finder and the Dock.

## 7. Installation on two Macs

The user is **not technical**, so installation must be one command.

- Provide `scripts/install.sh` that: checks for Xcode and XcodeGen (installing XcodeGen through Homebrew if missing, with a clear message if Homebrew is absent), generates the project, builds a **Release** build, copies `MarkDwain.app` to `/Applications`, registers it with Launch Services, enables the Quick Look extension (`pluginkit -e use -i <bundle id>.<ext id>`), and runs `qlmanage -r` and `qlmanage -r cache`.
- Provide `scripts/uninstall.sh` that reverses this.
- Signing: use a local/ad-hoc signature suitable for personal use ("Sign to Run Locally") unless Quick Look extension registration requires a proper development team. If it does, document the minimum needed (for example, a free Apple ID Personal Team) and which parts expire. **Verify this empirically and write down what actually worked.**
- Preferred distribution between machines: **clone the repo and run `scripts/install.sh` on each Mac**. As a fallback, document how to copy the built `.app` to the second Mac and clear the quarantine flag (`xattr -dr com.apple.quarantine /Applications/MarkDwain.app`), noting that Quick Look may need extra steps.
- Works on both Apple Silicon and Intel if the user's Macs differ (build universal if cheap).

## 8. README (required)

Short, plain-language README covering: prerequisites (full **Xcode** installed from the App Store, opened once to accept the license; `xcode-select -s` pointing to it), one-command install, how to make MarkDwain the default for `.md`, how to enable Quick Look if needed, how to update (`git pull && scripts/install.sh`), how to uninstall, known limitations, and links to `docs/ARCHITECTURE.md` and `docs/DEVELOPMENT.md` (see section 10).

## 9. Project conventions

- **App Sandbox: OFF for the main app** (personal tool; needs free access to relative images and linked files). Quick Look extension stays sandboxed as required by macOS.
- Hardened runtime not required for local use.
- App name: **MarkDwain**. Bundle IDs: `local.markdwain` (app) and `local.markdwain.quicklook` (extension). Keep the name in one constant/config value so it is easy to change.
- Keep the codebase small and readable: target well under ~1,500 lines of Swift plus the web assets. No over-engineering, no dependency injection frameworks, no unit-test scaffolding beyond a small renderer test if easy.
- Include a `Samples/` folder with a Markdown file that exercises every feature (tables, task lists, code in several languages, relative image, relative link to a second `.md`, anchor links, front matter, long document for TOC), plus the second file it links to.

## 10. Code comments and technical documentation (required)

The user is not technical, and will rely on Claude Code, or on a future session, to maintain this app. Code and docs must therefore explain themselves. All documentation is written in English.

### 10.1 Comments in the code

- **File header** on every source file (Swift, JS, CSS, shell scripts): two to five lines saying what the file is for, what it depends on, and where it fits in the flow.
- **Doc comments** (`///` in Swift, JSDoc in JS) on every type, protocol, and non-trivial function or property: what it does, what its inputs and outputs mean, and any side effects.
- **Explain the why**, not the what. Comment every non-obvious decision, workaround, and macOS quirk. Examples: why the parent directory is watched (atomic saves), why the main app is not sandboxed, why `pageZoom` is used, why the Quick Look extension cannot load relative images.
- Use `// MARK: -` sections in longer Swift files.
- Shell scripts: comment each step and explain what it changes on the system.
- Do not add noise comments that just restate the code (`// increment i`).

### 10.2 Technical documentation in `docs/`

Create these files and keep them consistent with the code actually built:

**`docs/ARCHITECTURE.md`**, containing:
1. **Overview**: what the app is, the two targets (app and Quick Look extension), and how they share code.
2. **Component diagram**: how the main pieces connect (app shell, window/document management, file watcher, WebView bridge, shared renderer, Quick Look extension).
3. **Dependencies**: a table of every third-party library and tool (markdown-it and plugins, highlight.js, DOMPurify, XcodeGen, anything else), with name, version, purpose, license, where it lives in the repo, and how to update it. State clearly that there are no runtime network dependencies.
4. **Repository map**: every folder and file of significance, one line each.
5. **Main components**: for every main class/struct/file, its responsibility, its key methods, and what it talks to.
6. **Main flows**, each with a flow chart and a short walkthrough (see 10.3).
7. **Key decisions and trade-offs**: why native, why WebView rendering, why not sandboxed, signing approach, anything surprising.
8. **Known limitations** and ideas deliberately left out.

**`docs/DEVELOPMENT.md`**: how to build, run, debug, and test from the command line; how to add a new Markdown feature or change the styling; how to update bundled JS libraries; how to troubleshoot Quick Look and Launch Services (`qlmanage`, `lsregister`, `pluginkit`).

The **README** must link to both files.

### 10.3 Flow charts

Include a flow chart for each of these features, each with a numbered walkthrough underneath:

1. **Opening a file and window management**: Finder, Open dialog, drag-and-drop, or terminal → check whether the file is already open → focus existing window or create a new one.
2. **Rendering pipeline**: file read → front matter handling → Markdown to HTML → sanitize → WebView → highlight, TOC extraction, and theme. Mark which steps are shared with Quick Look.
3. **Live reload**: file watcher → event types (modify, atomic rename, delete, reappear) → debounce → re-render → restore scroll position, or show the banner.
4. **Link handling**: the decision tree for anchor, relative Markdown, other local file, external URL, and mailto.
5. **Quick Look preview**: Finder Space → extension → shared renderer → size cap → preview.
6. **Install script**: the steps of `scripts/install.sh`, including the failure paths and what each step changes.

**Important: MarkDwain does not render Mermaid.** The user will read these docs in MarkDwain itself, so a Mermaid code block would appear as plain text. Therefore:
- Produce each diagram as an **SVG image** committed under `docs/diagrams/`, and embed it in the docs with a relative image link, so it displays in MarkDwain, on GitHub, and anywhere else.
- Also commit the diagram **source** next to each image (Graphviz `.dot` or Mermaid `.mmd`, whichever tool actually works in the environment), plus the exact command that regenerates the SVG, documented in `docs/DEVELOPMENT.md`.
- If no diagram tool can be installed, hand-write the SVG, or fall back to clear ASCII diagrams inside code blocks. Never leave a diagram as an unrendered Mermaid block.
- Diagrams must be readable in both light and dark mode: use a white or neutral background rect, not a transparent one.

### 10.4 Keeping docs honest

Write the docs **after** the code is working, then re-read the code against them. Every file, class, dependency, and flow described must actually exist and behave as described. Update the docs in the same change as any later code change.

## 11. Acceptance checklist

Verify each item and report what you tested:

- [ ] `scripts/install.sh` works on a clean machine state and MarkDwain launches with the provided icon.
- [ ] Double-clicking a `.md` opens it in a new window; opening a second file opens a second window; same file twice focuses the existing window. No tabs anywhere.
- [ ] Tables, task lists, strikethrough, and highlighted code render correctly in light **and** dark mode.
- [ ] Editing the file in another editor (including one that saves atomically) updates the preview within about a second and keeps scroll position.
- [ ] Deleting the file shows the banner; restoring it resumes updates.
- [ ] Relative image displays. Relative `.md` link opens a new window and honors `#anchor`. External link opens the browser. Non-Markdown local link opens in its default app.
- [ ] TOC sidebar toggles with ⌃⌘S, click scrolls, current section highlights, state persists.
- [ ] ⌘+ / ⌘− / ⌘0 work, apply to all windows, and persist across launches.
- [ ] ⌘F finds text in the page, and ⌘G / ⇧⌘G move between matches.
- [ ] Space in Finder on a `.md` shows the Quick Look preview, in both appearances; a >2 MB file does not hang.
- [ ] MarkDwain can be chosen as the default for Markdown through Get Info > Change All and then opens `.md` on double-click.
- [ ] Every source file has a header, and all types and non-trivial functions have doc comments that explain the why of non-obvious decisions.
- [ ] `docs/ARCHITECTURE.md` and `docs/DEVELOPMENT.md` exist and cover everything in section 10.2.
- [ ] All six flow charts exist as SVG images, render correctly when `docs/ARCHITECTURE.md` is opened in MarkDwain itself (light and dark mode), and their sources and regeneration command are committed.
- [ ] The dependency table matches what is really bundled, with versions.
- [ ] README is accurate against what was actually built and links to the docs.
