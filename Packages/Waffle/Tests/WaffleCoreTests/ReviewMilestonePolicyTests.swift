//
//  ReviewMilestonePolicyTests.swift
//  WaffleCoreTests
//

import Foundation
import Testing
import WaffleCore

private final class FakeKeyValueStore: KeyValueStoring {
    private(set) var storage: [String: Any] = [:]
    func data(forKey defaultName: String) -> Data? { storage[defaultName] as? Data }
    func string(forKey defaultName: String) -> String? { storage[defaultName] as? String }
    func bool(forKey defaultName: String) -> Bool { storage[defaultName] as? Bool ?? false }
    func integer(forKey defaultName: String) -> Int { storage[defaultName] as? Int ?? 0 }
    func set(_ value: Any?, forKey defaultName: String) { storage[defaultName] = value }
    func removeObject(forKey defaultName: String) { storage.removeValue(forKey: defaultName) }
}

@Suite("ReviewMilestonePolicy")
@MainActor
struct ReviewMilestonePolicyTests {

    @Test("second saved preset prompts, first and third do not")
    func secondPresetPrompts() {
        let policy = ReviewMilestonePolicy(defaults: FakeKeyValueStore())
        #expect(policy.recordPresetSaved(appVersion: "1.5.0") == false)
        #expect(policy.recordPresetSaved(appVersion: "1.5.0") == true)
        #expect(policy.recordPresetSaved(appVersion: "1.5.0") == false)
        #expect(policy.presetSaveCount == 3)
        #expect(policy.lastPromptedVersion == nil, "recording never claims; delivery does")
    }

    @Test("first 3x3+ grid prompts once; smaller grids never do")
    func largeGridPromptsOnce() {
        let policy = ReviewMilestonePolicy(defaults: FakeKeyValueStore())
        #expect(policy.recordGridShown(rows: 2, cols: 2, appVersion: "1.5.0") == false)
        #expect(policy.recordGridShown(rows: 3, cols: 2, appVersion: "1.5.0") == false)
        #expect(policy.recordGridShown(rows: 3, cols: 3, appVersion: "1.5.0") == true)
        #expect(policy.hasOpenedLargeGrid)
        #expect(policy.recordGridShown(rows: 4, cols: 4, appVersion: "1.6.0") == false)
    }

    @Test("third open of a saved layout prompts")
    func thirdLayoutOpenPrompts() {
        let policy = ReviewMilestonePolicy(defaults: FakeKeyValueStore())
        #expect(policy.recordLayoutOpened(appVersion: "1.5.0") == false)
        #expect(policy.recordLayoutOpened(appVersion: "1.5.0") == false)
        #expect(policy.recordLayoutOpened(appVersion: "1.5.0") == true)
        #expect(policy.recordLayoutOpened(appVersion: "1.5.0") == false)
        #expect(policy.layoutOpenCount == 4)
    }

    @Test("claiming marks the version and refuses a second claim")
    func claimOncePerVersion() {
        let policy = ReviewMilestonePolicy(defaults: FakeKeyValueStore())
        #expect(policy.claimPrompt(for: "1.5.0") == true)
        #expect(policy.claimPrompt(for: "1.5.0") == false)
        #expect(policy.claimPrompt(for: "1.6.0") == true)
    }

    @Test("a claimed version blocks every milestone")
    func oncePerVersion() {
        let policy = ReviewMilestonePolicy(defaults: FakeKeyValueStore())
        #expect(policy.recordGridShown(rows: 3, cols: 3, appVersion: "1.5.0") == true)
        _ = policy.claimPrompt(for: "1.5.0")
        _ = policy.recordPresetSaved(appVersion: "1.5.0")
        #expect(policy.recordPresetSaved(appVersion: "1.5.0") == false)
        _ = policy.recordLayoutOpened(appVersion: "1.5.0")
        _ = policy.recordLayoutOpened(appVersion: "1.5.0")
        #expect(policy.recordLayoutOpened(appVersion: "1.5.0") == false)
    }

    @Test("a milestone reached on a later version prompts again")
    func newVersionPromptsAgain() {
        let policy = ReviewMilestonePolicy(defaults: FakeKeyValueStore())
        #expect(policy.recordGridShown(rows: 3, cols: 3, appVersion: "1.5.0") == true)
        _ = policy.claimPrompt(for: "1.5.0")
        _ = policy.recordPresetSaved(appVersion: "1.6.0")
        #expect(policy.recordPresetSaved(appVersion: "1.6.0") == true)
    }
}
