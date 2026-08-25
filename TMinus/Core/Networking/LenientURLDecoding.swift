//
//  LenientURLDecoding.swift
//  TMinus
//

import Foundation

// MARK: - LenientURLDecoding

/// Repairs a URL string that fails to parse as-is, real API responses have been observed to
/// return URLs containing characters (unescaped spaces, non-ASCII text) that `URL(string:)`
/// rejects outright. Shared between `LaunchDTOMapper` and `NewsArticleDTOMapper`, which
/// previously each hand-rolled an identical trim/parse/percent-encode-and-retry sequence, a fix
/// or improvement to URL repair only had to be made once here instead of twice, in sync.
enum LenientURLDecoding {
    /// Broader repair than escaping a single known-bad character: percent-encodes anything
    /// outside the standard URL-allowed set, keeping "%" itself untouched so an already-escaped
    /// sequence (e.g. a correct "%20") isn't double-encoded into "%2520".
    private static let urlAllowedCharacters: CharacterSet = {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.formUnion(.urlPathAllowed)
        allowed.formUnion(.urlHostAllowed)
        allowed.insert(charactersIn: "%")
        return allowed
    }()

    /// Trims whitespace, tries a direct parse, then falls back to percent-encoding anything
    /// outside `urlAllowedCharacters` and retrying, returns `nil` only if the string is empty
    /// after trimming, has no `http`/`https` scheme, or is unparseable even after repair.
    ///
    /// The scheme check matters as much as the parsing itself: `URL(string:)` happily accepts
    /// arbitrary schemeless text as a "valid" relative URL, `URL(string: "N/A")` and
    /// `URL(string: "TBD")` both succeed, so a third-party API's placeholder value for a missing
    /// image/webcast/article link would otherwise survive as a non-nil `URL` that every caller of
    /// this type treats as a real, openable link.
    static func url(from string: String?) -> URL? {
        guard let string else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }
        if let url = URL(string: trimmed), hasWebScheme(url) {
            return url
        }
        guard let escaped = trimmed.addingPercentEncoding(withAllowedCharacters: urlAllowedCharacters),
              let url = URL(string: escaped),
              hasWebScheme(url)
        else { return nil }
        return url
    }

    private static func hasWebScheme(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }
}
