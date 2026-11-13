//
//  ReviewMilestonePolicy.swift
//  WaffleCore
//
//  Decides when to ask for an App Store review. Waffle asks at a value moment instead of
//  the old fifth launch: when the user saves their second preset, or the first time a
//  3x3-or-larger grid is shown, or when a saved layout is opened for the third time — and
//  never more than once per app version. The `record…` calls only count and say whether a
//  moment is eligible; the caller delivers the prompt later (after the toast, never during
//  a paywall or error) and then calls `claimPrompt(for:)`. Counters live behind
//  `KeyValueStoring` so the policy is host-testable with a fake store.
//

import Foundation

@MainActor
public struct ReviewMilestonePolicy {

    public enum Keys {
        public static let presetSaveCount = "reviewPresetSaveCount"
        public static let layoutOpenCount = "reviewLayoutOpenCount"
        public static let hasOpenedLargeGrid = "reviewHasOpenedLargeGrid"
        public static let lastPromptedVersion = "lastReviewPromptVersion"
    }

    /// The preset save (1-based) that earns a prompt.
    public static let presetSaveMilestone = 2
    /// The saved-layout open (1-based) that earns a prompt.
    public static let layoutOpenMilestone = 3
    /// A grid counts as "large" when both dimensions reach this.
    public static let largeGridMinimum = 3

    private let defaults: any KeyValueStoring

    public init(defaults: any KeyValueStoring = UserDefaults.standard) {
        self.defaults = defaults
    }

    public var presetSaveCount: Int { defaults.integer(forKey: Keys.presetSaveCount) }
    public var layoutOpenCount: Int { defaults.integer(forKey: Keys.layoutOpenCount) }
    public var hasOpenedLargeGrid: Bool { defaults.bool(forKey: Keys.hasOpenedLargeGrid) }
    public var lastPromptedVersion: String? { defaults.string(forKey: Keys.lastPromptedVersion) }

    /// Records a saved preset. Returns true when this save is a review moment.
    @discardableResult
    public func recordPresetSaved(appVersion: String) -> Bool {
        let count = presetSaveCount + 1
        defaults.set(count, forKey: Keys.presetSaveCount)
        return count == Self.presetSaveMilestone && lastPromptedVersion != appVersion
    }

    /// Records that a saved layout was opened (restored or applied). Returns true the third time.
    @discardableResult
    public func recordLayoutOpened(appVersion: String) -> Bool {
        let count = layoutOpenCount + 1
        defaults.set(count, forKey: Keys.layoutOpenCount)
        return count == Self.layoutOpenMilestone && lastPromptedVersion != appVersion
    }

    /// Records that a `rows`x`cols` grid was shown. Returns true the first time a large
    /// grid appears (and this version hasn't prompted yet).
    @discardableResult
    public func recordGridShown(rows: Int, cols: Int, appVersion: String) -> Bool {
        guard rows >= Self.largeGridMinimum, cols >= Self.largeGridMinimum else { return false }
        guard !hasOpenedLargeGrid else { return false }
        defaults.set(true, forKey: Keys.hasOpenedLargeGrid)
        return lastPromptedVersion != appVersion
    }

    /// Marks `appVersion` as prompted. Returns false when it already was (nothing to ask).
    public func claimPrompt(for appVersion: String) -> Bool {
        guard lastPromptedVersion != appVersion else { return false }
        defaults.set(appVersion, forKey: Keys.lastPromptedVersion)
        return true
    }
}
