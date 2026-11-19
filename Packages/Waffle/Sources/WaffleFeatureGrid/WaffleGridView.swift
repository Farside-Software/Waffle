//
//  WaffleGridView.swift
//  WaffleFeatureGrid
//
//  The waffle itself: a rows x cols grid of live web cells with selection, hover,
//  loading, popped-out placeholders, and URL drag-and-drop.
//

#if os(iOS)
import SwiftUI
import UIKit
import WebKit
import WaffleCore
import WaffleDesignSystem

public struct WaffleGridView: View {
    let model: GridModel
    var requestPopBack: () -> Void
    var fullscreenCell: WaffleCell? = nil

    /// Corner radius for cells, concentric with iPad screen corners (~18pt screen radius - 14pt inset)
    private let cellCornerRadius: CGFloat = 18

    public init(model: GridModel, requestPopBack: @escaping () -> Void, fullscreenCell: WaffleCell? = nil) {
        self.model = model
        self.requestPopBack = requestPopBack
        self.fullscreenCell = fullscreenCell
    }

    public var body: some View {
        GeometryReader { geometry in
            let rowCount = max(1, model.rowCount)
            let colCount = max(1, model.colCount)
            let cellHeight = max(1, (geometry.size.height - CGFloat(rowCount - 1) * 4) / CGFloat(rowCount))
            let cellWidth = max(1, (geometry.size.width - CGFloat(colCount - 1) * 4) / CGFloat(colCount))

            Grid(horizontalSpacing: 4, verticalSpacing: 4) {
                ForEach(Array(model.waffleRows.enumerated()), id: \.element.first?.id) { rowIndex, rowCells in
                    GridRow {
                        ForEach(rowCells) { waffleCell in
                            if fullscreenCell == waffleCell {
                                Color.clear
                                    .frame(width: cellWidth, height: cellHeight)
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .trailing).combined(with: .opacity)
                                    ))
                            } else {
                                WaffleCellContainer(
                                    waffleCell: waffleCell,
                                    model: model,
                                    cornerRadius: cellCornerRadius,
                                    requestPopBack: requestPopBack
                                )
                                .frame(width: cellWidth, height: cellHeight)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .trailing).combined(with: .opacity)
                                ))
                            }
                        }
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(Text("Row \(rowIndex + 1)"))
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
                }
            }
        }
        .animation(.snappy, value: model.rowCount)
        .animation(.snappy, value: model.colCount)
        .animation(.snappy, value: model.waffleRows.map { $0.map(\.id) })
    }
}

/// Separate container view to enable @State for hover tracking
struct WaffleCellContainer: View {
    let waffleCell: WaffleCell
    let model: GridModel
    let cornerRadius: CGFloat
    let requestPopBack: () -> Void
    /// iPhone and Duo panes: keep the address when the page's URL momentarily clears (a layout
    /// change re-creating the web view) so a pane never falls back to "empty", and use
    /// pane wording in the empty state.
    var isPhonePane = false
    /// Phone panes: how many panes are open, and how to add another (the empty-pane card
    /// offers "Add a second pane" while only one is open).
    var paneCount = 0
    var onAddPane: (() -> Void)? = nil
    /// Per-corner radii for a phone pane whose outer corners follow the display's corners.
    /// nil keeps every corner at `cornerRadius`.
    var cornerRadii: RectangleCornerRadii? = nil

    @State private var isHovered = false

    private var cellShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(cornerRadii: cornerRadii ?? RectangleCornerRadii(
            topLeading: cornerRadius, bottomLeading: cornerRadius,
            bottomTrailing: cornerRadius, topTrailing: cornerRadius
        ))
    }

    private var isPoppedOut: Bool { model.isPoppedOut(waffleCell) }
    private var isSelected: Bool { model.selectedCell == waffleCell }
    private var isEmpty: Bool { waffleCell.address.isEmpty }

    var body: some View {
        // One WebView per page for the cell's whole life: the empty card is drawn over it, never
        // swapped for it. Re-creating the host when the address toggles between empty and set
        // could build a second WebView for a page whose first was still tearing down, which traps
        // inside WebKit's SwiftUI layer.
        WebView(waffleCell.page)
            .webViewBackForwardNavigationGestures(.enabled)
            .webViewMagnificationGestures(.enabled)
            .webViewLinkPreviews(.enabled)
            .onAppear {
                // A cell built by a preset or restore already started its load; starting it again
                // here cancels that navigation and can leave the pane blank.
                if !waffleCell.address.isEmpty, waffleCell.page.url == nil, !waffleCell.page.isLoading, waffleCell.loadError == nil {
                    waffleCell.loadURL(urlString: waffleCell.address)
                }
            }
            .onChange(of: waffleCell.page.url) {
                // A failed load leaves no URL: keep the address so the failure state can retry it.
                if waffleCell.page.url == nil { return }
                waffleCell.address = waffleCell.page.url?.absoluteString ?? ""
                model.noteAddressChange(for: waffleCell)
            }
            .opacity(isEmpty ? 0 : 1)
            .allowsHitTesting(!isEmpty)
            .overlay {
                if isEmpty {
                    EmptyCellView(isPane: isPhonePane, isOnlyPane: paneCount == 1, onAddPane: onAddPane)
                }
            }
        .overlay {
            if waffleCell.loadError != nil, !isEmpty, !waffleCell.isLoading {
                LoadFailureView(retry: { waffleCell.reloadCell() })
            }
        }
        .clipShape(cellShape)
        .overlay {
            if isPoppedOut {
                PoppedOutPlaceholder(cornerRadius: cornerRadius, requestPopBack: requestPopBack)
            } else if isSelected {
                // Soft glow selection instead of harsh border
                cellShape
                    .stroke(Color.accentColor, lineWidth: 3)
                    .shadow(color: Color.accentColor.opacity(0.5), radius: 8)
                    .padding(1)
                    .allowsHitTesting(!isPhonePane)
            } else if isPhonePane {
                // Phone panes take touches directly (see `selectsOnTouch`): nothing sits over
                // the page, so an unselected pane scrolls and follows links like any other.
                EmptyView()
            } else {
                // Hover highlight for non-selected cells
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.accentColor.opacity(isHovered ? 0.6 : 0), lineWidth: 2)
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(Color.accentColor.opacity(isHovered ? 0.08 : 0))
                    )
                    .animation(.easeInOut(duration: 0.15), value: isHovered)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        model.select(waffleCell)
                    }
                    .contextMenu {
                        if !isEmpty {
                            Button(String(localized: "Copy To Selected Cell")) {
                                model.loadInSelectedCell(waffleCell.address)
                            }
                            Button(String(localized: "Reload"), systemImage: "arrow.clockwise") {
                                waffleCell.reloadCell()
                            }
                            AutoRefreshMenu(
                                selection: waffleCell.refreshInterval,
                                onSelect: { model.setRefreshInterval($0, for: waffleCell) }
                            )
                            ContentBlockingMenu(
                                mode: waffleCell.contentBlockingMode,
                                isActive: model.contentBlocking.isActive(for: waffleCell),
                                globalEnabled: model.contentBlocking.isGloballyEnabled,
                                siteHasException: model.contentBlocking.hasException(for: waffleCell.address),
                                canExceptSite: ContentBlockingPolicy.normalizedHost(from: waffleCell.address) != nil,
                                onSelect: { model.setContentBlockingMode($0, for: waffleCell) },
                                onToggleSite: { model.toggleBlockingException(for: waffleCell) }
                            )
                        }
                    }
            }
        }
        .overlay {
            // Loading indicator: the cell's own rounded border fills in as
            // the page loads. It hugs the waffle shape (no straight strip
            // jutting past the corners) and uses the brand tertiary color.
            // Applied after the selection overlay so it draws on top of the
            // accent selection stroke instead of hiding beneath it.
            if waffleCell.isLoading && !isEmpty {
                cellShape
                    .trim(from: 0, to: waffleCell.loadingProgress)
                    .stroke(
                        Color.waffleTertiary,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .padding(1.5)
                    .animation(.easeInOut(duration: 0.2), value: waffleCell.loadingProgress)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .topTrailing) {
            // Phone panes report the count in the ••• menu instead of over the page.
            if !isPhonePane, !isEmpty, !isPoppedOut, waffleCell.blockedCount > 0,
               model.contentBlocking.isActive(for: waffleCell) {
                BlockedCountBadge(count: waffleCell.blockedCount)
                    .padding(8)
            }
        }
        .task(id: isPoppedOut) {
            // The blocker can't report counts directly; poll the page's counter lightly.
            guard !isPoppedOut else { return }
            while !Task.isCancelled {
                await waffleCell.refreshBlockedCount()
                try? await Task.sleep(for: .seconds(1.5))
            }
        }
        .modifier(PhoneTouchSelection(isEnabled: isPhonePane && !isPoppedOut) {
            if model.selectedCell != waffleCell { model.select(waffleCell) }
            model.notePaneTouched()
        })
        .onHover { hovering in
            isHovered = hovering
        }
        // Accept URL drops (e.g. a bookmark dragged from the sidebar).
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            waffleCell.loadURL(urlString: url.absoluteString)
            model.select(waffleCell)
            return true
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityCellLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(isSelected ? Text("") : Text("Double tap to select this cell"))
    }

    private var accessibilityCellLabel: Text {
        if isEmpty {
            return Text("Empty cell")
        }
        if !waffleCell.page.title.isEmpty {
            return Text(waffleCell.page.title)
        }
        return Text(URLDisplayFormatter.compact(waffleCell.address))
    }
}

/// Phone panes: the first touch inside a pane selects it and still reaches the page, so a
/// pane that isn't selected yet can be scrolled, tapped and pinched straight away.
/// (The iPad's unselected cells keep their tap-to-select overlay instead.) The drag gesture
/// is recognized alongside the web view's own recognizers and never claims the touch.
private struct PhoneTouchSelection: ViewModifier {
    let isEnabled: Bool
    let onTouchDown: () -> Void
    @State private var isTouching = false

    func body(content: Content) -> some View {
        if isEnabled {
            content.simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isTouching else { return }
                        isTouching = true
                        onTouchDown()
                    }
                    .onEnded { _ in isTouching = false }
            )
        } else {
            content
        }
    }
}

/// Overlay shown in the grid slot of a cell that is open in another window.
private struct PoppedOutPlaceholder: View {
    let cornerRadius: CGFloat
    let requestPopBack: () -> Void

    var body: some View {
        ZStack {
            // Same calm surface as EmptyCellView.
            Color(uiColor: .systemGroupedBackground)

            ViewThatFits(in: .vertical) {
                // Full version
                VStack(spacing: 16) {
                    Text("Popped Out")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)

                    Text("This cell is open in another window")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)


                    popBackButton
                        .fontWeight(.semibold)
                }
                .padding(24)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(40)

                // Compact version
                VStack(spacing: 12) {
                    Text("Popped Out")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)

                    popBackButton
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .padding(16)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(20)

                // Minimal version
                popBackButton
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(8)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    private var popBackButton: some View {
        Button {
            requestPopBack()
        } label: {
            Label(String(localized: "Pop Back"), systemImage: "arrow.down.backward")
        }
        .buttonStyle(.wafflePrimary)
        .accessibilityHint(Text("Returns the cell to the grid"))
    }
}

#Preview {
    WaffleGridView(
        model: GridModel(),
        requestPopBack: {}
    )
}
#endif
