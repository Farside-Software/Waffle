//
//  WaffleCard.swift
//  WaffleDesignSystem
//
//  The one card surface: a rounded (20 pt, continuous) panel in the system's secondary
//  background, plus the small gold symbol tile that goes before a title. Onboarding, Syrup and
//  the sidebar share them so no screen invents its own radius or tint.
//

#if os(iOS)
import SwiftUI
import UIKit

public enum WaffleCardStyle {
    public static let cornerRadius: CGFloat = 20
}

public extension View {
    /// Wraps content in the Waffle card surface.
    func waffleCard(padding: CGFloat = 16) -> some View {
        self.padding(padding)
            .background(
                Color(uiColor: .secondarySystemBackground),
                in: RoundedRectangle(cornerRadius: WaffleCardStyle.cornerRadius, style: .continuous)
            )
    }
}

/// A symbol on a soft gold tile, the way onboarding marks a feature row.
public struct WaffleSymbolTile: View {
    private let systemImage: String
    private let side: CGFloat

    public init(systemImage: String, side: CGFloat = 36) {
        self.systemImage = systemImage
        self.side = side
    }

    public var body: some View {
        Image(systemName: systemImage)
            .font(.body.weight(.semibold))
            .symbolRenderingMode(.hierarchical)
            // Dark brown on light, the pale gold on dark.
            .foregroundStyle(Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
                ? UIColor(red: 0xF1 / 255, green: 0xE0 / 255, blue: 0x94 / 255, alpha: 1)
                : UIColor(red: 0x44 / 255, green: 0x20 / 255, blue: 0x1A / 255, alpha: 1) }))
            .frame(width: side, height: side)
            .background(Color.waffleSecondary.opacity(0.28), in: RoundedRectangle(cornerRadius: side * 0.28, style: .continuous))
            .accessibilityHidden(true)
    }
}
#endif
