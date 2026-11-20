//
//  BrandColors.swift
//  WaffleDesignSystem
//
//  The Waffle brand palette, defined in code so the colors resolve identically in every
//  module and in host `swift build` without asset-catalog symbol generation. Values
//  mirror the `.colorset`s in the app's asset catalog. Declared on
//  `ShapeStyle where Self == Color` so `.wafflePrimary` works both as a `Color` and
//  directly in `.foregroundStyle`/`.fill`/`.tint`.
//

import SwiftUI

public extension ShapeStyle where Self == Color {
    /// Warm waffle yellow — backgrounds and gradients.
    static var wafflePrimary: Color { Color(red: 0xF1 / 255, green: 0xE0 / 255, blue: 0x94 / 255) }

    /// Golden syrup brown — secondary accents.
    static var waffleSecondary: Color { Color(red: 0xDF / 255, green: 0xA6 / 255, blue: 0x56 / 255) }

    /// Dark roast brown — primary CTAs and toast chrome.
    static var waffleTertiary: Color { Color(red: 0x44 / 255, green: 0x20 / 255, blue: 0x1A / 255) }
}

#if canImport(UIKit)
import UIKit

public extension ShapeStyle where Self == Color {
    /// Ink for symbols on gold tiles: dark roast brown in light mode, the pale waffle yellow in dark.
    static var waffleInk: Color { Color(uiColor: waffleInkUIColor) }
}

/// Built outside any actor: SwiftUI resolves dynamic colours on its async render thread, and a
/// provider closure written inside a view body inherits the MainActor (the package default) and
/// traps there (`dispatch_assert_queue_fail`).
nonisolated private let waffleInkUIColor = UIColor { @Sendable traits in
    traits.userInterfaceStyle == .dark
        ? UIColor(red: 0xF1 / 255, green: 0xE0 / 255, blue: 0x94 / 255, alpha: 1)
        : UIColor(red: 0x44 / 255, green: 0x20 / 255, blue: 0x1A / 255, alpha: 1)
}
#endif
