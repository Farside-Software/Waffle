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
    @State private var settled = false
    @State private var showsButton = OnboardingSplash.hasPlayedEntrance

    /// The launch storyboard's sizes: 160 pt, 200 pt in regular width.
    private var side: CGFloat { horizontalSizeClass == .regular ? 200 : 160 }

    var body: some View {
        ZStack {
            OnboardingStyle.background.ignoresSafeArea()

            GeometryReader { proxy in
                // Unfolded Duo: the text and Get Started take the left half and the mark the
                // right, so neither sits on the hinge and both halves are used. (The launch
                // screen starts at the true centre; the move is eased.)
                let hinge = proxy.foldCenterXIfAvailable
                let onFold = settled && hinge != nil
                let centerX = onFold ? (hinge! / 2) : proxy.size.width / 2
                let markX = onFold ? hinge! + (proxy.size.width - hinge!) / 2 : proxy.size.width / 2
                let markSide: CGFloat = onFold ? 300 : side
                // In a short window the Get Started button would cover the tagline: lift the mark and
                // text together just enough to keep them clear of it. Zero at every normal height.
                let lift = onFold ? 0 : max(0, side / 2 + 225 - proxy.size.height / 2)
                WaffleMark(bodyProgress: body0, rowProgress: rows, butterProgress: butter)
                    .frame(width: markSide, height: markSide)
                    .position(x: markX, y: proxy.size.height / 2 - lift)

                VStack(spacing: 14) {
                    Text("Waffle")
                        .font(onFold ? .system(size: 64, weight: .bold, design: .rounded) : .system(.largeTitle, design: .rounded, weight: .bold))
                        .accessibilityAddTraits(.isHeader)
                    Text("Browse the web in a grid, not in tabs.")
                        .font(onFold ? .title2 : .title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .accessibilityElement(children: .combine)
                .padding(.horizontal, 32)
                .frame(width: min(520, columnWidth(proxy)))
                .position(x: centerX, y: onFold ? proxy.size.height / 2 - 40 : proxy.size.height / 2 + side / 2 + 70 - lift)
                .opacity(showsText ? 1 : 0)
                .offset(y: showsText ? 0 : 10)
            }
            .ignoresSafeArea()

            GeometryReader { proxy in
                let centerX = settled ? (leftHalfCenter(proxy) ?? proxy.size.width / 2) : proxy.size.width / 2
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
                .frame(width: min(520, columnWidth(proxy)) - 64)
                .opacity(showsButton ? 1 : 0)
                .offset(y: showsButton ? 0 : 10)
                .position(x: centerX, y: proxy.size.height - 32 - 26)
            }
        }
        .onAppear(perform: runEntrance)
    }

    /// Centre of the half left of a vertical fold, in the geometry's space; nil without one.
    private func leftHalfCenter(_ proxy: GeometryProxy) -> CGFloat? {
        proxy.foldCenterXIfAvailable.map { $0 / 2 }
    }

    private func columnWidth(_ proxy: GeometryProxy) -> CGFloat {
        proxy.foldCenterXIfAvailable ?? proxy.size.width
    }

    private func runEntrance() {
        withAnimation(.easeInOut(duration: 0.5).delay(0.2)) { settled = true }
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
