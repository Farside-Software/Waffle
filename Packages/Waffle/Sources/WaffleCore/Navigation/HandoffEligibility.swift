import Foundation

/// Decides whether a pane address can be published as a Handoff or Spotlight
/// web page. `NSUserActivity.webpageURL` raises an Objective-C exception for
/// anything that is not http or https (for example `about:blank`), so every
/// caller must gate on this before assigning it.
public enum HandoffEligibility {
    /// The URL to publish as the activity's `webpageURL`, or nil when the
    /// address is empty, malformed, or not http/https.
    public static func webpageURL(for address: String) -> URL? {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host(percentEncoded: false)?.isEmpty == false
        else { return nil }
        return url
    }
}
