//
//  PresetShare.swift
//  WaffleCore
//
//  Plain-text share payload for a preset: the `waffle://preset/<uuid>` deep link (opens
//  the preset on any of the user's devices via CloudKit sync) followed by the page URLs
//  so the list is useful to anyone without Waffle, with a get-Waffle link on its own line
//  so someone without the app can install it.
//

import Foundation

nonisolated public enum PresetShare {
    /// Where someone without Waffle can get it; `ct` attributes installs to shared layouts.
    public static let getWaffleLink = "https://molargiksoftware.com/go/waffle?ct=share_layout"

    /// Share text for a preset's name, layout and URLs.
    public static func text(name: String, id: UUID, rows: Int, cols: Int, urls: [String]) -> String {
        var lines: [String] = []
        let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
        lines.append(title.isEmpty ? "Waffle preset (\(rows)x\(cols))" : "\(title) (\(rows)x\(cols))")
        lines.append(DeepLink.openPreset(id).url.absoluteString)
        lines.append(getWaffleLink)
        let pages = urls.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if !pages.isEmpty {
            lines.append("")
            lines.append(contentsOf: pages)
        }
        return lines.joined(separator: "\n")
    }
}

public extension PresetShare {
    static func text(for preset: Preset) -> String {
        guard preset.paneCount > 0 else {
            return text(name: preset.name, id: preset.id, rows: preset.rows, cols: preset.cols, urls: preset.urls)
        }
        // A layout saved on iPhone or iPhone Duo: panes, not a grid.
        var lines: [String] = []
        let title = preset.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let panes = preset.paneCount == 1 ? "1 pane" : "\(preset.paneCount) panes"
        lines.append(title.isEmpty ? "Waffle layout (\(panes))" : "\(title) (\(panes))")
        lines.append(DeepLink.openPreset(preset.id).url.absoluteString)
        lines.append(PresetShare.getWaffleLink)
        let pages = preset.urls.prefix(preset.paneCount)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if !pages.isEmpty {
            lines.append("")
            lines.append(contentsOf: pages)
        }
        return lines.joined(separator: "\n")
    }
}
