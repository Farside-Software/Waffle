//
//  EmptyCellView.swift
//  WaffleFeatureGrid
//
//  The calm start page shown in a cell or pane with nothing loaded: the Waffle mark, a title,
//  and one hint line the first few times. Falls back to a smaller mark, then to the title alone,
//  as the cell shrinks.
//

#if os(iOS)
import SwiftUI
import UIKit
import WaffleDesignSystem

public struct EmptyCellView: View {
    /// iPhone and Duo call their slots panes and have no sidebar menu.
    private let isPane: Bool
    /// Phone panes: this is the only pane, so there is nothing to "tap" to select.
    private let isOnlyPane: Bool
    /// Phone panes: starts a second pane (offered while only one is open).
    private let onAddPane: (() -> Void)?

    /// The hint is for a first look; after it has been on screen once it stays out of the way.
    @AppStorage("hasSeenStartHint") private var hasSeenHint = false
    @State private var showsHint = false

    public init(isPane: Bool = false, isOnlyPane: Bool = false, onAddPane: (() -> Void)? = nil) {
        self.isPane = isPane
        self.isOnlyPane = isOnlyPane
        self.onAddPane = onAddPane
    }

    private var title: LocalizedStringKey { isPane ? "Empty Pane" : "Empty Cell" }

    private var hint: LocalizedStringKey {
        if isPane { isOnlyPane ? "Type an address below to open a page." : "Tap this pane, then type an address below." }
        else { "Tap a cell, then use the address bar to open a page." }
    }

    public var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)

            ViewThatFits(in: .vertical) {
                fullContent
                compactContent
                minimalContent
            }
        }
        .onAppear { showsHint = !hasSeenHint }
        .onDisappear { hasSeenHint = true }
    }

    private var fullContent: some View {
        VStack(spacing: 14) {
            WaffleMark().frame(width: 88, height: 88)
            Text(title)
                .font(.system(.title2, design: .rounded, weight: .bold))
            if showsHint {
                Text(hint)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if isPane, isOnlyPane, let onAddPane {
                Button(action: onAddPane) {
                    Label("Add a second pane", systemImage: "plus.rectangle.on.rectangle")
                }
                .buttonStyle(.wafflePrimary)
                .padding(.top, 4)
            }
        }
        .padding(32)
    }

    private var compactContent: some View {
        VStack(spacing: 8) {
            WaffleMark().frame(width: 44, height: 44)
            Text(title)
                .font(.system(.headline, design: .rounded, weight: .bold))
        }
        .padding(16)
    }

    private var minimalContent: some View {
        Text(title)
            .font(.system(.subheadline, design: .rounded, weight: .bold))
            .foregroundStyle(.secondary)
            .padding(8)
    }
}

#Preview {
    EmptyCellView()
        .frame(width: 400, height: 300)
}
#endif
