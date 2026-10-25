// TextLoader.swift — reads a Markdown file as text, tolerating bad encodings and optionally capping size.
// Used by the app (full file) and the Quick Look extension (2 MB cap).

import Foundation

enum TextLoader {
    /// Reads `url` as UTF-8; invalid bytes become U+FFFD instead of failing (spec: lossy fallback).
    /// - Parameter maxBytes: stop reading after this many bytes; `truncated` is then true.
    /// - Returns: nil if the file can't be opened (missing, unreadable).
    static func load(_ url: URL, maxBytes: Int? = nil) -> (text: String, truncated: Bool)? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        let limit = maxBytes ?? Int.max
        // Read one byte more than the cap so we can tell "exactly at cap" from "over cap".
        guard let data = try? handle.read(upToCount: limit == Int.max ? limit : limit + 1) else { return nil }
        let truncated = data.count > limit
        // A cut in the middle of a multi-byte character just yields one replacement character.
        return (String(decoding: truncated ? data.prefix(limit) : data, as: UTF8.self), truncated)
    }
}
