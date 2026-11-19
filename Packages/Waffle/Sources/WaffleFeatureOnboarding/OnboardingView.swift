//
//  OnboardingView.swift
//  WaffleFeatureOnboarding
//
//  First-run tour, laid out like Opalite's: a splash with the mark and one button, then paged
//  pages under a row of page dots, Back and Skip as toolbar items, and a single Continue pinned
//  below. Each page puts a small live grid or set of panes in the user's hands.
//

#if os(iOS)
import SwiftUI
import WaffleCore
import WaffleDesignSystem

public struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var done = false

    @State private var pageIndex = 0
    @State private var showsSplash = true
    @State private var goingForward = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let variant: OnboardingVariant
    private let pages: [OnboardingPage]

    /// Invoked once the tour ends (the iPad session then presents the Syrup sheet; the
    /// phone session does not, since the user has not used the app yet).
    private let onFinished: () -> Void

    public init(variant: OnboardingVariant = .iPad, onFinished: @escaping () -> Void) {
        self.variant = variant
        self.pages = OnboardingPage.pages(for: variant)
        self.onFinished = onFinished
        #if DEBUG
        // Simulator screenshots without taps: `-WaffleDebugOnboardingPage 2` opens the third
        // page; leave it out for the splash.
        if UserDefaults.standard.object(forKey: "WaffleDebugOnboardingPage") != nil {
            let start = UserDefaults.standard.integer(forKey: "WaffleDebugOnboardingPage")
            _pageIndex = State(initialValue: min(max(start, 0), pages.count - 1))
            _showsSplash = State(initialValue: false)
        }
        #endif
    }

    public var body: some View {
        Group {
            if showsSplash {
                OnboardingSplash { withAnimation(.easeInOut(duration: 0.3)) { showsSplash = false } }
                    .transition(.opacity)
            } else {
                tour.transition(.opacity)
            }
        }
    }

    private var isLast: Bool { pageIndex == pages.count - 1 }

    private var tour: some View {
        NavigationStack {
            ZStack {
                OnboardingStyle.background.ignoresSafeArea()
                GeometryReader { proxy in
                    if OnboardingPageView.isWide(proxy.size) {
                        // Wide and short (iPad landscape, the unfolded Duo): the page owns the
                        // dots and Continue so they sit in the text column, off the hinge.
                        OnboardingPageView(
                            page: pages[pageIndex], probe: LayoutProbe(proxy), size: proxy.size,
                            indicator: AnyView(pageIndicator), footer: AnyView(continueButton(inColumn: true))
                        )
                        .id(pageIndex)
                        .transition(pageTransition)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        .simultaneousGesture(swipe)
                    } else {
                        VStack(spacing: 0) {
                            pageIndicator
                                .padding(.top, 4)
                                .padding(.bottom, 8)
                            GeometryReader { inner in
                                OnboardingPageView(page: pages[pageIndex], probe: LayoutProbe(inner), size: inner.size)
                                    .id(pageIndex)
                                    .transition(pageTransition)
                                    .frame(width: inner.size.width, height: inner.size.height)
                                    .clipped()
                                    .simultaneousGesture(swipe)
                            }
                            continueButton(inColumn: false)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if pageIndex > 0 {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { go(-1) } label: { Label("Back", systemImage: "chevron.backward") }
                            .accessibilityIdentifier("backButton")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { finish() } label: { Label("Skip", systemImage: "forward.end") }
                        .accessibilityHint(Text("Skips the tour"))
                        .accessibilityIdentifier("skipButton")
                }
            }
            .tint(OnboardingStyle.ink)
        }
        .sensoryFeedback(.selection, trigger: pageIndex)
    }

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<pages.count, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(index == pageIndex ? AnyShapeStyle(Color.waffleSecondary) : AnyShapeStyle(.tertiary))
                    .frame(width: index == pageIndex ? 24 : 8, height: 8)
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8), value: pageIndex)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Page \(pageIndex + 1) of \(pages.count)"))
    }

    private func continueButton(inColumn: Bool) -> some View {
        Button {
            if isLast { finish() } else { go(1) }
        } label: {
            HStack(spacing: 8) {
                Text(isLast ? "Get Started" : "Continue")
                if !isLast { Image(systemName: "arrow.right").accessibilityHidden(true) }
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
        }
        .onboardingPrimaryButton()
        .keyboardShortcut(.defaultAction)
        .accessibilityIdentifier("continueButton")
        .frame(maxWidth: inColumn ? 460 : OnboardingStyle.readableWidth)
        .padding(.horizontal, inColumn ? 0 : 24)
        .padding(.top, 10)
        .padding(.bottom, 16)
    }

    // MARK: Paging

    private var pageTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .move(edge: goingForward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: goingForward ? .leading : .trailing).combined(with: .opacity)
        )
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 40)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
                if value.translation.width < -80, !isLast { go(1) }
                else if value.translation.width > 80, pageIndex > 0 { go(-1) }
            }
    }

    private func go(_ step: Int) {
        let target = pageIndex + step
        guard pages.indices.contains(target) else { return }
        goingForward = step > 0
        // Commit the direction first so the outgoing page leaves the right way.
        Task { @MainActor in
            withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.45, dampingFraction: 0.86)) {
                pageIndex = target
            }
        }
    }

    private func finish() {
        done = true
        onFinished()
    }
}
#endif
