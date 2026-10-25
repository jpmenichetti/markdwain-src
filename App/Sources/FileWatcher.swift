// FileWatcher.swift — detects changes to one file, including editors that save "atomically".
// Used by ViewerWindowController, which re-renders on `onChange` and shows a banner on `onMissing`.

import Foundation

/// Watches a single file for modification, replacement (atomic save), deletion and reappearance.
///
/// Why two watches: many editors save by writing a temp file and renaming it over the original. The original
/// inode vanishes, so a watch on the file alone goes deaf. We therefore watch the file (catches in-place
/// writes) AND its parent directory (catches renames/creates), and re-open the file watch whenever the
/// file's inode changes. Events are debounced 150 ms because one save often produces several events.
final class FileWatcher {
    private let url: URL
    private let onChange: () -> Void
    private let onMissing: () -> Void

    private var fileSource: DispatchSourceFileSystemObject?
    private var dirSource: DispatchSourceFileSystemObject?
    private var armedInode: UInt64?
    private var debounce: DispatchWorkItem?
    private var pollTimer: Timer?
    private var lastSignature: Signature?
    private var isMissing = false

    /// Identity of the file's current content: modification time, size and inode.
    private struct Signature: Equatable {
        let mtime: Date, size: Int, inode: UInt64
        init?(_ url: URL) {
            guard let a = try? FileManager.default.attributesOfItem(atPath: url.path),
                  let m = a[.modificationDate] as? Date, let s = a[.size] as? Int,
                  let i = a[.systemFileNumber] as? UInt64 else { return nil }
            mtime = m; size = s; inode = i
        }
    }

    /// - Parameters:
    ///   - onChange: file content probably changed (also fires when a deleted file reappears).
    ///   - onMissing: file was deleted or moved away.
    init(url: URL, onChange: @escaping () -> Void, onMissing: @escaping () -> Void) {
        self.url = url; self.onChange = onChange; self.onMissing = onMissing
        lastSignature = Signature(url)
        isMissing = lastSignature == nil
        arm()
        if isMissing { startPolling() }
    }

    deinit { stop() }

    /// Cancels all watches. Safe to call repeatedly.
    func stop() {
        debounce?.cancel(); pollTimer?.invalidate(); pollTimer = nil
        fileSource?.cancel(); dirSource?.cancel(); fileSource = nil; dirSource = nil
    }

    /// (Re)creates the file and directory watches as needed.
    private func arm() {
        if dirSource == nil { dirSource = makeSource(path: url.deletingLastPathComponent().path, mask: [.write, .delete, .rename]) }
        let inode = Signature(url)?.inode
        if fileSource == nil || inode != armedInode {
            fileSource?.cancel(); fileSource = nil
            if inode != nil {
                fileSource = makeSource(path: url.path, mask: [.write, .extend, .delete, .rename, .attrib])
                armedInode = inode
            }
        }
    }

    private func makeSource(path: String, mask: DispatchSource.FileSystemEvent) -> DispatchSourceFileSystemObject? {
        let fd = open(path, O_EVTONLY) // O_EVTONLY: watch without keeping the volume busy
        guard fd >= 0 else { return nil }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: mask, queue: .main)
        source.setEventHandler { [weak self] in self?.scheduleEvaluate() }
        source.setCancelHandler { close(fd) }
        source.resume()
        return source
    }

    private func scheduleEvaluate() {
        debounce?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.evaluate() }
        debounce = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: item)
    }

    /// Compares the file's current state to the last known one and notifies accordingly.
    private func evaluate() {
        arm()
        guard let sig = Signature(url) else {
            if !isMissing { isMissing = true; startPolling(); onMissing() }
            return
        }
        if isMissing || sig != lastSignature {
            isMissing = false
            pollTimer?.invalidate(); pollTimer = nil
            lastSignature = sig
            onChange()
        }
    }

    /// While the file is gone its directory may be gone too (no events possible), so poll once a second.
    private func startPolling() {
        guard pollTimer == nil else { return }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.evaluate() }
    }
}
