# MarkDwain

A tiny, read-only Markdown viewer for macOS. Double-click a `.md` file and it opens in its own window; press Space on a `.md` file in Finder for a Quick Look preview. Dark and light mode, live reload when the file changes, table of contents, zoom, find.

## What you need

- A Mac with macOS 14 (Sonoma) or newer (Apple Silicon or Intel).
- **Xcode** (the full app from the App Store, not just the command line tools). Open it once and accept the license. If needed run `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`.
- [Homebrew](https://brew.sh) is used only to install XcodeGen if you don't have it.

## Install (one command)

```bash
git clone <this repository> markdwain && cd markdwain
scripts/install.sh
```

It builds the app and puts `MarkDwain.app` in `/Applications`, and turns on the Quick Look extension. Repeat on your second Mac.

**Update:** `git pull && scripts/install.sh`  **Uninstall:** `scripts/uninstall.sh` (add `--purge` to also delete settings and build files).

## Make MarkDwain open all `.md` files

1. In Finder select any `.md` file and press ⌘I (Get Info).
2. Under **Open with**, choose **MarkDwain**.
3. Click **Change All…** and confirm.

## Quick Look

Select a `.md` file in Finder and press Space. If you get plain text instead:

```bash
qlmanage -r && qlmanage -r cache
pluginkit -e use -i local.markdwain.quicklook
qlmanage -p Samples/feature-tour.md      # test from the terminal
```

If another app already previews Markdown it may take priority: turn it off in System Settings > Privacy & Security > Extensions > Quick Look.

## Using it

| | |
|---|---|
| Open | ⌘O, double-click, drag onto the Dock icon or a window, `open file.md` |
| Find / next / previous | ⌘F / ⌘G / ⇧⌘G |
| Table of contents | ⌃⌘S or the toolbar button (hidden if the document has no headings) |
| Zoom | ⌘+ / ⌘− / ⌘0 (50-300 %, applies to all windows, remembered) |
| Reveal in Finder / Open With… | ⇧⌘R / File menu (to jump to an editor) |

Every file gets its own window; opening the same file again focuses its window. Links to other `.md` files open in a new window; web links open in your browser.

## Signing: what actually worked

The project uses an ad-hoc signature ("Sign to Run Locally"), so **no Apple account is needed**. On the Mac where this was built (macOS 26, Apple Silicon), the app launched and opened files, and `pluginkit` registered and enabled the extension with that signature; `qlmanage -p` started the extension. Nothing expires. If on your other Mac the extension doesn't show up, the fallback is to sign with a free "Personal Team" Apple ID in Xcode (such signatures expire after 7 days and need a rebuild), but this wasn't needed here.

Building on each Mac with `scripts/install.sh` is the recommended way; the next section covers a Mac without Xcode.

## Install on a Mac without Xcode

The build is universal (Apple Silicon and Intel), so you can copy the finished app. Needs macOS 14 or newer. This was tested on a second Mac.

1. **On the Mac that has the app**, make a zip (use `ditto`, not Finder's Compress, so the signature survives):
   ```bash
   cd /Applications && ditto -c -k --keepParent MarkDwain.app ~/Desktop/MarkDwain.zip
   ```
   Move the zip to the other Mac (AirDrop, USB stick, cloud drive).
2. **On the other Mac**, double-click the zip, then drag `MarkDwain.app` into the Applications folder in Finder. (Copying with Terminal's `ditto` straight into `/Applications` can fail with "Operation not permitted" because macOS protects that folder.)
3. In Terminal, run:
   ```bash
   xattr -dr com.apple.quarantine /Applications/MarkDwain.app
   /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/MarkDwain.app
   pluginkit -a "/Applications/MarkDwain.app/Contents/PlugIns/MarkDwain Quick Look.appex"
   pluginkit -e use -i local.markdwain.quicklook
   qlmanage -r && qlmanage -r cache
   ```
   The `xattr` line is needed because the app has an ad-hoc signature; without it macOS says the app is damaged or from an unidentified developer. If a command says "Operation not permitted", allow Terminal under System Settings > Privacy & Security > App Management (or Full Disk Access), reopen Terminal and retry.
4. Set MarkDwain as the default for `.md` files (see above). If Space doesn't show a preview, tick MarkDwain under System Settings > Privacy & Security > Extensions > Quick Look.

After each rebuild you need to repeat the copy; with Xcode installed, `git pull && scripts/install.sh` is easier.

## Known limitations

- Quick Look previews cannot show relative (local) images, because Quick Look extensions are sandboxed (deliberately not weakened). They are static: no sidebar, live reload or working links, and capped at 2 MB of text.
- Read-only by design. No tabs, printing/PDF, math or Mermaid (a Mermaid block shows as plain code).
- GitHub extras such as alert blocks (`> [!NOTE]`) and emoji shortcodes are not rendered.

## Documentation

- [Architecture](docs/ARCHITECTURE.md): components, dependencies, flows with diagrams, decisions.
- [Development guide](docs/DEVELOPMENT.md): build, test, change styling or features, update libraries, troubleshooting.

Try [Samples/feature-tour.md](Samples/feature-tour.md) to see every feature.
