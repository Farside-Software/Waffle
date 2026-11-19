//
//  OnboardingSplash.swift
//  WaffleFeatureOnboarding
//
//  The first screen on a fresh install, after Opalite's: the mark at the exact centre of the
//  screen (where the launch screen put it), the name and one line below, a single Get Started.
//  On first appearance the mark builds up: the waffle, its pockets row by row, the butter last.
//  Reduce Motion shows it complete.
//

#if os(iOS)
import SwiftUI
import WaffleDesignSystem

struct OnboardingSplash: View {
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private static var hasPlayedEntrance = false

    @State private var body0: CGFloat = OnboardingSplash.hasPlayedEntrance ? 1 : 0
    @State private var rows: [CGFloat] = OnboardingSplash.hasPlayedEntrance ? [1, 1, 1] : [0, 0, 0]
    @State private var butter: CGFloat = OnboardingSplash.hasPlayedEntrance ? 1 : 0
    @State private var showsText = OnboardingSplash.hasPlayedEntrance
    @State private var showsButton = OnboardingSplash.hasPlayedEntrance

    /// The launch storyboard's sizes: 160 pt, 200 pt in regular width.
    private var side: CGFloat { horizontalSizeClass == .regular ? 200 : 160 }

    var body: some View {
        ZStack {
            OnboardingStyle.background.ignoresSafeArea()

            GeometryReader { proxy in
                WaffleMark(bodyProgress: body0, rowProgress: rows, butterProgress: butter)
                    .frame(width: side, height: side)
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)

                VStack(spacing: 10) {
                    Text("Waffle")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .accessibilityAddTraits(.isHeader)
                    Text("Browse the web in a grid, not in tabs.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .accessibilityElement(children: .combine)
                .padding(.horizontal, 32)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2 + side / 2 + 70)
                .opacity(showsText ? 1 : 0)
                .offset(y: showsText ? 0 : 10)
            }
            .ignoresSafeArea()

            VStack {
                Spacer()
                Button(action: onContinue) {
                    HStack(spacing: 8) {
                        Text("Get Started")
                        Image(systemName: "arrow.right").accessibilityHidden(true)
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                }
                .onboardingPrimaryButton()
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("continueButton")
                .opacity(showsButton ? 1 : 0)
                .offset(y: showsButton ? 0 : 10)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .onAppear(perform: runEntrance)
    }

    private func runEntrance() {
        guard !Self.hasPlayedEntrance else { return }
        Self.hasPlayedEntrance = true
        guard !reduceMotion else {
            body0 = 1; rows = [1, 1, 1]; butter = 1; showsText = true; showsButton = true
            return
        }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { body0 = 1 }
        for index in rows.indices {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.3 + 0.16 * Double(index))) { rows[index] = 1 }
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.9)) { butter = 1 }
        withAnimation(.easeOut(duration: 0.4).delay(1.2)) { showsText = true }
        withAnimation(.easeOut(duration: 0.35).delay(1.35)) { showsButton = true }
    }
}
#endif
