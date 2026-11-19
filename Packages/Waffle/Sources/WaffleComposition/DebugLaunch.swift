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

#if os(iOS) && DEBUG
import WaffleFeatureSidebar

/// `-WaffleDebugSeedLibrary YES` fills an empty library with sample bookmarks and saved
/// layouts (public pages only) so store screenshots need no taps.
enum DebugLibrarySeeding {
    @MainActor
    static func applyIfRequested(to sidebar: SidebarModel) {
        guard UserDefaults.standard.bool(forKey: "WaffleDebugSeedLibrary") else { return }
        sidebar.load()
        if sidebar.bookmarks.isEmpty {
            let marks: [(String, String)] = [
                ("NASA Image of the Day", "https://www.nasa.gov/image-of-the-day/"),
                ("OpenStreetMap", "https://www.openstreetmap.org/"),
                ("Wikipedia", "https://en.wikipedia.org/"),
                ("NWS Radar", "https://radar.weather.gov/"),
                ("Earth Observatory", "https://earthobservatory.nasa.gov/"),
                ("James Webb Space Telescope", "https://science.nasa.gov/mission/webb/"),
            ]
            for (title, url) in marks { sidebar.addBookmark(urlString: url, title: title) }
        }
        if sidebar.presets.isEmpty {
            let a = "https://www.nasa.gov/image-of-the-day/", b = "https://www.openstreetmap.org/#map=12/41.8781/-87.6298"
            let c = "https://radar.weather.gov/", d = "https://en.wikipedia.org/wiki/Aurora"
            let e = "https://science.nasa.gov/mission/webb/", f = "https://earthobservatory.nasa.gov/"
            sidebar.savePreset(named: "Morning check", rows: 1, cols: 2, urls: [a, b], paneCount: 2, paneRatios: [0.5])
            sidebar.savePreset(named: "Weather watch", rows: 2, cols: 2, urls: [c, d, b, a], paneCount: 4, paneRatios: [])
            sidebar.savePreset(named: "Space and Earth", rows: 1, cols: 2, urls: [e, f], paneCount: 2, paneRatios: [0.5])
        }
        sidebar.load()
    }
}
#endif
