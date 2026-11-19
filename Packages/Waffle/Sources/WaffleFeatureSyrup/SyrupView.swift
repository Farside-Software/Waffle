//
//  SyrupView.swift
//  WaffleFeatureSyrup
//
//  The Syrup purchase sheet. Takes the `StoreManager` directly (it is already an
//  @Observable presentation-ready object); purchase/close outcomes flow out via closures.
//

#if os(iOS)
import SwiftUI
import WaffleCore
import WaffleDesignSystem
import WaffleServices

public struct SyrupView: View {
    private let store: StoreManager
    private let onPurchased: (() -> Void)?
    private let onClose: (() -> Void)?
    /// Set on iPhone and iPhone Duo: lists what Syrup unlocks there instead of the iPad grid features.
    private let phonePitch: SyrupPitch?
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.duoPanelDense) private var dense

    public init(store: StoreManager, phonePitch: SyrupPitch? = nil, onPurchased: (() -> Void)? = nil, onClose: (() -> Void)? = nil) {
        self.store = store
        self.phonePitch = phonePitch
        self.onPurchased = onPurchased
        self.onClose = onClose
    }

    public var body: some View {
        if let phonePitch {
            phoneBody(phonePitch)
        } else {
            padBody
        }
    }

    // MARK: - iPad and Mac (unchanged layout)

    private var padBody: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack {
                    Spacer()
                    Button {
                        onClose?()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Close"))
                }

                Image(systemName: "drop.fill")
                    .font(.system(size: 48))
                    // Dark brown vanishes on a dark sheet: the brand gold there.
                    .foregroundStyle(colorScheme == .dark ? Color.wafflePrimary : Color.waffleTertiary)

                Text(verbatim: "Syrup")
                    .font(.largeTitle).bold()

                Text("Waffle + Syrup, what could be better?")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text("Unlock the full Waffle experience")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 10) {
                    Label("Up to \(AppConfiguration.maxPremiumRows)x\(AppConfiguration.maxPremiumCols) waffles (double the \(AppConfiguration.maxFreeRows)x\(AppConfiguration.maxFreeCols) limit)", systemImage: "square.grid.3x3")
                    Label("Rearrange waffles", systemImage: "arrow.left.arrow.right.square")
                    Label("Pop out cells into their own windows", systemImage: "rectangle.on.rectangle")
                    Label("Fullscreen a single cell", systemImage: "arrow.up.left.and.arrow.down.right.rectangle")
                    Label("Create and update Preset waffles", systemImage: "square.and.arrow.down")
                    Label("Syrup is shared for free with your whole family", systemImage: "person.2")
                }
                .labelStyle(AlignedIconLabelStyle(iconSize: 22, iconWidth: 40, iconColor: .secondary))
                .frame(maxWidth: .infinity, alignment: .leading)
                .waffleCard()
            }

            if let price = store.product?.displayPrice {
                Text("Only \(price). One time. No subscription!")
                    .font(.headline)
            } else {
                Text("Loading price…")
                    .font(.headline)
            }

            if let msg = store.errorMessage {
                Text(msg)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            purchaseButtons

            Text("Syrup is a one-time purchase. Use Family Sharing to share Syrup with family.  ")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding([.horizontal, .bottom])
        }
        .padding()
        .frame(minWidth: 420, minHeight: 520)
    }

    private var purchaseButtons: some View {
        VStack(spacing: 12) {
            Button {
                Task {
                    let ok = await store.purchase()
                    if ok {
                        onPurchased?()
                    }
                }
            } label: {
                HStack {
                    if store.isLoading { ProgressView() }
                    Text("Buy Syrup")
                        .bold()
                }
            }
            .buttonStyle(.wafflePrimary)
            .disabled(store.isLoading || store.product == nil)

            Button {
                Task {
                    let ok = await store.restore()
                    if ok {
                        onPurchased?()
                    }
                }
            } label: {
                Text("Restore Purchases")
            }
            .buttonStyle(.waffleSecondary)
            .disabled(store.isLoading)
        }
    }

    // MARK: - iPhone and iPhone Duo sheet

    /// The close button and the price and buy buttons are pinned outside the scrolling pitch,
    /// so Buy and Restore are always reachable however short the display or large the text.
    private func phoneBody(_ pitch: SyrupPitch) -> some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button {
                    onClose?()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Close"))
            }

            // On a tall screen the pitch would sit at the top with a dead band above the pinned
            // buy area. The scroll content is at least as tall as the viewport and spreads its
            // slack evenly between the sections; where it is taller (small phones, large
            // text) the spacers collapse to their minimum and it scrolls as before.
            GeometryReader { viewport in
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)

                        // Drop and name share a line: the pitch is shorter than it was, so on the
                        // unfolded Duo's side panel the "Always free" card is not cut off.
                        HStack(spacing: 10) {
                            Image(systemName: "drop.fill")
                                .font(.system(size: dense ? 40 : 34))
                                // Dark brown vanishes on a dark sheet: the brand gold there.
                                .foregroundStyle(colorScheme == .dark ? Color.wafflePrimary : Color.waffleTertiary)
                                .accessibilityHidden(true)
                            Text(verbatim: "Syrup")
                                .font(dense ? .system(size: 38, weight: .bold, design: .rounded) : .system(.largeTitle, design: .rounded, weight: .bold))
                        }

                        Spacer(minLength: 12)

                        Text(Self.lead(for: pitch.trigger))
                            .font(dense ? .title3.weight(.semibold) : .headline)
                            .multilineTextAlignment(.center)

                        Spacer(minLength: 12)

                        phoneFeatures(pitch)

                        Spacer(minLength: 16)

                        Text(LocalizedStringKey("Syrup is a one-time purchase. With Family Sharing, your whole family can use it."))
                            .font(dense ? .subheadline : .footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        Spacer(minLength: 0)
                    }
                    .padding(.bottom, 8)
                    .frame(minHeight: viewport.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollIndicators(.visible)
            }

            VStack(spacing: 10) {
                // Never a hardcoded price: the live StoreKit price, or neutral wording.
                if let price = store.product?.displayPrice {
                    Text("\(price), one time. No subscription.")
                        .font(.headline)
                } else {
                    Text("A one-time purchase. No subscription.")
                        .font(.headline)
                }
                if let msg = store.errorMessage {
                    Text(msg)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                purchaseButtons
            }
            .multilineTextAlignment(.center)
            // The pinned part stays at control size (like the bar): at the accessibility
            // sizes the pitch above grows and scrolls, and Buy never shrinks the room for it.
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .padding(.top, 10)
        }
        .padding(.horizontal)
        .padding(.bottom)
    }

    // MARK: - iPhone and iPhone Duo

    private static func lead(for trigger: SyrupTrigger) -> LocalizedStringKey {
        switch trigger {
        case .general: "Get more from Waffle with Syrup"
        case .thirdPane: "Add a third pane with Syrup"
        case .secondLayout: "Save more layouts with Syrup"
        case .deskMode: "Use Desk Mode with Syrup"
        }
    }

    private func phoneFeatures(_ pitch: SyrupPitch) -> some View {
        VStack(spacing: dense ? 14 : 14) {
            VStack(alignment: .leading, spacing: dense ? 14 : 12) {
                ForEach(pitch.features, id: \.self) { feature in
                    phoneLabel(feature, device: pitch.device)
                        .fontWeight(feature == pitch.leadFeature ? .semibold : .regular)
                }
            }
            .font(dense ? .body : .body)
            .labelStyle(AlignedIconLabelStyle(iconSize: dense ? 28 : 22, iconWidth: dense ? 48 : 40, iconColor: .secondary))
            .frame(maxWidth: .infinity, alignment: .leading)
            .waffleCard()

            // What else the purchase covers, on the other devices.
            Group {
                if pitch.device.isFoldable {
                    Text("Also unlocks Waffle on iPad: bigger grids, pop-out, fullscreen and rearranging")
                } else {
                    Text("Also unlocks Waffle on iPad and iPhone Duo: bigger grids, a third and fourth pane, Desk Mode")
                }
            }
            .font(dense ? .subheadline : .subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)

            // The free side, said plainly (and it fills the sheet honestly).
            Label("Always free: two panes, one saved layout, auto-refresh and content blocking", systemImage: "checkmark.circle")
                .font(dense ? .subheadline : .subheadline)
                .foregroundStyle(.secondary)
                .labelStyle(AlignedIconLabelStyle(iconSize: dense ? 28 : 22, iconWidth: dense ? 48 : 40, iconColor: .secondary))
                .frame(maxWidth: .infinity, alignment: .leading)
                .waffleCard()
        }
    }

    @ViewBuilder
    private func phoneLabel(_ feature: SyrupFeature, device: SyrupDevice) -> some View {
        switch feature {
        case .morePanes:
            if device.isInnerDisplay {
                Label("A third and fourth pane on this display", systemImage: "rectangle.split.2x2")
            } else {
                Label("A third and fourth pane when you unfold your iPhone Duo", systemImage: "rectangle.split.2x2")
            }
        case .unlimitedLayouts:
            Label("Unlimited saved layouts", systemImage: "square.and.arrow.down")
        case .deskMode:
            if device.isInnerDisplay {
                Label("Desk Mode when this display is half-folded", systemImage: "laptopcomputer")
            } else {
                Label("Desk Mode when your iPhone Duo is half-folded", systemImage: "laptopcomputer")
            }
        }
    }
}
#endif
