//
//  DebugLaunch.swift
//  WaffleComposition
//
//  DEBUG-only launch arguments for reaching iPad states in the simulator without taps.
//  Compiled out of Release builds. (The phone workspace has its own in `FoldSensing.swift`
//  and `PhoneMainView`: `-WaffleDebugPanes`, `-WaffleDebugSheet`.)
//
//  - `-WaffleDebugGrid "2x2|https://a,https://b,..."` fills the iPad grid (rows x cols, then
//    the addresses in reading order). Bypasses gating.
//  - Addresses may be `empty`, `error` or `refused` to seed a start page or a failed load.
//  - `-WaffleDebugSheet settings|syrup|rearrange` opens that sheet on iPad.
//

#if os(iOS) && DEBUG
import Foundation
import WaffleCore
import WaffleFeatureGrid

enum DebugGridSeeding {
    @MainActor
    static func applyIfRequested(to grid: GridModel) {
        guard let spec = UserDefaults.standard.string(forKey: "WaffleDebugGrid") else { return }
        let parts = spec.split(separator: "|", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return }
        let size = parts[0].lowercased().split(separator: "x").compactMap { Int($0) }
        guard size.count == 2, size[0] > 0, size[1] > 0 else { return }
        let urls = DebugAddressTokens.expand(parts[1].split(separator: ",").map(String.init))
        grid.apply(snapshot: Snapshot(rows: size[0], cols: size[1], urls: urls, selectedIndex: 0))
    }
}
#endif
