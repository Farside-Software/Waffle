//
//  OnboardingPageView.swift
//  WaffleFeatureOnboarding
//
//  One tour page: a symbol tile, a title and one line, the interactive miniature, and a short
//  card of rows. Portrait pages stack and tighten on short windows (the closed Duo), scrolling
//  only as a last resort. On wide, short windows (iPad landscape, the unfolded Duo) the page
//  splits in two columns, around the fold when there is one.
//

#if os(iOS)
import SwiftUI
import WaffleDesignSystem

struct OnboardingPageView: View {
    let page: OnboardingPage
    let probe: LayoutProbe
    let size: CGSize

    private var isWide: Bool { size.width >= 640 && size.height < size.width * 0.8 }

    var body: some View {
        if isWide {
            wide
        } else {
            ViewThatFits(in: .vertical) {
                stacked(compact: false)
                stacked(compact: true)
                ScrollView { stacked(compact: true) }
                    .scrollBounceBehavior(.basedOnSize)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: Layouts

    private func stacked(compact: Bool) -> some View {
        VStack(spacing: compact ? 14 : 22) {
            OnboardingPageHeader(page: page, compact: compact)
            demo(compact: compact)
            if !page.features.isEmpty {
                featureCard(compact: compact)
            }
            footnote
        }
        .padding(.horizontal, compact ? 16 : 24)
        .padding(.top, compact ? 6 : 16)
        .padding(.bottom, compact ? 14 : 16)
        .frame(maxWidth: OnboardingStyle.readableWidth)
        .frame(maxWidth: .infinity)
    }

    /// Text and rows on one side, the miniature on the other. A fold keeps both off the hinge.
    private var wide: some View {
        let gutter: CGFloat = 28
        let hinge = probe.foldCenterX ?? size.width / 2
        let leftWidth = max(0, hinge - gutter - 28)
        let rightWidth = max(0, size.width - hinge - gutter - 28)
        return HStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 18) {
                    OnboardingPageHeader(page: page, compact: true)
                    if !page.features.isEmpty { featureCard(compact: true) }
                    footnote
                }
                .padding(.vertical, 8)
                .frame(maxWidth: 460)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(width: leftWidth)
            .padding(.leading, 28)
            .padding(.trailing, gutter)

            ScrollView {
                demo(compact: false)
                    .frame(maxWidth: 460)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(width: rightWidth)
            .padding(.leading, gutter)
            .padding(.trailing, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Pieces

    @ViewBuilder
    private func demo(compact: Bool) -> some View {
        switch page.kind {
        case .grid: SelectDemo(compact: compact)
        case .shape: ShapeDemo(compact: compact)
        case .library: LibraryDemo()
        case .panes: PanesDemo(compact: compact)
        case .size: SizeDemo(compact: compact)
        case .layouts: LayoutsDemo()
        case .unfold: UnfoldDemo()
        case .syrup: EmptyView()
        }
    }

    private func featureCard(compact: Bool) -> some View {
        // Rows are spelled out without ForEach: ViewThatFits measures alternatives off the main
        // actor, where a main-actor ForEach content closure trips a dispatch assertion.
        VStack(spacing: 0) {
            featureRow(0, compact: compact)
            featureRow(1, compact: compact)
            featureRow(2, compact: compact)
            featureRow(3, compact: compact)
        }
        .onboardingCard()
    }

    @ViewBuilder
    private func featureRow(_ index: Int, compact: Bool) -> some View {
        if page.features.indices.contains(index) {
            if index > 0 { Divider().padding(.leading, 60) }
            OnboardingFeatureRow(feature: page.features[index], compact: compact)
        }
    }

    @ViewBuilder
    private var footnote: some View {
        if let footnote = page.footnote {
            Text(footnote)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Header

struct OnboardingPageHeader: View {
    let page: OnboardingPage
    var compact = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bounce = false
    @ScaledMetric(relativeTo: .largeTitle) private var box: CGFloat = 80
    @ScaledMetric(relativeTo: .largeTitle) private var compactBox: CGFloat = 52

    var body: some View {
        let side = compact ? compactBox : box
        VStack(spacing: compact ? 8 : 14) {
            Image(systemName: page.systemImage)
                .font(.system(size: side * 0.48, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(OnboardingStyle.ink)
                .symbolEffect(.bounce, options: .nonRepeating, value: bounce)
                .frame(width: side, height: side)
                .background(Color.waffleSecondary.opacity(0.28), in: RoundedRectangle(cornerRadius: side * 0.26, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: side * 0.26, style: .continuous).strokeBorder(.quaternary))
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text(page.title)
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text(page.subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            guard !reduceMotion else { return }
            bounce.toggle()
        }
    }
}

// MARK: - Feature row

struct OnboardingFeatureRow: View {
    let feature: OnboardingFeature
    var compact = false

    @ScaledMetric(relativeTo: .body) private var glyphBox: CGFloat = 36

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: feature.systemImage)
                .font(.body.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(OnboardingStyle.ink)
                .frame(width: glyphBox, height: glyphBox)
                .background(Color.waffleSecondary.opacity(0.28), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(feature.title).font(.body.weight(.semibold))
                Text(feature.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if feature.requiresSyrup {
                Image(systemName: "drop.fill")
                    .font(.caption)
                    .foregroundStyle(OnboardingStyle.ink)
                    .accessibilityLabel(Text("Syrup"))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, compact ? 9 : 12)
        .accessibilityElement(children: .combine)
    }
}
#endif
