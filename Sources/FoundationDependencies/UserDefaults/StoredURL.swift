//
//  StoredURL.swift
//  foundation-dependencies
//
//  Created by Robert Nash on 27/08/2026.
//

import Foundation

/// How this package represents a `URL` inside a defaults store.
///
/// A URL is stored as its `absoluteString`, and read back by parsing that string and
/// requiring a scheme. Both stores use these two rules, so the URL endpoints agree
/// with each other for the same reason the string endpoints do, and a stored URL is
/// legible in a `plist` file rather than being an archive.
///
/// ## Why this is not `UserDefaults.url(forKey:)`
///
/// Foundation's own URL support is not one representation but two, and neither is one
/// this package should hand a caller. Measured against a real suite on macOS 26,
/// Swift 6.2.4:
///
/// - `set(_:forKey:)` given a **file** URL stores the bare path, so
///   `file:///tmp/thing.txt` is written as the string `/tmp/thing.txt`.
/// - `set(_:forKey:)` given any **other** URL stores 263 bytes of `NSKeyedArchiver`
///   output, so the value is unreadable in the `plist`, is an Objective-C archive
///   format rather than a property list shape, and comes back out of `data(forKey:)`
///   as that archive.
/// - `url(forKey:)` reading a **string** interprets it as a file path relative to the
///   process's working directory, whatever the string is. A key holding `"hello"`
///   reads back as `file:///…/hello`, and a key holding `"https://example.com/x"`
///   reads back as `https:/example.com/x -- file:///…/`, with the double slash
///   collapsed. There is no input for which that endpoint returns `nil` except an
///   empty string and a non-string value.
///
/// The last of those is the one that decided it. A reader whose failure mode is a
/// plausible wrong answer rather than `nil` is worse than no reader, and the first two
/// mean a URL's storage shape depends on a property of the URL the caller did not
/// choose. `absoluteString` is one representation for both kinds, round trips exactly
/// — including spaces, credentials, ports, queries and fragments, all measured — and
/// makes ``UserDefaultsClient/url`` and ``UserDefaultsClient/string`` two readings of
/// the same stored text rather than two unrelated formats.
///
/// The cost is stated rather than hidden: a URL written by `UserDefaults` itself, or
/// by an Objective-C component calling `set(_:forKey:)`, does not read back through
/// ``UserDefaultsClient/url``. A file URL written that way is a bare path, which has
/// no scheme and so reads as `nil`. There is no representation that interoperates
/// with both of Foundation's, because they are not the same as each other.
enum StoredURL {

    /// The text stored for `url`.
    static func text(for url: URL) -> String {
        url.absoluteString
    }

    /// The URL a stored string reads as, or `nil` when it is not an absolute URL.
    ///
    /// The scheme is what the requirement rests on. `URL(string:)` accepts almost
    /// anything, percent-encoding what it cannot use — `"not a url at all"` parses,
    /// and so does `"42"` — and returns a relative URL with no scheme for each. A
    /// caller asking a key for a URL wants one it can open, so a reading with no
    /// scheme is not a reading.
    static func url(from text: String) -> URL? {
        guard let url = URL(string: text), url.scheme != nil else {
            return nil
        }
        return url
    }
}
