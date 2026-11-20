//
//  PhoneMainView.swift
//  WaffleComposition
//
//  The browsing window on iPhone and iPhone Duo. Instead of the iPad's rows x cols grid
//  it shows two to four resizable panes:
//
//  - compact width (every iPhone, and the Duo's outer display): up to two panes, stacked in
//    portrait and side by side in landscape, with a draggable divider.
//  - the Duo's inner display (regular/regular size classes): up to four panes, with a gutter
//    on the fold so no pane straddles it.
//  - half-folded laptop pose (Syrup): live panes on the upright half, controls on the flat half.
//
//  Layout is driven by size classes and the fold region, never by orientation or pose
//  checks, as Apple advises. Panes are never re-hosted when the layout changes, so a fold
//  transition does not reload pages.
//

#if os(iOS)
import SwiftUI
import WebKit
import WaffleCore
import WaffleDesignSystem
import WaffleFeatureGrid
import WaffleFeatureSidebar
import WaffleFeatureSettings
import WaffleFeatureSyrup

public struct PhoneMainView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private let session: SessionController
    @State private var sidebarModel: SidebarModel

    @AppStorage("searchProvider") private var searchProviderRawValue: String = SearchProvider.google.rawValue

    @State private var showSettingsSheet = false
    /// Syrup opened from inside Settings (which is itself presented, so the sheet lives there).
    @State private var showSyrupOverSettings = false
    @State private var showLayoutsSheet = false
    /// The user maximized the selected pane.
    @State private var isMaximized = false
    /// The half-folded laptop pose is showing the desk deck (mirrors the geometry-derived value).
    @State private var inDeskMode = false
    /// Half-folded laptop pose on the inner display (desk mode itself needs Syrup).
    @State private var inLaptopPose = false
    /// The user hid the "Desk Mode" offer in the ••• menu for good.
    @AppStorage("deskModeOfferDismissed") private var deskOfferDismissed = false
    @State private var isEditingAddress = false
    /// The pane whose address is being edited; a submit navigates only this pane.
    @State private var editingPaneID: UUID?
    /// Bumped to end address editing without submitting (Cancel, or another pane was selected).
    @State private var dismissEditingToken = 0
    @State private var hinge: HingeSummary = .unknown
    /// iPhone Duo: the address editor card is open (the controls live in the trailing toolbar).
    @State private var showAddressCard = false
    @State private var addressCardText = ""
    @State private var addressCardPaneID: UUID?

    public init(session: SessionController) {
        self.session = session
        _sidebarModel = State(initialValue: session.makeSidebarModel())
    }

    private var grid: GridModel { session.grid }

    private var searchProvider: SearchProvider {
        SearchProvider(rawValue: searchProviderRawValue) ?? .google
    }

    private var mode: PaneMode {
        PaneMode.resolve(
            horizontalRegular: horizontalSizeClass == .regular,
            verticalRegular: verticalSizeClass == .regular
        )
    }

    /// The pane shown alone, if any. Compact displays can't hold more than two panes, so
    /// a three- or four-pane arrangement (opened on the inner display) shows the focused pane.
    private var focusedPaneID: UUID? {
        guard let index = PaneFocus.focusedIndex(
            count: grid.paneCount, mode: mode, isDeskMode: inDeskMode,
            isMaximized: isMaximized, selected: grid.selectedPaneIndex
        ) else { return nil }
        return grid.panes[index].id
    }

    /// Panes tucked away behind the focused one; their auto-refresh timers pause.
    private var hiddenPaneIDs: Set<UUID> {
        guard let focused = focusedPaneID else { return [] }
        return Set(grid.panes.map(\.id)).subtracting([focused])
    }

    private var effectiveHinge: HingeSummary {
        #if DEBUG
        if let simulated = DebugFoldSimulation.hinge { return simulated }
        #endif
        return hinge
    }

    // MARK: - Body

    public var body: some View {
        @Bindable var session = session

        GeometryReader { proxy in
            // The reader sits inside the safe area. The layout works in screen coordinates (the
            // fold is reported in the reader's space and converted by its origin), so rebuild
            // the screen size and shift results back into the reader's space when placing views.
            let inset = proxy.safeAreaInsets
            let screenSize = CGSize(
                width: proxy.size.width + inset.leading + inset.trailing,
                height: proxy.size.height + inset.top + inset.bottom
            )
            let origin = CGPoint(x: inset.leading, y: inset.top)
            let reading = FoldSensing.reading(in: proxy, screenSize: screenSize)
            let laptopPose = mode == .inner
                && reading?.isActive == true
                && reading?.gutter.primaryIsHorizontal == false
                && (effectiveHinge == .partiallyOpen || effectiveHinge == .unknown)
            let isDesk = laptopPose && session.canUseDeskMode
            // Duo, except the half-folded laptop pose (which keeps its deck, or its bar): the
            // controls are a column in the trailing strip and the panes run to the edges.
            let toolbar = Self.isFoldableDevice && !isDesk
            // Portrait on the unfolded Duo has a status band across the top, but the status items
            // only occupy the top of the trailing corner: the panes run to the top edge, and only
            // a pane in the trailing column starts below the status.
            let statusInStrip = (toolbar || isDesk) && inset.top >= 40
            let stripWidth = max(inset.trailing, PhoneScreenLayout.toolbarStripWidth)
            let layout = PhoneScreenLayout.compute(
                size: screenSize,
                safe: (inset.top, inset.leading, toolbar ? Self.bottomBand : (mode == .inner && !isEditingAddress ? max(inset.bottom - Self.innerBottomGive, 0) : inset.bottom), inset.trailing),
                fold: reading?.gutter,
                mode: mode,
                deskMode: isDesk,
                barOnFarSide: selectedPaneIsOnFarSide(primaryIsHorizontal: reading?.gutter.primaryIsHorizontal ?? (screenSize.width >= screenSize.height)),
                barHeight: barHeight,
                trailingToolbar: toolbar,
                stripWidth: stripWidth,
                ignoreTopSafeArea: statusInStrip
            )

            ZStack(alignment: .topLeading) {
                PaneWorkspaceView(
                    model: grid,
                    primaryIsHorizontal: layout.primaryIsHorizontal,
                    fold: layout.fold,
                    focusedPaneID: focusedPaneID,
                    leadingDisplayCorners: toolbar ? Self.paneCorners(mode: mode) : (isDesk ? (Self.paneCorners(mode: mode).top, 14) : nil),
                    // Only a pane that reaches the trailing screen edge (Desk Mode's upright half) sits
                    // under the status items; with the toolbar strip the panes stop short of them.
                    trailingTopInset: (statusInStrip && !toolbar) ? inset.top : 0,
                    onAddPane: { session.addPane(mode: mode, isFoldable: Self.isFoldableDevice) }
                )
                .environment(\.duoPanelDense, mode == .inner)
                .frame(width: layout.workspace.width, height: layout.workspace.height)
                .offset(x: layout.workspace.minX - origin.x, y: layout.workspace.minY - origin.y)

                Color.clear.frame(width: 0, height: 0)
                    .onChange(of: laptopPose, initial: true) { _, now in inLaptopPose = now }
                    .onChange(of: isDesk, initial: true) { _, now in
                        inDeskMode = now
                        isMaximized = PaneFocus.reconciledMaximized(isMaximized, count: grid.paneCount, isDeskMode: now)
                    }

                if toolbar {
                    let strip = CGRect(x: screenSize.width - stripWidth, y: 0, width: stripWidth, height: screenSize.height)
                    trailingToolbar(topClearance: statusInStrip ? inset.top + 8 : Self.toolbarTopClearance)
                        .frame(width: strip.width, height: strip.height)
                        .offset(x: strip.minX - origin.x, y: strip.minY - origin.y)
                        .zIndex(3)
                    if showsUnfoldHint {
                        Text("Unfold your iPhone Duo to see all \(grid.paneCount) panes")
                            .font(.caption)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .padding(.horizontal, 12)
                            .frame(height: Self.hintHeight + 8)
                            .glassEffect(.regular, in: .capsule)
                            .dynamicTypeSize(...Self.controlTypeLimit)
                            .allowsHitTesting(false)
                            .frame(width: layout.workspace.width, height: layout.workspace.height - 8, alignment: .bottom)
                            .offset(x: layout.workspace.minX - origin.x, y: layout.workspace.minY - origin.y)
                    }
                    if showAddressCard {
                        addressCardOverlay(layout: layout, origin: origin)
                    }
                }

                if let bar = layout.bar {
                    if let halves = splitBarRects(layout: layout, bar: bar) {
                        // Unfolded Duo: one half of the bar on each side of the hinge, so no
                        // control sits in (or straddles) the fold.
                        controlBar(width: halves.leading.width, side: .leading)
                            .frame(width: halves.leading.width, height: halves.leading.height)
                            .offset(x: halves.leading.minX - origin.x, y: halves.leading.minY - origin.y)
                        controlBar(width: halves.trailing.width, side: .trailing)
                            .frame(width: halves.trailing.width, height: halves.trailing.height)
                            .offset(x: halves.trailing.minX - origin.x, y: halves.trailing.minY - origin.y)
                    } else {
                        controlBar(width: bar.width, side: .whole)
                            .frame(width: bar.width, height: bar.height)
                            .offset(x: bar.minX - origin.x, y: bar.minY - origin.y)
                    }
                }

                if let panel = sidePanelRect(layout: layout) {
                    if session.presentSyrupSheet {
                        sidePanel(panel, origin: origin) { syrupSheet }
                    } else if showLayoutsSheet {
                        sidePanel(panel, origin: origin) { layoutsSheet }
                    }
                }

                if let deck = layout.deck {
                    DeskDeck(
                        session: session,
                        sidebarModel: sidebarModel,
                        mode: mode,
                        width: deck.width,
                        searchProvider: searchProvider,
                        isEditingAddress: $isEditingAddress,
                        editingPaneID: $editingPaneID,
                        dismissEditingToken: $dismissEditingToken,
                        openLayouts: { showLayoutsSheet = true },
                        openSettings: { showSettingsSheet = true }
                    )
                    .frame(width: deck.width, height: deck.height)
                    .offset(x: deck.minX - origin.x, y: deck.minY - origin.y)
                }
            }
        }
        // Duo: the keyboard never reflows the panes; the address card sits above it by design.
        .ignoresSafeArea(.keyboard, edges: Self.isFoldableDevice && !inDeskMode ? .bottom : [])
        .background(Color.wafflePrimary.opacity(0.3).ignoresSafeArea())
        .observingHinge($hinge)
        .animation(.snappy, value: isEditingAddress)
        .animation(.snappy, value: showAddressCard)
        .animation(.snappy, value: showLayoutsSheet)
        .animation(.snappy, value: session.presentSyrupSheet)
        .onAppear {
            grid.contentBlocking.start()
            if !grid.restoreFromSnapshotIfAvailable() {
                grid.makeInitialItem()
            }
            session.adaptWorkspaceToEntitlement()
            sidebarModel.load()
            #if DEBUG
            DebugLibrarySeeding.applyIfRequested(to: sidebarModel)
            #endif
            #if DEBUG
            DebugPaneSeeding.applyIfRequested(to: grid)
            let defaults = UserDefaults.standard
            if defaults.bool(forKey: "WaffleDebugMaximize") { isMaximized = true }
            switch defaults.string(forKey: "WaffleDebugSheet") {
            case "layouts": showLayoutsSheet = true
            case "settings": showSettingsSheet = true
            case "settingsThenDone":
                // Opens Settings, then dismisses it the way Done does: the panes must survive.
                showSettingsSheet = true
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(3000))
                    showSettingsSheet = false
                }
            case "settingsSyrup":
                showSettingsSheet = true
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(2500))
                    showSyrupOverSettings = true
                }
            case "paywallDeskMode": session.requestSyrup(for: .deskMode)
            case "paywallGeneral": session.requestSyrup()
            default: break
            }
            if defaults.string(forKey: "WaffleDebugAction") == "saveLayoutTwice" {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(1500))
                    session.savePaneLayout()
                    try? await Task.sleep(for: .milliseconds(500))
                    session.savePaneLayout()
                }
            }
            if defaults.string(forKey: "WaffleDebugAction") == "addressCard" {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(2500))
                    openAddressCard()
                }
            }
            if defaults.string(forKey: "WaffleDebugAction") == "addPane" {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(1500))
                    session.addPane(mode: mode, isFoldable: Self.isFoldableDevice)
                }
            }
            #endif
        }
        .onChange(of: grid.selectedCell) { _, _ in
            // Selecting another pane ends editing: the field shows that pane's address again.
            if isEditingAddress { dismissEditingToken += 1 }
            showAddressCard = false
        }
        .onChange(of: grid.paneTouchCount) { _, _ in
            if isEditingAddress { dismissEditingToken += 1 }
        }
        .onChange(of: hiddenPaneIDs, initial: true) { _, hidden in
            grid.setHiddenCells(hidden)
        }
        .onChange(of: grid.paneCount) { _, count in
            isMaximized = PaneFocus.reconciledMaximized(isMaximized, count: count, isDeskMode: inDeskMode)
        }
        .onChange(of: scenePhase, initial: true) { _, newPhase in
            if newPhase == .inactive || newPhase == .background {
                grid.persistNow()
            }
            grid.setAppActive(newPhase == .active)
        }
        .sheet(isPresented: Binding(
            get: { session.presentSyrupSheet && !usesSidePanel },
            set: { session.presentSyrupSheet = $0 }
        )) { syrupSheet }
        .settingsPresentation(isPresented: $showSettingsSheet, fullPage: mode == .inner && Self.isFoldableDevice) {
            SettingsView(
                model: session.makeSettingsModel(),
                isSyrupEnabled: session.isSyrupEnabled,
                // Settings is itself a sheet or full-page cover, and a view cannot present a
                // second one over it from underneath: Syrup opens from inside Settings.
                requestSyrup: { self.showSyrupOverSettings = true },
                openInApp: { grid.loadInSelectedCell($0) },
                usesPaneWording: true,
                restorePurchases: { await self.session.store.restore() },
                contentBlocking: ContentBlockingSettingsBinding(
                    isEnabled: Binding(
                        get: { grid.contentBlocking.isGloballyEnabled },
                        set: { grid.contentBlocking.isGloballyEnabled = $0 }
                    ),
                    exceptionHosts: grid.contentBlocking.exceptionHosts,
                    removeException: { grid.contentBlocking.removeException(host: $0) },
                    listTitles: grid.contentBlocking.listTitles
                )
            )
            .sheet(isPresented: Binding(
                get: { showSyrupOverSettings && !settingsIsFullPage },
                set: { showSyrupOverSettings = $0 }
            )) { settingsSyrup }
            .overlay {
                if showSyrupOverSettings && settingsIsFullPage {
                    // The unfolded Duo's full page: Syrup is a card in the right half, clear of
                    // the hinge, over a dimmed page.
                    GeometryReader { proxy in
                        let fold = proxy.foldCenterXIfAvailable ?? proxy.size.width / 2
                        ZStack(alignment: .topLeading) {
                            Color.black.opacity(0.25)
                                .ignoresSafeArea()
                                .onTapGesture { showSyrupOverSettings = false }
                            settingsSyrup
                                .frame(width: max(0, proxy.size.width - fold - 28 - 12), height: max(0, proxy.size.height - 24))
                                .background(Color(.systemBackground))
                                .clipShape(.rect(cornerRadius: 20, style: .continuous))
                                .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
                                .offset(x: fold + 28, y: 12)
                        }
                    }
                    .transition(.opacity)
                }
            }
            .animation(.snappy, value: showSyrupOverSettings)
        }
        .sheet(isPresented: Binding(
            get: { showLayoutsSheet && !usesSidePanel },
            set: { showLayoutsSheet = $0 }
        )) { layoutsSheet }
        .userActivity(
            "com.molargiksoftware.Waffle.browsing",
            isActive: HandoffEligibility.webpageURL(for: grid.selectedCell?.address ?? "") != nil
        ) { activity in
            guard let cell = grid.selectedCell,
                  let url = HandoffEligibility.webpageURL(for: cell.address) else { return }
            activity.title = cell.page.title.isEmpty ? cell.address : cell.page.title
            activity.webpageURL = url
            activity.isEligibleForHandoff = true
            activity.isEligibleForSearch = true
            self.session.annotateBrowsingActivity(activity, forAddress: cell.address)
        }
        .task {
            for await _ in self.session.observeLibraryChanges() {
                sidebarModel.load()
            }
        }
        .toast(message: session.errorHandler.toastMessage, bottomInset: barHeight + PhoneScreenLayout.margin * 2 + 8) {
            self.session.errorHandler.dismissToast()
        }
        .errorAlert(Binding(
            get: { self.session.errorHandler.currentError },
            set: { _ in self.session.errorHandler.dismiss() }
        ))
    }

    // MARK: - Unfolded Duo geometry

    private var settingsIsFullPage: Bool { mode == .inner && Self.isFoldableDevice }

    private var settingsSyrup: some View {
        SyrupView(
            store: session.store,
            phonePitch: SyrupPitch(
                trigger: .general,
                device: mode == .inner ? .iPhoneDuoInner : (Self.isFoldableDevice ? .iPhoneDuoOuter : .iPhone)
            ),
            onPurchased: { self.showSyrupOverSettings = false },
            onClose: { self.showSyrupOverSettings = false }
        )
    }

    private var syrupSheet: some View {
        SyrupView(
            store: session.store,
            phonePitch: SyrupPitch(
                trigger: session.syrupTrigger,
                device: mode == .inner ? .iPhoneDuoInner : (Self.isFoldableDevice ? .iPhoneDuoOuter : .iPhone)
            ),
            onPurchased: { self.session.presentSyrupSheet = false },
            onClose: { self.session.presentSyrupSheet = false }
        )
    }

    private func sidePanel<Content: View>(_ panel: CGRect, origin: CGPoint, @ViewBuilder content: () -> Content) -> some View {
        content()
            .environment(\.duoPanelDense, true)
            .frame(width: panel.width, height: panel.height)
            .background(Color(.systemBackground))
            .clipShape(.rect(cornerRadius: 14))
            .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
            .offset(x: panel.minX - origin.x, y: panel.minY - origin.y)
            .transition(.move(edge: .trailing).combined(with: .opacity))
            .zIndex(2)
    }

    /// The unfolded Duo's inner display: panes sit side by side around a vertical fold.
    private var usesSidePanel: Bool { mode == .inner && !inDeskMode }

    /// Where group A ends and group B begins on the unfolded Duo (screen coordinates, along the
    /// primary axis: x when the hinge is vertical (landscape), y when it is horizontal
    /// (portrait)), taken from the same frames the panes use, so bars and panels line up with
    /// the pane edges whether the fold is flat or partly open.
    private func seam(layout: PhoneScreenLayout) -> (aEnd: CGFloat, bStart: CGFloat)? {
        guard mode == .inner else { return nil }
        let horizontal = layout.primaryIsHorizontal
        let frames = PaneFrameCalculator.frames(
            count: max(grid.paneCount, 2),
            ratios: grid.paneRatios,
            size: layout.workspace.size,
            primaryIsHorizontal: horizontal,
            fold: layout.fold
        )
        let slots = PaneFrameCalculator.slots(count: max(grid.paneCount, 2), primaryIsHorizontal: horizontal)
        guard let a = slots.a.first, let b = slots.b.first, a < frames.panes.count, b < frames.panes.count else { return nil }
        if horizontal {
            return (frames.panes[a].maxX + layout.workspace.minX, frames.panes[b].minX + layout.workspace.minX)
        }
        return (frames.panes[a].maxY + layout.workspace.minY, frames.panes[b].minY + layout.workspace.minY)
    }

    /// The two halves of the control bar either side of the seam (screen coordinates).
    private func splitBarRects(layout: PhoneScreenLayout, bar: CGRect) -> (leading: CGRect, trailing: CGRect)? {
        guard layout.primaryIsHorizontal, let seam = seam(layout: layout) else { return nil }
        let left = layout.workspace.minX, right = layout.workspace.maxX
        guard seam.aEnd - left > 120, right - seam.bStart > 120 else { return nil }
        return (
            CGRect(x: left, y: bar.minY, width: seam.aEnd - left, height: bar.height),
            CGRect(x: seam.bStart, y: bar.minY, width: right - seam.bStart, height: bar.height)
        )
    }

    /// Layouts & Bookmarks and the Syrup sheet on the unfolded Duo: a panel over group B's
    /// side (leading edge on the pane edge, never across the hinge).
    private func sidePanelRect(layout: PhoneScreenLayout, bottomInset: CGFloat = 0) -> CGRect? {
        guard usesSidePanel, let seam = seam(layout: layout) else { return nil }
        // With the controls in the trailing toolbar the panel is its half's full height, down to
        // the display's bottom edge (its own content keeps clear of the home indicator).
        let bottom = layout.bar == nil ? layout.workspace.maxY + Self.bottomBand : layout.workspace.maxY + PhoneScreenLayout.margin + barHeight
        if layout.primaryIsHorizontal {
            let top = layout.workspace.minY
            return CGRect(x: seam.bStart, y: top, width: layout.workspace.maxX - seam.bStart, height: bottom - top)
        }
        // Portrait (horizontal hinge): the panel is the lower half, full width.
        return CGRect(x: layout.workspace.minX, y: seam.bStart, width: layout.workspace.width, height: bottom - seam.bStart)
    }

    private func selectedPaneIsOnFarSide(primaryIsHorizontal: Bool) -> Bool {
        guard let index = grid.selectedPaneIndex else { return false }
        return PaneFrameCalculator.slots(count: grid.paneCount, primaryIsHorizontal: primaryIsHorizontal).b.contains(index)
    }

// MARK: - Trailing toolbar (iPhone Duo)

    /// The Duo's controls: a column of circular glass buttons in the strip under the clock,
    /// anchored to the bottom (the thumb). Back, the address button, the pane switcher (only
    /// while one pane of three or four shows), maximize, reload and •••. The pane switcher and
    /// Add Pane stay reachable: the switcher button here, Add Pane and Go to Pane in •••.
    private func trailingToolbar(topClearance: CGFloat) -> some View {
        let showsMaximize = PaneFocus.offersMaximize(count: grid.paneCount, mode: mode, isDeskMode: inDeskMode)
        return VStack(spacing: 10) {
            circleButton("Back", systemImage: "chevron.backward") { grid.selectedCell?.goBack() }
                .opacity(grid.selectedCell?.canGoBack == true ? 1 : 0.45)
            verticalAddressBar
            if showsSwitcher { paneSwitcher }
            if showsMaximize {
                circleButton(
                    focusedPaneID == nil ? "Maximize Pane" : "Show All Panes",
                    systemImage: focusedPaneID == nil
                        ? "arrow.up.left.and.arrow.down.right"
                        : "arrow.down.right.and.arrow.up.left"
                ) { toggleMaximize() }
            }
            reloadButton
            menuButton
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, topClearance)
        .padding(.bottom, Self.bottomBand)
    }

    /// The address bar turned 90 degrees: a tall glass capsule, as wide as the round buttons and
    /// as tall as the strip allows, showing the page's host reading bottom to top (like a book
    /// spine, middle truncated) with a globe at its end. Tap opens the address card.
    private var verticalAddressBar: some View {
        let address = grid.selectedCell?.address ?? ""
        let host = address.isEmpty ? "" : bareHost(address)
        let width = AppConfiguration.barControlHeight
        return Button { openAddressCard() } label: {
            VStack(spacing: 6) {
                Image(systemName: address.isEmpty ? "magnifyingglass" : "globe")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 12)
                GeometryReader { g in
                    Text(host.isEmpty ? String(localized: "Search or enter a URL") : host)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(host.isEmpty ? .secondary : .primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(width: max(g.size.height, 1), height: g.size.width)
                        .rotationEffect(.degrees(-90))
                        .position(x: g.size.width / 2, y: g.size.height / 2)
                }
                .padding(.bottom, 8)
            }
            .frame(width: width)
            .frame(maxHeight: .infinity)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .frame(minHeight: 96)
        .glassEffect(.regular.interactive(), in: .capsule)
        .accessibilityLabel(Text(address.isEmpty ? "Address bar" : LocalizedStringKey(address)))
        .accessibilityHint(Text("Edit the address"))
    }

    private func bareHost(_ address: String) -> String {
        let host = URLDisplayFormatter.phoneDisplay(address)
        return host.firstIndex(of: "/").map { String(host[..<$0]) } ?? host
    }

    private func openAddressCard() {
        addressCardPaneID = grid.selectedCell?.id
        addressCardText = grid.selectedCell?.address ?? ""
        showAddressCard = true
    }

    private func closeAddressCard() { showAddressCard = false }

    private func submitAddressCard() {
        grid.addressText = addressCardText
        grid.submitAddress(using: searchProvider, toPaneID: addressCardPaneID)
        showAddressCard = false
    }

    /// The address card sits at the top of the selected pane's half (clear of the hinge and
    /// of the keyboard, which rises from the bottom); a tap outside closes it.
    private func addressCardOverlay(layout: PhoneScreenLayout, origin: CGPoint) -> some View {
        let half = selectedPaneHalf(layout: layout)
        let width = min(max(half.width - 24, 200), 440)
        return ZStack(alignment: .topLeading) {
            Color.black.opacity(0.18)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { closeAddressCard() }
            AddressEditCard(text: $addressCardText, onSubmit: submitAddressCard, onCancel: closeAddressCard)
                .frame(width: width)
                .offset(x: half.minX + (half.width - width) / 2 - origin.x, y: half.minY + 12 - origin.y)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
        .zIndex(4)
    }

    /// The side of the hinge the selected pane is on (screen coordinates), or the whole
    /// workspace on a single display.
    private func selectedPaneHalf(layout: PhoneScreenLayout) -> CGRect {
        // Portrait: the card always sits in the upper band, clear of the hinge and of the
        // keyboard that rises over the lower half.
        guard layout.primaryIsHorizontal, let seam = seam(layout: layout), grid.paneCount > 1 else { return layout.workspace }
        let onFarSide = selectedPaneIsOnFarSide(primaryIsHorizontal: true)
        return onFarSide
            ? CGRect(x: seam.bStart, y: layout.workspace.minY, width: layout.workspace.maxX - seam.bStart, height: layout.workspace.height)
            : CGRect(x: layout.workspace.minX, y: layout.workspace.minY, width: seam.aEnd - layout.workspace.minX, height: layout.workspace.height)
    }

    // MARK: - Control bar

    /// The bar's circle controls stop scaling here so a glyph always stays inside its 44-point
    /// circle; the address field and labels scale up to the same cap.
    static let controlTypeLimit = DynamicTypeSize.xxxLarge

    /// Whether the focused pane is the only one visible while others are open behind it.
    private var showsSwitcher: Bool { focusedPaneID != nil && grid.paneCount > 2 }

    /// Duo, closed, three or four panes open: a line on the bar says unfolding shows them all.
    private var showsUnfoldHint: Bool {
        mode == .compact && grid.paneCount > PaneLimits.maxCompactPanes && Self.isFoldableDevice
    }

    private var barHeight: CGFloat {
        if Self.isFoldableDevice && !inDeskMode { return 0 }
        return (mode == .inner ? Self.innerBarHeight : PhoneScreenLayout.barHeight) + (showsUnfoldHint ? Self.hintHeight : 0)
    }
    /// The unfolded display is short: a slimmer bar that also uses part of the home-indicator
    /// band, so the panes get the height back.
    static let innerBarHeight: CGFloat = 50
    static let innerBottomGive: CGFloat = 16
    static let hintHeight: CGFloat = 20
    /// A small band below the panes for the home indicator (the old bar left about 50 pt).
    static let bottomBand: CGFloat = 14
    /// The Duo's real display corner radii (the simulator device profile, in points): 55 on every
    /// corner of the inner display; the outer display is 8 on the hinge side and 59 on the other.
    /// The panes' leading corners sit flush on the leading edge, so the top one takes the display
    /// radius itself and the bottom one the radius less the band below it (concentric). The
    /// outer display's leading corners are the 8 pt ones: smaller than a pane's own radius, so
    /// panes there keep their usual corners.
    static func paneCorners(mode: PaneMode) -> (top: CGFloat, bottom: CGFloat) {
        mode == .inner ? (55, 55 - bottomBand) : (8, 8)
    }
    /// The system draws the clock and status at the top of the trailing strip. The column grows
    /// with what it shows: a Focus icon above the clock and the Wi-Fi ring with its page dots end
    /// near 168 pt on a device (the bare clock and Wi-Fi end near 97 pt), and the safe area does
    /// not report it. Clear the tallest, so Back never sits under the status.
    static let toolbarTopClearance: CGFloat = 180

    static var isFoldableDevice: Bool {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "WaffleDebugFoldable") { return true }
        #endif
        // The one Duo check lives in the design system (`PhoneDuo`).
        return PhoneDuo.isDuo
    }

    enum BarSide { case whole, leading, trailing }

    private func controlBar(width: CGFloat, side: BarSide) -> some View {
        @Bindable var grid = grid
        let showsMaximize = PaneFocus.offersMaximize(count: grid.paneCount, mode: mode, isDeskMode: inDeskMode)
        let buttonCount = (showsMaximize ? 4 : 3)
        let reserved = side == .leading
            ? CGFloat(52 + 16)
            : CGFloat(buttonCount) * 44 + CGFloat(buttonCount) * 8 + 16 + (showsSwitcher ? Self.switcherWidth + 8 : 0)

        return VStack(spacing: 0) {
            if showsUnfoldHint && !isEditingAddress {
                Text("Unfold your iPhone Duo to see all \(grid.paneCount) panes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(height: Self.hintHeight)
                    .dynamicTypeSize(...Self.controlTypeLimit)
            }
            HStack(spacing: 8) {
                if side == .trailing { Spacer(minLength: 0) }
                if side != .trailing && !isEditingAddress {
                    circleButton("Back", systemImage: "chevron.backward") { grid.selectedCell?.goBack() }
                        .opacity(grid.selectedCell?.canGoBack == true ? 1 : 0.45)
                }

                if side != .trailing {
                AddressBarView(
                    text: $grid.addressText,
                    placeholder: String(localized: "Search or enter a URL"),
                    availableWidth: isEditingAddress ? width - Self.cancelButtonWidth : width,
                    reservedControlWidth: reserved,
                    onSubmit: { grid.submitAddress(using: searchProvider, toPaneID: editingPaneID) },
                    onEditingChanged: { editing in
                        editingPaneID = editing ? grid.selectedCell?.id : nil
                        withAnimation(.snappy) { isEditingAddress = editing }
                    },
                    dismissEditingToken: dismissEditingToken,
                    phoneStyle: true
                )
                }

                if isEditingAddress {
                    if side != .trailing { cancelEditingButton }
                } else if side != .leading {
                    if showsSwitcher { paneSwitcher }
                    if showsMaximize {
                        circleButton(
                            focusedPaneID == nil ? "Maximize Pane" : "Show All Panes",
                            systemImage: focusedPaneID == nil
                                ? "arrow.up.left.and.arrow.down.right"
                                : "arrow.down.right.and.arrow.up.left"
                        ) { toggleMaximize() }
                    }
                    reloadButton
                    menuButton
                }
            }
            .frame(height: AppConfiguration.barControlHeight + (mode == .inner ? 4 : 12))
        }
        .padding(.horizontal, 6)
    }

    /// Room the Cancel button takes beside the expanded address field.
    static let cancelButtonWidth: CGFloat = 84
    static let switcherWidth: CGFloat = 64

    private var cancelEditingButton: some View {
        Button { dismissEditingToken += 1 } label: {
            Text("Cancel")
                .font(.body)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 12)
                .frame(minWidth: 44, minHeight: AppConfiguration.barControlHeight)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
        .dynamicTypeSize(...Self.controlTypeLimit)
        .accessibilityHint(Text("Stops editing the address"))
    }

    /// "1 of 3": which pane is showing out of how many are open. Tap for the next pane;
    /// touch and hold to pick one.
    private var paneSwitcher: some View {
        let index = (grid.selectedPaneIndex ?? 0) + 1
        return Menu {
            paneList
        } label: {
            Text("\(index) of \(grid.paneCount)")
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: Self.switcherWidth, height: AppConfiguration.barControlHeight)
                .contentShape(Capsule())
        } primaryAction: {
            cycleSelectedPane()
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
        .dynamicTypeSize(...Self.controlTypeLimit)
        .accessibilityLabel(Text("Pane \(index) of \(grid.paneCount)"))
        .accessibilityHint(Text("Shows the next pane. Touch and hold to choose a pane"))
    }

    @ViewBuilder
    private var paneList: some View {
        ForEach(Array(grid.panes.enumerated()), id: \.element.id) { index, pane in
            Button {
                grid.select(pane)
            } label: {
                Label(paneTitle(pane, index: index), systemImage: grid.selectedCell == pane ? "checkmark" : "rectangle")
            }
        }
    }

    private func cycleSelectedPane() {
        let panes = grid.panes
        guard panes.count > 1 else { return }
        let next = ((grid.selectedPaneIndex ?? -1) + 1) % panes.count
        grid.select(panes[next])
    }

    private func glyph(_ systemImage: String) -> some View {
        Image(systemName: systemImage)
            .dynamicTypeSize(...Self.controlTypeLimit)
            .frame(width: AppConfiguration.barControlHeight, height: AppConfiguration.barControlHeight)
            .contentShape(Circle())
    }

    private func circleButton(_ title: LocalizedStringKey, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            glyph(systemImage)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel(Text(title))
    }

    /// Tap reloads; touch and hold opens the pane's auto-refresh options.
    private var reloadButton: some View {
        Menu {
            autoRefreshItem
        } label: {
            glyph(grid.selectedCell?.refreshInterval == .off || grid.selectedCell == nil
                  ? "arrow.clockwise" : "arrow.trianglehead.2.clockwise.rotate.90")
        } primaryAction: {
            grid.selectedCell?.reloadCell()
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel(Text("Reload"))
        .accessibilityHint(Text("Reloads the selected pane. Touch and hold for auto-refresh options"))
    }

    @ViewBuilder
    private var autoRefreshItem: some View {
        if let cell = grid.selectedCell {
            AutoRefreshMenu(
                selection: cell.refreshInterval,
                onSelect: { grid.setRefreshInterval($0, for: cell) }
            )
        }
    }

    /// The ••• menu, grouped and in reading order (`.menuOrder(.fixed)`: the first group is at
    /// the top and Settings, last, sits nearest the thumb and is never pushed off screen):
    /// this pane's arrangement, the page's own actions, layouts, then Settings.
    private var menuButton: some View {
        let addDecision = PaneLimits.addPane(currentCount: grid.paneCount, mode: mode, isSyrupEnabled: session.isSyrupEnabled)
        let atLimit = addDecision == .atDeviceLimit
        let selected = grid.selectedCell
        return Menu {
            // Panes
            Button { session.addPane(mode: mode, isFoldable: Self.isFoldableDevice) } label: {
                Label {
                    if atLimit {
                        Text("Add Pane") + Text(verbatim: " · ")
                            + Text(mode == .compact && Self.isFoldableDevice ? LocalizedStringKey("Unfold for More") : LocalizedStringKey("Limit Reached"))
                    } else {
                        Text("Add Pane")
                    }
                } icon: {
                    Image(systemName: "plus.rectangle.on.rectangle")
                }
            }
            .disabled(atLimit)

            if PaneFocus.offersMaximize(count: grid.paneCount, mode: mode, isDeskMode: inDeskMode) {
                Button { toggleMaximize() } label: {
                    Label(
                        focusedPaneID == nil ? "Maximize Pane" : "Show All Panes",
                        systemImage: focusedPaneID == nil ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left"
                    )
                }
            }
            if grid.paneCount == 2 {
                Button { grid.swapPanes(0, 1) } label: {
                    Label("Swap Panes", systemImage: "arrow.left.arrow.right")
                }
            }
            if grid.paneCount > 1, let selected {
                Button(role: .destructive) { session.removePane(selected) } label: {
                    Label("Close “\(paneName(selected))” Pane", systemImage: "xmark.rectangle")
                }
                if grid.paneCount > 2 {
                    Menu {
                        paneList
                    } label: {
                        Label("Go to Pane", systemImage: "rectangle.on.rectangle")
                    }
                }
            }

            Divider()

            // This pane's page, in one submenu so the menu stays short enough to show
            // Settings without scrolling.
            Menu {
                if let selected, selected.blockedCount > 0, grid.contentBlocking.isActive(for: selected) {
                    // The count the iPad shows as a badge over the page.
                    Button {} label: {
                        Label("\(selected.blockedCount) items blocked on this page", systemImage: "shield.lefthalf.filled")
                    }
                    .disabled(true)
                }
                Button { grid.selectedCell?.goForward() } label: {
                    Label("Forward", systemImage: "chevron.forward")
                }
                .disabled(selected?.canGoForward != true)
                Button { grid.selectedCell?.reloadCell() } label: {
                    Label("Reload", systemImage: "arrow.clockwise")
                }
                .disabled(selected == nil)
                if let selected {
                    ContentBlockingMenu(
                        mode: selected.contentBlockingMode,
                        isActive: grid.contentBlocking.isActive(for: selected),
                        globalEnabled: grid.contentBlocking.isGloballyEnabled,
                        siteHasException: grid.contentBlocking.hasException(for: selected.address),
                        canExceptSite: ContentBlockingPolicy.normalizedHost(from: selected.address) != nil,
                        onSelect: { grid.setContentBlockingMode($0, for: selected) },
                        onToggleSite: { grid.toggleBlockingException(for: selected) }
                    )
                }
                autoRefreshItem
            } label: {
                Label("This Page", systemImage: "safari")
            }

            Divider()

            // Layouts
            Button { session.savePaneLayout() } label: {
                Label("Save Layout", systemImage: "square.and.arrow.down")
            }
            Button { showLayoutsSheet = true } label: {
                Label("Layouts & Bookmarks", systemImage: "rectangle.split.2x1")
            }

            Divider()

            if inLaptopPose, !session.canUseDeskMode, !deskOfferDismissed {
                Button { session.requestSyrup(for: .deskMode) } label: {
                    Label("Desk Mode", systemImage: "drop.fill")
                }
                Button { deskOfferDismissed = true } label: {
                    Label("Hide Desk Mode Offer", systemImage: "eye.slash")
                }
            }
            Button { showSettingsSheet = true } label: {
                Label("Settings", systemImage: "gearshape")
            }
        } label: {
            glyph("ellipsis")
        }
        .menuOrder(.fixed)
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel(Text("Panes and layouts"))
        .accessibilityHint(Text("Add or close panes, save layouts, and open settings"))
    }

    /// The pane's site, or "Pane N", for menu titles that name which pane an action affects.
    private func paneName(_ pane: WaffleCell) -> String {
        if !pane.address.isEmpty {
            let host = URLDisplayFormatter.phoneDisplay(pane.address)
            let bare = host.firstIndex(of: "/").map { String(host[..<$0]) } ?? host
            // The short host the address pill falls back to ("wikipedia.org", not
            // "en.wikipedia.org"), so a menu title does not wrap inside the name.
            let short = URLDisplayFormatter.registrableDomain(of: bare)
            return short.count > 20 ? String(short.prefix(19)) + "…" : short
        }
        let index = (grid.panes.firstIndex(of: pane) ?? 0) + 1
        return String(localized: "Pane \(index)")
    }

    private func paneTitle(_ pane: WaffleCell, index: Int) -> String {
        if !pane.page.title.isEmpty { return pane.page.title }
        if !pane.address.isEmpty { return URLDisplayFormatter.phoneDisplay(pane.address) }
        return String(localized: "Pane \(index + 1)")
    }

    // MARK: - Layouts sheet

    private var layoutsSheet: some View {
        NavigationStack {
            SidebarView(
                model: sidebarModel,
                applyPreset: { preset in
                    session.applyPaneLayout(preset, mode: mode)
                    showLayoutsSheet = false
                },
                applyBookmark: { address in
                    grid.loadInSelectedCell(address)
                    showLayoutsSheet = false
                },
                currentGrid: {
                    let count = grid.paneCount
                    let shape = PaneLimits.gridShape(forPaneCount: count)
                    return (
                        rows: shape.rows, cols: shape.cols,
                        urls: grid.flattenedAddresses(),
                        refreshIntervals: grid.flattenedRefreshIntervals(),
                        paneCount: count,
                        paneRatios: grid.paneRatios.array
                    )
                },
                currentCell: {
                    guard let cell = grid.selectedCell, !cell.address.isEmpty else { return nil }
                    return (address: cell.address, title: cell.page.title)
                },
                isSyrupEnabled: session.isSyrupEnabled,
                canMakePresets: PaneLimits.canSaveLayout(existingCount: sidebarModel.presets.count, isSyrupEnabled: session.isSyrupEnabled),
                requestSyrup: {
                    // One sheet at a time: close this one, then show the paywall.
                    showLayoutsSheet = false
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(450))
                        session.requestSyrup(for: .secondLayout)
                    }
                },
                isPhoneLayouts: true
            )
            .navigationTitle(Text("Layouts & Bookmarks"))
            .navigationBarTitleDisplayMode(.inline)
            // The sheet covers the screen's own toast, so it carries one ("Updated “…”").
            .toast(message: session.errorHandler.toastMessage) {
                self.session.errorHandler.dismissToast()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showLayoutsSheet = false } label: {
                        Label("Done", systemImage: "checkmark").labelStyle(.titleAndIcon)
                    }
                }
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - Actions

    private func toggleMaximize() {
        if focusedPaneID != nil {
            isMaximized = false
        } else {
            isMaximized = true
        }
    }
}

// MARK: - Desk mode

/// The flat half of a half-folded Duo: pane switcher, refresh timers and layouts, so the
/// upright half is all web content.
private struct DeskDeck: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let session: SessionController
    let sidebarModel: SidebarModel
    let mode: PaneMode
    let width: CGFloat
    let searchProvider: SearchProvider
    @Binding var isEditingAddress: Bool
    @Binding var editingPaneID: UUID?
    @Binding var dismissEditingToken: Int
    let openLayouts: () -> Void
    let openSettings: () -> Void

    private var grid: GridModel { session.grid }

    var body: some View {
        @Bindable var grid = grid

        // Scrolls: in landscape (or at large text sizes) the deck's content is taller than
        // the flat half, and nothing may be cut off or sit tight against the bottom edge.
        ScrollView(.vertical) {
        VStack(alignment: .leading, spacing: 20) {
            // Panes: tall tiles with the page title and the refresh timer on the tile.
            sectionTitle("Panes")
            HStack(spacing: 10) {
                ForEach(Array(grid.panes.enumerated()), id: \.element.id) { index, pane in
                    paneTile(pane, index: index)
                }
                if grid.paneCount < PaneLimits.maxInnerPanes {
                    Button { session.addPane(mode: mode, isFoldable: PhoneMainView.isFoldableDevice) } label: {
                        Image(systemName: "plus")
                            .font(.title2.weight(.semibold))
                            .frame(width: 64)
                            .frame(maxHeight: .infinity)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 18))
                    .accessibilityLabel(Text("Add Pane"))
                }
            }
            .frame(minHeight: 168)
            .fixedSize(horizontal: false, vertical: true)

            // Address row.
            HStack(spacing: 8) {
                if !isEditingAddress {
                    deckButton("Back", systemImage: "chevron.backward") { grid.selectedCell?.goBack() }
                    deckButton("Forward", systemImage: "chevron.forward") { grid.selectedCell?.goForward() }
                }
                AddressBarView(
                    text: $grid.addressText,
                    placeholder: String(localized: "Search or enter a URL"),
                    availableWidth: isEditingAddress ? width - PhoneMainView.cancelButtonWidth : width,
                    reservedControlWidth: 4 * 44 + 4 * 8 + 16,
                    onSubmit: { grid.submitAddress(using: searchProvider, toPaneID: editingPaneID) },
                    onEditingChanged: { editing in
                        editingPaneID = editing ? grid.selectedCell?.id : nil
                        withAnimation(.snappy) { isEditingAddress = editing }
                    },
                    dismissEditingToken: dismissEditingToken,
                    phoneStyle: true
                )
                .frame(maxWidth: .infinity)
                if isEditingAddress {
                    Button { dismissEditingToken += 1 } label: {
                        Text("Cancel")
                            .padding(.horizontal, 12)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .capsule)
                }
                if !isEditingAddress {
                    deckButton("Reload", systemImage: "arrow.clockwise") { grid.selectedCell?.reloadCell() }
                    deckButton("Settings", systemImage: "gearshape", action: openSettings)
                }
            }

            // Layouts: one tap restores a saved arrangement.
            sectionTitle("Layouts")
            HStack(spacing: 8) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Button { session.savePaneLayout() } label: {
                            Label("Save Layout", systemImage: "plus")
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 14)
                                .frame(minHeight: 48)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive(), in: .capsule)

                        ForEach(sidebarModel.presets) { preset in
                            Button { session.applyPaneLayout(preset, mode: mode) } label: {
                                Text(preset.name.isEmpty ? String(localized: "Untitled Preset") : preset.name)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                    .padding(.horizontal, 16)
                                    .frame(minHeight: 48)
                            }
                            .buttonStyle(.plain)
                            .glassEffect(.regular.interactive(), in: .capsule)
                        }
                    }
                }
                deckButton("Layouts & Bookmarks", systemImage: "ellipsis", action: openLayouts)
            }
        }
        .padding(.horizontal, 6)
        .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func sectionTitle(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.leading, 6)
    }

    private func deckButton(_ title: LocalizedStringKey, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .dynamicTypeSize(...PhoneMainView.controlTypeLimit)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel(Text(title))
    }

    /// A pane's tile: tap anywhere above the timer row to select it; the timer row is its own
    /// 44-point control (also holds Close Pane).
    private func paneTile(_ pane: WaffleCell, index: Int) -> some View {
        let isSelected = grid.selectedCell == pane
        return VStack(alignment: .leading, spacing: 0) {
            Button { grid.select(pane) } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(index + 1)")
                        .font(.caption.weight(.bold))
                        .lineLimit(1)
                        .padding(.horizontal, 6)
                        .frame(minWidth: 24, minHeight: 24)
                        .background(isSelected ? Color.waffleTertiary : Color.secondary.opacity(0.3), in: Capsule())
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                    Text(tileTitle(pane))
                        .font(.subheadline.weight(.semibold))
                        // Narrow tiles at accessibility sizes truncate; they never hyphenate.
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 1 : 2)
                        .multilineTextAlignment(.leading)
                    // A page that never loaded has no title, so the host is already the title.
                    if !pane.address.isEmpty, URLDisplayFormatter.phoneDisplay(pane.address) != tileTitle(pane) {
                        Text(URLDisplayFormatter.phoneDisplay(pane.address))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Menu {
                AutoRefreshMenu(
                    selection: pane.refreshInterval,
                    onSelect: { grid.setRefreshInterval($0, for: pane) }
                )
                if grid.paneCount > 1 {
                    Button(role: .destructive) { session.removePane(pane) } label: {
                        Label("Close Pane", systemImage: "xmark.rectangle")
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: pane.refreshInterval == .off ? "timer" : "timer.circle.fill")
                    Text(pane.refreshInterval.title)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Auto-Refresh"))
        }
        // Unselected tiles get a faint fill under the glass: on a dark background glass alone
        // reads as a pale slab.
        .background(isSelected ? Color.clear : Color.primary.opacity(0.10), in: .rect(cornerRadius: 18))
        .glassEffect(isSelected ? .regular.tint(Color.accentColor.opacity(0.25)).interactive() : .regular.interactive(), in: .rect(cornerRadius: 18))
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func tileTitle(_ pane: WaffleCell) -> String {
        if !pane.page.title.isEmpty { return pane.page.title }
        if !pane.address.isEmpty { return URLDisplayFormatter.phoneDisplay(pane.address) }
        return String(localized: "Empty Pane")
    }
}
#endif
