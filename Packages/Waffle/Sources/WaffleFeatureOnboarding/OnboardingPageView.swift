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
    /// Wide layout only: the page dots and the Continue button, placed in the text column.
    var indicator: AnyView?
    var footer: AnyView?

    static func isWide(_ size: CGSize) -> Bool { size.width >= 640 && size.height < size.width * 0.8 }
    private var isWide: Bool { Self.isWide(size) }

    var body: some View {
        if isWide {
            wide
        } else {
            ViewThatFits(in: .vertical) {
                stacked(compact: false)
                stacked(compact: true)
                // Longer languages: rows keep their titles and drop the detail lines, then the
                // miniature steps aside, before the page has to scroll.
                stacked(compact: true, tight: true)
                stacked(compact: true, tight: true, showsDemo: false)
                ScrollView { stacked(compact: true, tight: true, showsDemo: false) }
                    .scrollBounceBehavior(.basedOnSize)
                    .scrollIndicatorsFlash(onAppear: true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: Layouts

    private func stacked(compact: Bool, tight: Bool = false, showsDemo: Bool = true) -> some View {
        VStack(spacing: compact ? 14 : 22) {
            OnboardingPageHeader(page: page, compact: compact)
            if showsDemo { demo(compact: compact) }
            if !page.features.isEmpty {
                featureCard(compact: compact, detail: !tight)
            }
            footnote
        }
        .padding(.horizontal, compact ? 16 : 24)
        .padding(.top, compact ? 6 : 16)
        .padding(.bottom, compact ? 14 : 16)
        .frame(maxWidth: OnboardingStyle.readableWidth)
        .frame(maxWidth: .infinity)
    }

    /// Text and rows on one side, the miniature on the other. A fold keeps both off the hinge;
    /// the dots and Continue belong to the text column, and both columns centre vertically.
    private var wide: some View {
        let dense = probe.foldCenterX != nil
        let gutter: CGFloat = dense ? 24 : 28
        let hinge = probe.foldCenterX ?? size.width / 2
        let leftWidth = max(0, hinge - gutter - 28)
        let rightWidth = max(0, size.width - hinge - gutter - 28)
        return HStack(spacing: 0) {
            VStack(spacing: 0) {
                if !dense {
                    indicator
                        .padding(.top, 4)
                        .padding(.bottom, 8)
                }
                GeometryReader { column in
                    ViewThatFits(in: .vertical) {
                        if dense {
                            textColumn(compact: false, large: true, dense: true, height: column.size.height)
                        }
                        textColumn(compact: true, large: false, dense: dense, height: column.size.height)
                        textColumn(compact: true, large: false, dense: dense, height: column.size.height, detail: false)
                        // A short landscape phone: the symbol tile steps aside too.
                        textColumn(compact: true, large: false, dense: dense, height: column.size.height, detail: false, tile: false)
                        ScrollView {
                            textColumn(compact: true, large: false, dense: dense, height: column.size.height, detail: false, tile: false)
                        }
                        .scrollBounceBehavior(.basedOnSize)
                        .scrollIndicatorsFlash(onAppear: true)
                    }
                    .frame(width: column.size.width, height: column.size.height)
                }
                if dense {
                    indicator.padding(.top, 6)
                }
                footer
            }
            .frame(width: leftWidth)
            .padding(.leading, 28)
            .padding(.trailing, gutter)

            GeometryReader { column in
                if dense, page.kind == .syrup {
                    // No miniature on the Syrup page: the rows take the right half instead.
                    ScrollView {
                        featureCard(compact: false, large: true)
                            .frame(maxWidth: .infinity, minHeight: column.size.height)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                } else if dense {
                    // The miniature fills the half, top to bottom, like the pages it teaches.
                    demo(compact: false)
                        .environment(\.demoFills, true)
                        .frame(width: column.size.width, height: max(0, column.size.height - 32))
                        .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        demo(compact: false)
                            .frame(maxWidth: 460)
                            .frame(maxWidth: .infinity, minHeight: column.size.height)
                            .padding(.vertical, 8)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }
            }
            .frame(width: rightWidth)
            .padding(.leading, gutter)
            .padding(.trailing, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func textColumn(compact: Bool, large: Bool, dense: Bool, height: CGFloat, detail: Bool = true, tile: Bool = true) -> some View {
        VStack(spacing: large ? 22 : 18) {
            OnboardingPageHeader(page: page, compact: compact, large: large, showsTile: tile)
            if !page.features.isEmpty, !(dense && page.kind == .syrup) { featureCard(compact: compact, large: large, detail: detail) }
            footnote
        }
        .padding(.vertical, 8)
        .frame(maxWidth: dense ? .infinity : 460)
        .frame(maxWidth: .infinity, minHeight: height)
    }

    // MARK: Pieces

    @ViewBuilder
    private func demo(compact: Bool) -> some View {
        switch page.kind {
        case .grid: SelectDemo(compact: compact)
        case .shape: ShapeDemo(compact: compact)
        case .library: LibraryDemo()
        case .panes: PanesDemo(compact: compact, toolbar: page.usesToolbar)
        case .size: SizeDemo(compact: compact)
        case .layouts: LayoutsDemo()
        case .unfold: UnfoldDemo()
        case .syrup: EmptyView()
        }
    }

    private func featureCard(compact: Bool, large: Bool = false, detail: Bool = true) -> some View {
        // Rows are spelled out without ForEach: ViewThatFits measures alternatives off the main
        // actor, where a main-actor ForEach content closure trips a dispatch assertion.
        VStack(spacing: 0) {
            featureRow(0, compact: compact, large: large, detail: detail)
            featureRow(1, compact: compact, large: large, detail: detail)
            featureRow(2, compact: compact, large: large, detail: detail)
            featureRow(3, compact: compact, large: large, detail: detail)
        }
        .onboardingCard()
    }

    @ViewBuilder
    private func featureRow(_ index: Int, compact: Bool, large: Bool, detail: Bool) -> some View {
        if page.features.indices.contains(index) {
            if index > 0 { Divider().padding(.leading, large ? 76 : 60) }
            OnboardingFeatureRow(feature: page.features[index], compact: compact, large: large, showsDetail: detail)
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
    /// The unfolded Duo: a bigger tile, title and line to fill the half.
    var large = false
    var showsTile = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bounce = false
    @ScaledMetric(relativeTo: .largeTitle) private var largeBox: CGFloat = 96
    @ScaledMetric(relativeTo: .largeTitle) private var box: CGFloat = 80
    @ScaledMetric(relativeTo: .largeTitle) private var compactBox: CGFloat = 52

    var body: some View {
        let side = large ? largeBox : (compact ? compactBox : box)
        VStack(spacing: large ? 18 : (compact ? 8 : 14)) {
            if showsTile {
            Image(systemName: page.systemImage)
                .font(.system(size: side * 0.48, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(OnboardingStyle.ink)
                .symbolEffect(.bounce, options: .nonRepeating, value: bounce)
                .frame(width: side, height: side)
                .background(Color.waffleSecondary.opacity(0.28), in: RoundedRectangle(cornerRadius: side * 0.26, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: side * 0.26, style: .continuous).strokeBorder(.quaternary))
                .accessibilityHidden(true)
            }

            VStack(spacing: 6) {
                Text(page.title)
                    .font(.system(large ? .largeTitle : .title, design: .rounded, weight: .bold))
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text(page.subtitle)
                    .font(large ? .title3 : .body)
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
    var large = false
    /// False in the tight tiers: the title alone.
    var showsDetail = true

    @ScaledMetric(relativeTo: .body) private var largeGlyphBox: CGFloat = 48
    @ScaledMetric(relativeTo: .body) private var glyphBox: CGFloat = 36

    var body: some View {
        let glyph = large ? largeGlyphBox : glyphBox
        HStack(spacing: large ? 16 : 14) {
            Image(systemName: feature.systemImage)
                .font((large ? Font.title3 : Font.body).weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(OnboardingStyle.ink)
                .frame(width: glyph, height: glyph)
                .background(Color.waffleSecondary.opacity(0.28), in: RoundedRectangle(cornerRadius: large ? 13 : 10, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(feature.title).font((large ? Font.title3 : Font.body).weight(.semibold))
                    .lineLimit(showsDetail ? nil : 1)
                    .minimumScaleFactor(showsDetail ? 1 : 0.7)
                if showsDetail {
                    Text(feature.detail)
                        .font(large ? .body : .subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
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
        .padding(.vertical, large ? 14 : (compact ? 9 : 12))
        .accessibilityElement(children: .combine)
    }
}
#endif
