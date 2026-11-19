//
//  SettingsPages.swift
//  WaffleFeatureSettings
//
//  The top-level list (grouped rows, each opening a page) and the pages themselves. The
//  same views serve the pushed layout (sheet) and the unfolded Duo's split (full page).
//

#if os(iOS)
import SwiftUI
import WaffleCore
import WaffleDesignSystem

extension SettingsView {

    // MARK: - Top-level list

    /// `selection` is set in the split layout, where rows select a page beside the list
    /// instead of pushing it.
    @ViewBuilder
    func rootList(selection: Binding<SettingsPage?>?) -> some View {
        Form {
            Section {
                syrupButton
                restoreRow
            }

            Section {
                pageRow(.search, "Search Engine", "magnifyingglass", .blue,
                        value: Text(verbatim: SearchProvider(rawValue: searchProviderRawValue)?.displayName ?? ""), selection: selection)
                pageRow(.contentBlocking, "Content Blocking", "shield.lefthalf.filled", .green,
                        value: Text(contentBlocking.isEnabled.wrappedValue ? "On" : "Off"), selection: selection)
                pageRow(.library, usesPaneWording ? "Layouts & Bookmarks" : "Presets & Bookmarks", "square.grid.2x2.fill", .orange,
                        value: nil, selection: selection)
            }

            Section {
                pageRow(.help, "Help & Feedback", "questionmark.circle.fill", .teal, value: nil, selection: selection)
                pageRow(.about, "About", "info.circle.fill", .gray, value: nil, selection: selection)
            }

            #if DEBUG
            Section {
                pageRow(.debug, "Debug", "ladybug.fill", .pink, value: nil, selection: selection)
            }
            #endif
        }
        .navigationTitle(Text("Settings"))
        .navigationBarTitleDisplayMode(.large)
    }

    @ViewBuilder
    private func pageRow(_ page: SettingsPage, _ title: LocalizedStringKey, _ icon: String, _ tint: Color,
                         value: Text?, selection: Binding<SettingsPage?>?) -> some View {
        let label = LabeledContent {
            if let value { value }
        } label: {
            SettingsIconLabel(title: title, systemImage: icon, tint: tint)
        }
        if let selection {
            let isSelected = selection.wrappedValue == page
            Button {
                selection.wrappedValue = page
            } label: {
                HStack {
                    label
                    SettingsChevron()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .listRowBackground(isSelected ? Color.accentColor.opacity(0.18) : nil)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        } else {
            NavigationLink(value: page) { label }
        }
    }

    // MARK: - Syrup

    private var syrupButton: some View {
        Button {
            if !isSyrupEnabled { requestSyrup() }
        } label: {
            // At accessibility text sizes the status drops under the name
            // instead of wrapping letter by letter.
            syrupRow(stacked: dynamicTypeSize.isAccessibilitySize)
        }
        .buttonStyle(.plain)
        .disabled(isSyrupEnabled)
        .accessibilityHint(isSyrupEnabled ? Text("") : Text("Opens the Syrup purchase sheet"))
    }

    @ViewBuilder
    private var restoreRow: some View {
        if let restorePurchases, !isSyrupEnabled {
            Button {
                Task {
                    isRestoring = true
                    let restored = await restorePurchases()
                    isRestoring = false
                    restoreMessage = restored ? "Syrup restored. Thank you!" : "No earlier purchase was found"
                }
            } label: {
                HStack {
                    SettingsIconLabel(title: "Restore Purchases", systemImage: "arrow.clockwise", tint: .gray)
                        .foregroundStyle(.primary)
                    if isRestoring {
                        Spacer()
                        ProgressView()
                    }
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isRestoring)
            if let restoreMessage {
                Text(restoreMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Pages

    @ViewBuilder
    func page(_ page: SettingsPage) -> some View {
        switch page {
        case .search: searchPage
        case .contentBlocking: contentBlockingPage
        case .library: libraryPage
        case .help: helpPage
        case .about: aboutPage
        #if DEBUG
        case .debug: debugPage
        #endif
        }
    }

    private var searchPage: some View {
        Form {
            Picker(String(localized: "Default Search Engine"), selection: $searchProviderRawValue) {
                ForEach(SearchProvider.allCases, id: \.self) { provider in
                    Text(provider.displayName).tag(provider.rawValue)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        }
        .navigationTitle(Text("Search Engine"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var contentBlockingPage: some View {
        Form {
            Section {
                Toggle(isOn: contentBlocking.isEnabled) {
                    Label(String(localized: "Block Ads, Trackers & Cookie Banners"), systemImage: "shield.lefthalf.filled")
                }
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    if usesPaneWording {
                        Text("Applies to every pane. To change it for one pane or site, open ••• then This Page then Content Blocking. Sites listed here are never blocked.")
                    } else {
                        Text("Applies to every cell. Override it for a single cell or site from the cell's context menu. Sites listed here are never blocked.")
                    }
                    if !contentBlocking.listTitles.isEmpty {
                        Text("Filter lists: \(listNames) (easylist.to), licensed CC BY-SA 3.0 and CC BY 3.0.")
                    }
                }
            }
            if !contentBlocking.exceptionHosts.isEmpty {
                Section {
                    ForEach(contentBlocking.exceptionHosts, id: \.self) { host in
                        Text(verbatim: host)
                    }
                    .onDelete { offsets in
                        for index in offsets { contentBlocking.removeException(contentBlocking.exceptionHosts[index]) }
                    }
                } header: {
                    Text("Never Blocked")
                }
            }
        }
        .navigationTitle(Text("Content Blocking"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var libraryPage: some View {
        Form {
            Section {
                Button(role: .destructive) {
                    showDeletePresetsConfirm = true
                } label: {
                    Text(LocalizedStringKey(usesPaneWording ? "Delete All Layouts" : "Delete All Presets"))
                }
                Button(role: .destructive) {
                    showDeleteBookmarksConfirm = true
                } label: {
                    Text("Delete All Bookmarks")
                }
            } header: {
                Text("Data")
            }
        }
        .navigationTitle(Text(LocalizedStringKey(usesPaneWording ? "Layouts & Bookmarks" : "Presets & Bookmarks")))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var helpPage: some View {
        Form {
            Section {
                linkRow("Support", "lifepreserver.fill", .teal, Company.support)
                Link(destination: SettingsLinks.writeReview) {
                    SettingsIconLabel(title: "Rate Waffle", systemImage: "star.fill", tint: .yellow)
                }
                .foregroundStyle(.primary)
                .accessibilityHint(Text("Opens the App Store to write a review."))
                ShareLink(
                    item: SettingsLinks.shareApp,
                    message: Text(LocalizedStringKey(usesPaneWording
                        ? "Browse pages side by side and save your layouts with Waffle."
                        : "Browse pages side by side and save your presets with Waffle."))
                ) {
                    SettingsIconLabel(title: "Share Waffle", systemImage: "square.and.arrow.up.fill", tint: .green)
                }
                .foregroundStyle(.primary)
            }
        }
        .navigationTitle(Text("Help & Feedback"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var aboutPage: some View {
        Form {
            Section {
                VStack(spacing: 4) {
                    Text("Waffle")
                        .font(.largeTitle.weight(.bold))
                        .accessibilityAddTraits(.isHeader)
                    Text(appVersionString)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .listRowBackground(Color.clear)
            }
            Section {
                linkRow("Website", "safari.fill", .blue, Company.website)
                linkRow("Privacy Policy", "hand.raised.fill", .gray, Company.privacy)
            }
            Section {
                Button {
                    openLink("https://www.linkedin.com/in/nicholas-molargik/")
                } label: {
                    LabeledContent("Developer") {
                        Text(verbatim: "Nicholas Molargik").foregroundStyle(.blue)
                    }
                }
                .buttonStyle(.plain)
                Button {
                    openLink(Company.website.absoluteString)
                } label: {
                    LabeledContent("Publisher") {
                        Text(verbatim: Company.name).foregroundStyle(.blue)
                    }
                }
                .buttonStyle(.plain)
            } header: {
                Text("Credits")
            }
        }
        .navigationTitle(Text("About"))
        .navigationBarTitleDisplayMode(.inline)
    }

    /// A link row that opens the page in the selected cell, like the About links always did.
    private func linkRow(_ title: LocalizedStringKey, _ icon: String, _ tint: Color, _ url: URL) -> some View {
        Button {
            openLink(url.absoluteString)
        } label: {
            HStack {
                SettingsIconLabel(title: title, systemImage: icon, tint: tint)
                Spacer(minLength: 0)
                SettingsChevron()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    #if DEBUG
    private var debugPage: some View {
        Form {
            Button {
                model.addExampleData()
            } label: {
                Label(String(localized: "Add Example Bookmarks & Presets"), systemImage: "plus.square.on.square")
            }
            .foregroundStyle(.primary)
        }
        .navigationTitle(Text("Debug"))
        .navigationBarTitleDisplayMode(.inline)
    }
    #endif
}
#endif
