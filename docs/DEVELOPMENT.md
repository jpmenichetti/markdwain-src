# Development Guide

All commands run from the repository root. Prerequisites: full Xcode, XcodeGen (`brew install xcodegen`), Node.js (only for the renderer test and for updating libraries), Graphviz (only to regenerate diagrams).

## Build, run, debug

```bash
xcodegen generate                      # creates MarkDwain.xcodeproj from project.yml
xcodebuild -project MarkDwain.xcodeproj -scheme MarkDwain -configuration Debug -derivedDataPath build build
open -a "$PWD/build/Build/Products/Debug/MarkDwain.app" Samples/feature-tour.md
```

- You can also open `MarkDwain.xcodeproj` in Xcode and press Run. Never edit the `.xcodeproj` by hand; change `project.yml` and regenerate.
- Debugging the page: JS errors don't show up anywhere by default. Temporarily set `webView.isInspectable = true` in `ViewerWindowController.init`, run the Debug build, then use Safari > Develop > (your Mac) > the page.
- Release build with both CPU types: `scripts/install.sh` does it; the product ends up in `build/Build/Products/Release/`.

## Tests

| Command | What it checks |
|---|---|
| `node tests/render-test.js` | Markdown pipeline: tables, task lists, strikethrough, highlighting, slugs, front matter, footnotes. |
| `tests/watcher/run.sh` | FileWatcher: in-place write, atomic save (twice), delete, reappear. |
| `tests/snapshot/run.sh Samples/feature-tour.md out.png dark sidebar` | Renders a file offscreen through the real `PageBuilder` and saves a PNG (`light`/`dark`, optional `sidebar`). Also prints DOM facts (tables, images loaded, TOC entries); an extra `"js:<script>"` argument runs JavaScript in the page and prints the result (used to test scrolling, TOC and sanitizing). Use it to look at styling without opening the app. |

## Adding a Markdown feature or changing the styling

- **Styling**: edit `Shared/Web/viewer.css`. Colours are CSS variables at the top (light and dark sets). Verify with the snapshot tool in both modes.
- **A markdown-it plugin**: put its browser build in `Shared/Web/vendor/`, add it to the `libs` list in `Shared/Swift/PageBuilder.swift` (before `render.js`), call `md.use(...)` in `getMd()` in `render.js`, add an assertion to `tests/render-test.js`, and add it to the dependency table in ARCHITECTURE.md.
- **Allowing an HTML tag/attribute** that DOMPurify strips: adjust the options in `render()` in `render.js`.
- **Page behaviour** (TOC, links, banners): `Shared/Web/viewer.js`. Calls from Swift are the functions on `window.MarkDwain` (`boot`, `update`, `setSidebar`, `setMissing`, `scrollToId`).
- Changes in `Shared/` apply to both the app and Quick Look. Keep the docs in this folder in sync in the same change.

## Updating bundled libraries

Download the browser (UMD/minified) build and overwrite the file in `Shared/Web/vendor/`. Examples using npm:

```bash
npm pack markdown-it@15.0.3 && tar xzf markdown-it-*.tgz && cp package/dist/browser/markdown-it.umd.min.js Shared/Web/vendor/markdown-it.min.js
npm pack markdown-it-anchor && tar xzf markdown-it-anchor-*.tgz && cp package/dist/markdownItAnchor.umd.js Shared/Web/vendor/
npm pack dompurify && tar xzf dompurify-*.tgz && cp package/dist/purify.min.js Shared/Web/vendor/
```

markdown-it-task-lists, markdown-it-footnote and highlight.js (common build plus the two `styles/github*.min.css`) come from their npm packages or the highlight.js CDN builds the same way. After updating, run `node tests/render-test.js`, look at a snapshot, and update the version column in ARCHITECTURE.md (the version is in the comment header of each file).

## Regenerating the diagrams

Each diagram's source is `docs/diagrams/<name>.dot`; the committed `.svg` is what the docs show.

```bash
scripts/make-diagrams.sh        # runs: dot -Tsvg <name>.dot -o <name>.svg for every .dot file
```

Diagrams use an explicit white background so they read well in light and dark mode. MarkDwain does not render Mermaid, so do not use Mermaid blocks in these docs.

## Troubleshooting Quick Look and Launch Services

```bash
qlmanage -p Samples/feature-tour.md      # open a Quick Look preview from the terminal
qlmanage -r ; qlmanage -r cache          # reset Quick Look and its cache
pluginkit -m -v -i local.markdwain.quicklook     # is the extension registered? "+" = enabled, "-" = disabled
pluginkit -e use -i local.markdwain.quicklook    # enable it (use "ignore" to disable)
pluginkit -m -p com.apple.quicklook.preview      # all preview extensions; another app may handle Markdown too
LSR=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
$LSR -f /Applications/MarkDwain.app      # re-register the app (document types, icon)
$LSR -dump | grep -i -B2 -A8 markdwain   # inspect what Launch Services knows
mdls -name kMDItemContentType file.md    # which UTI a file has (should be net.daringfireball.markdown)
```

If another app also previews Markdown, the one System Settings > Privacy & Security > Extensions > Quick Look lists first wins; untick the other one. Launch-time problems with the default app: Finder > Get Info > Open with > Change All again.
