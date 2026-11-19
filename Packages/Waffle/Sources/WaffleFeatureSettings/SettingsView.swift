//
//  SettingsView.swift
//  WaffleFeatureSettings
//
//  Search engine, Syrup status, destructive data actions, and about links. Data actions
//  go through `SettingsModel`; Syrup gating and in-app link opening are injected.
//

#if os(iOS)
import SwiftUI
import WaffleCore
import WaffleDesignSystem

public struct SettingsView: View {
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.dismiss) var dismiss

    let model: SettingsModel
    let isSyrupEnabled: Bool
    let requestSyrup: () -> Void
    /// Loads a URL into the selected grid cell (the app browses its own links).
    let openInApp: (String) -> Void
    let contentBlocking: ContentBlockingSettingsBinding
    /// iPhone and iPhone Duo: panes and layouts instead of cells and presets, "Done" to close,
    /// and a Restore Purchases row. The iPad keeps its wording.
    let usesPaneWording: Bool
    /// Phone only: restores purchases, returning whether Syrup is now owned.
    let restorePurchases: (() async -> Bool)?

    @AppStorage("searchProvider") var searchProviderRawValue: String = SearchProvider.google.rawValue
    @State var showDeleteBookmarksConfirm = false
    @State var showDeletePresetsConfirm = false
    @State var restoreMessage: LocalizedStringKey?
    @State var isRestoring = false
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @State var path: [SettingsPage]
    /// The page shown beside the list on the unfolded Duo.
    @State var splitSelection: SettingsPage?

    public init(
        model: SettingsModel,
        isSyrupEnabled: Bool,
        requestSyrup: @escaping () -> Void,
        openInApp: @escaping (String) -> Void,
        usesPaneWording: Bool = false,
        restorePurchases: (() async -> Bool)? = nil,
        contentBlocking: ContentBlockingSettingsBinding
    ) {
        var initialPage: SettingsPage?
        #if DEBUG
        initialPage = SettingsLayout.debugPage
        #endif
        _path = State(initialValue: initialPage.map { [$0] } ?? [])
        _splitSelection = State(initialValue: initialPage ?? .search)
        self.usesPaneWording = usesPaneWording
        self.restorePurchases = restorePurchases
        self.contentBlocking = contentBlocking
        self.model = model
        self.isSyrupEnabled = isSyrupEnabled
        self.requestSyrup = requestSyrup
        self.openInApp = openInApp
    }

    var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return String(localized: "Version \(version) (\(build))")
    }

    func syrupRow(stacked: Bool) -> some View {
        let name = SettingsIconLabel(title: "Syrup", systemImage: "drop.fill", tint: .waffleTertiary)
            .foregroundStyle(.primary)
        let status = HStack(spacing: 6) {
            if isSyrupEnabled {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                Text("Purchased. Thank you!")
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
            } else {
                Image(systemName: "cart")
                    .foregroundStyle(.waffleTertiary)
                Text("Not Purchased")
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
            }
        }
        return Group {
            if stacked {
                VStack(alignment: .leading, spacing: 6) {
                    name
                    HStack {
                        status
                        Spacer(minLength: 0)
                        if !isSyrupEnabled {
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            } else {
                HStack {
                    name
                    Spacer()
                    status
                    if !isSyrupEnabled {
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    // MARK: - Body

    public var body: some View {
        Group {
            if SettingsLayout.usesSplit(horizontalSizeClass: horizontalSizeClass) {
                SettingsSplitLayout {
                    NavigationStack { rootList(selection: $splitSelection) }
                } detail: {
                    NavigationStack {
                        page(splitSelection ?? .search)
                            .id(splitSelection)
                            .toolbar { doneButton }
                    }
                }
            } else {
                NavigationStack(path: $path) {
                    rootList(selection: nil)
                        .toolbar { doneButton }
                        .navigationDestination(for: SettingsPage.self) { page($0) }
                }
            }
        }
        .alert(Text("Delete All Bookmarks?"), isPresented: $showDeleteBookmarksConfirm) {
            Button(String(localized: "Cancel"), role: .cancel) { }
            Button(String(localized: "Delete"), role: .destructive) {
                model.deleteAllBookmarks()
            }
        } message: {
            Text("This action will permanently remove all bookmarks.")
        }
        .alert(Text(LocalizedStringKey(usesPaneWording ? "Delete All Layouts?" : "Delete All Presets?")), isPresented: $showDeletePresetsConfirm) {
            Button(String(localized: "Cancel"), role: .cancel) { }
            Button(String(localized: "Delete"), role: .destructive) {
                model.deleteAllPresets()
            }
        } message: {
            Text(LocalizedStringKey(usesPaneWording ? "This action will permanently remove all layouts." : "This action will permanently remove all presets."))
        }
    }

    private var doneButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                dismiss()
            } label: {
                Label(usesPaneWording ? String(localized: "Done") : String(localized: "Close"),
                      systemImage: "checkmark")
                    .labelStyle(.titleAndIcon)
            }
        }
    }

    var listNames: String {
        contentBlocking.listTitles.formatted(.list(type: .and))
    }

    func openLink(_ urlString: String) {
        openInApp(urlString)
        dismiss()
    }
}

/// Outbound links for rating and sharing Waffle; `ct` attributes installs to the source.
enum SettingsLinks {
    /// Opens the App Store's write-a-review page directly.
    static let writeReview = URL(string: "https://apps.apple.com/app/id6751783473?action=write-review")!
    /// What "Share Waffle" hands to the share sheet.
    static let shareApp = Company.page("/go/waffle?ct=share_app")
}
#endif
