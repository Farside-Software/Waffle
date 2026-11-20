//
//  OnboardingStyle.swift
//  WaffleFeatureOnboarding
//
//  Shared look of the tour, after Opalite's: the plain grouped background, a card surface for
//  grouped content, a tinted symbol tile, and Waffle's gold as the accent.
//

#if os(iOS)
import SwiftUI
import UIKit
import WaffleDesignSystem

enum OnboardingStyle {
    static let readableWidth: CGFloat = 560
    static let cardRadius: CGFloat = 20

    /// Gold-brown ink for symbols and the active page dot: dark brown on light, the pale gold on dark.
    static var ink: Color { .waffleInk }

    /// The launch screen's colour: the grouped background, so the handoff has no flash.
    static var background: Color { Color(uiColor: .systemGroupedBackground) }
}

private struct DemoFillsKey: EnvironmentKey { static let defaultValue = false }

extension EnvironmentValues {
    /// The unfolded Duo: a demo fills the height of its half instead of staying a small card.
    var demoFills: Bool {
        get { self[DemoFillsKey.self] }
        set { self[DemoFillsKey.self] = newValue }
    }
}

extension View {
    func onboardingCard(padding: CGFloat = 0) -> some View {
        self.padding(padding)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: OnboardingStyle.cardRadius, style: .continuous))
    }

    /// The single full-width primary action.
    func onboardingPrimaryButton() -> some View {
        self.buttonStyle(.wafflePrimary)
            .controlSize(.large)
    }
}

/// Where a selected cell gets the app's real selection treatment: a gold stroke and soft glow.
struct SelectionOutline: ViewModifier {
    let isSelected: Bool
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(isSelected ? Color.waffleSecondary : .clear, lineWidth: 3)
                    .shadow(color: isSelected ? Color.waffleSecondary.opacity(0.5) : .clear, radius: 6)
            }
            .scaleEffect(isSelected ? 1.02 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isSelected)
    }
}

extension View {
    func selectionOutline(_ isSelected: Bool, cornerRadius: CGFloat = 12) -> some View {
        modifier(SelectionOutline(isSelected: isSelected, cornerRadius: cornerRadius))
    }
}
#endif
