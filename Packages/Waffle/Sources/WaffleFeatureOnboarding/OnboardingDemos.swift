//
//  OnboardingDemos.swift
//  WaffleFeatureOnboarding
//
//  The interactive miniatures: a small live grid or stack of panes the user can tap, resize and
//  reshape during the tour. Everything here is pretend (no web views), drawn with the app's real
//  selection treatment so what they learn is what they will see.
//

#if os(iOS)
import SwiftUI
import WaffleCore
import WaffleDesignSystem

// MARK: - Sample sites

struct DemoSite: Identifiable {
    let address: String
    let icon: String
    let tint: Color
    var id: String { address }

    static let samples: [DemoSite] = [
        .init(address: "apple.com", icon: "applelogo", tint: .primary),
        .init(address: "news.com", icon: "newspaper.fill", tint: .red),
        .init(address: "mail.com", icon: "envelope.fill", tint: .blue),
        .init(address: "video.com", icon: "play.rectangle.fill", tint: .purple),
        .init(address: "maps.com", icon: "map.fill", tint: .green),
        .init(address: "music.com", icon: "music.note", tint: .pink),
        .init(address: "scores.com", icon: "sportscourt.fill", tint: .orange),
        .init(address: "weather.com", icon: "cloud.sun.fill", tint: .cyan),
        .init(address: "notes.com", icon: "note.text", tint: .yellow),
    ]
}

/// One miniature page. Tapping reports through `onTap`.
struct DemoCell: View {
    let site: DemoSite
    let isSelected: Bool
    var isLocked = false
    var compact = false
    var onTap: (() -> Void)?

    var body: some View {
        Button {
            onTap?()
        } label: {
            ZStack {
                LinearGradient(
                    colors: [Color.wafflePrimary.opacity(0.55), Color.waffleSecondary.opacity(0.4)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                VStack(spacing: compact ? 2 : 4) {
                    Image(systemName: site.icon)
                        .font(compact ? .body : .title3)
                        .foregroundStyle(site.tint)
                    Text(verbatim: site.address)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .padding(4)

                if isLocked {
                    Rectangle().fill(.black.opacity(0.28))
                    Image(systemName: "drop.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(5)
                        .background(Color.waffleTertiary, in: Circle())
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .selectionOutline(isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: site.address))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// The bar that controls the selected cell or pane; its address follows the selection.
struct DemoAddressBar: View {
    let address: String
    var showsMenu = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "chevron.backward").foregroundStyle(.secondary)
            HStack(spacing: 6) {
                Image(systemName: "arrow.clockwise").foregroundStyle(.secondary).font(.caption)
                Text(verbatim: address)
                    .font(.subheadline)
                    .lineLimit(1)
                    .contentTransition(.interpolate)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(uiColor: .tertiarySystemFill), in: Capsule())
            Image(systemName: showsMenu ? "ellipsis" : "square.grid.3x3.fill").foregroundStyle(.secondary)
        }
        .padding(10)
        .background(Color(uiColor: .tertiarySystemFill).opacity(0.5), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .animation(.easeInOut(duration: 0.2), value: address)
    }
}

// MARK: - Grid (iPad)

/// A live grid. With `locksBeyondFree` cells outside the free 2x2 carry the Syrup drop.
struct DemoGrid: View {
    let rows: Int
    let columns: Int
    @Binding var selected: Int
    var locksBeyondFree = false
    var compact = false

    var body: some View {
        VStack(spacing: 8) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(0..<columns, id: \.self) { column in
                        let index = row * 3 + column
                        let locked = locksBeyondFree && (row >= AppConfiguration.maxFreeRows || column >= AppConfiguration.maxFreeCols)
                        DemoCell(
                            site: DemoSite.samples[index % DemoSite.samples.count],
                            isSelected: selected == index && !locked,
                            isLocked: locked,
                            compact: compact
                        ) {
                            if !locked { selected = index }
                        }
                    }
                }
            }
        }
        .frame(height: CGFloat(rows) * (compact ? 56 : 68) + CGFloat(rows - 1) * 8)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: rows)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: columns)
    }
}

/// Page one: the toolbar address follows the tapped cell.
struct SelectDemo: View {
    var compact = false
    @State private var selected = 0

    var body: some View {
        VStack(spacing: 12) {
            DemoAddressBar(address: DemoSite.samples[selected % DemoSite.samples.count].address)
            DemoGrid(rows: 2, columns: 2, selected: $selected, compact: compact)
        }
        .onboardingCard(padding: 12)
    }
}

/// Page two: add and remove rows and columns; cells beyond the free grid show the Syrup drop.
struct ShapeDemo: View {
    var compact = false
    @State private var rows = 2
    @State private var columns = 2
    @State private var selected = 0

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                stepper("Rows", value: $rows)
                stepper("Columns", value: $columns)
            }
            DemoGrid(rows: rows, columns: columns, selected: $selected, locksBeyondFree: true, compact: compact)
            Text(rows > AppConfiguration.maxFreeRows || columns > AppConfiguration.maxFreeCols
                 ? "Cells with a drop are Syrup: larger grids unlock them."
                 : "Your free grid fits \(AppConfiguration.maxFreeRows)×\(AppConfiguration.maxFreeCols) cells.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .onboardingCard(padding: 12)
    }

    private func stepper(_ title: LocalizedStringKey, value: Binding<Int>) -> some View {
        HStack(spacing: 8) {
            Button { value.wrappedValue = max(1, value.wrappedValue - 1) } label: {
                Image(systemName: "minus").frame(width: 32, height: 32)
            }
            .disabled(value.wrappedValue <= 1)
            .accessibilityLabel(Text("Remove one"))
            VStack(spacing: 0) {
                Text(title).font(.caption2).foregroundStyle(.secondary)
                Text(verbatim: "\(value.wrappedValue)").font(.headline).contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity)
            Button { value.wrappedValue = min(3, value.wrappedValue + 1) } label: {
                Image(systemName: "plus").frame(width: 32, height: 32)
            }
            .disabled(value.wrappedValue >= 3)
            .accessibilityLabel(Text("Add one"))
        }
        .buttonStyle(.bordered)
        .tint(Color.waffleSecondary)
        .padding(6)
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .tertiarySystemFill).opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// Page three (iPad): the sidebar's two lists.
struct LibraryDemo: View {
    private enum Tab: Hashable { case bookmarks, presets }
    @State private var tab = Tab.bookmarks
    @State private var opened: String?

    var body: some View {
        VStack(spacing: 10) {
            Picker("Library", selection: $tab.animation()) {
                Text("Bookmarks").tag(Tab.bookmarks)
                Text("Presets").tag(Tab.presets)
            }
            .pickerStyle(.segmented)

            VStack(spacing: 0) {
                switch tab {
                case .bookmarks:
                    row("apple.com", "applelogo")
                    Divider()
                    row("news.com", "newspaper.fill")
                    Divider()
                    row("mail.com", "envelope.fill")
                case .presets:
                    row("Morning", "square.grid.2x2")
                    Divider()
                    row("Match day", "square.grid.3x3")
                    Divider()
                    row("Work", "rectangle.split.2x1")
                }
            }
            .background(Color(uiColor: .tertiarySystemFill).opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .onboardingCard(padding: 12)
    }

    private func row(_ title: String, _ icon: String) -> some View {
        Button { opened = title } label: {
            HStack {
                Image(systemName: icon).foregroundStyle(Color.waffleSecondary).frame(width: 26)
                Text(verbatim: title)
                Spacer()
                if opened == title {
                    Image(systemName: "checkmark").foregroundStyle(Color.waffleSecondary)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Panes (iPhone)

/// Two stacked panes with the bar underneath; tapping a pane selects it.
struct PanesDemo: View {
    var compact = false
    @State private var selected = 0

    var body: some View {
        VStack(spacing: 10) {
            VStack(spacing: 8) {
                ForEach(0..<2, id: \.self) { index in
                    DemoCell(site: DemoSite.samples[index], isSelected: selected == index, compact: compact) { selected = index }
                        .frame(height: compact ? 64 : 84)
                }
            }
            DemoAddressBar(address: DemoSite.samples[selected].address, showsMenu: true)
        }
        .onboardingCard(padding: 12)
    }
}

/// Two panes with a divider the user can drag.
struct SizeDemo: View {
    var compact = false
    @State private var ratio: CGFloat = 0.5
    @State private var startRatio: CGFloat?

    var body: some View {
        let total: CGFloat = compact ? 170 : 220
        let gap: CGFloat = 20
        VStack(spacing: 0) {
            DemoCell(site: DemoSite.samples[0], isSelected: false, compact: compact)
                .frame(height: (total - gap) * ratio)
                .allowsHitTesting(false)
            Capsule()
                .fill(Color.waffleSecondary)
                .frame(width: 48, height: 6)
                .frame(maxWidth: .infinity, minHeight: gap)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let start = startRatio ?? ratio
                            startRatio = start
                            ratio = min(0.75, max(0.25, start + value.translation.height / (total - gap)))
                        }
                        .onEnded { _ in startRatio = nil }
                )
                .accessibilityLabel(Text("Pane divider"))
                .accessibilityAdjustableAction { direction in
                    ratio = min(0.75, max(0.25, ratio + (direction == .increment ? 0.1 : -0.1)))
                }
            DemoCell(site: DemoSite.samples[1], isSelected: false, compact: compact)
                .frame(height: (total - gap) * (1 - ratio))
                .allowsHitTesting(false)
        }
        .frame(height: total)
        .onboardingCard(padding: 12)
    }
}

/// Saving a layout: one is free, a second shows what Syrup adds.
struct LayoutsDemo: View {
    @State private var saved: [String] = []
    @State private var tappedSecond = false

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                ForEach(0..<2, id: \.self) { index in
                    DemoCell(site: DemoSite.samples[index], isSelected: false)
                        .frame(height: 52)
                        .allowsHitTesting(false)
                }
            }
            Button {
                if saved.isEmpty {
                    saved = [String(localized: "Morning news")]
                } else {
                    tappedSecond = true
                }
            } label: {
                Label("Save this layout", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(Color.waffleSecondary)
            .controlSize(.large)

            if let first = saved.first {
                HStack {
                    Image(systemName: "rectangle.split.2x1").foregroundStyle(Color.waffleSecondary)
                    Text(verbatim: first)
                    Spacer()
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.waffleSecondary)
                }
                .padding(10)
                .background(Color(uiColor: .tertiarySystemFill).opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
            if tappedSecond {
                Text("One saved layout is free. Syrup keeps as many as you like.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: saved)
        .animation(.easeInOut(duration: 0.2), value: tappedSecond)
        .onboardingCard(padding: 12)
    }
}

// MARK: - Unfold (iPhone Duo)

/// The Duo's three poses: unfolded (four panes around the fold), half-folded (Desk Mode), closed.
struct UnfoldDemo: View {
    private enum Pose: Hashable { case unfolded, desk, closed }
    @State private var pose = Pose.unfolded
    @State private var selected = 0

    var body: some View {
        VStack(spacing: 12) {
            Picker("Pose", selection: $pose.animation(.spring(response: 0.4, dampingFraction: 0.85))) {
                Text("Unfolded").tag(Pose.unfolded)
                Text("Desk Mode").tag(Pose.desk)
                Text("Closed").tag(Pose.closed)
            }
            .pickerStyle(.segmented)

            Group {
                switch pose {
                case .unfolded:
                    HStack(spacing: 22) {
                        paneColumn(0, 1)
                        paneColumn(2, 3)
                    }
                    .overlay {
                        Capsule().fill(Color.waffleTertiary.opacity(0.45)).frame(width: 3)
                    }
                case .desk:
                    VStack(spacing: 8) {
                        HStack(spacing: 8) { pane(0); pane(1) }
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(uiColor: .tertiarySystemFill))
                            .overlay { DemoAddressBar(address: DemoSite.samples[selected].address, showsMenu: true).padding(8) }
                            .frame(height: 70)
                    }
                case .closed:
                    VStack(spacing: 8) { pane(0); pane(1) }
                        .frame(maxWidth: 150)
                }
            }
            .frame(height: 170)
            .frame(maxWidth: .infinity)
        }
        .onboardingCard(padding: 12)
    }

    private func paneColumn(_ a: Int, _ b: Int) -> some View {
        VStack(spacing: 8) { pane(a); pane(b) }
    }

    private func pane(_ index: Int) -> some View {
        DemoCell(site: DemoSite.samples[index], isSelected: selected == index, compact: true) { selected = index }
    }
}
#endif
