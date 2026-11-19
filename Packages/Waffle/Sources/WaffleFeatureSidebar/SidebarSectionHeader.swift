//
//  SidebarSectionHeader.swift
//  WaffleFeatureSidebar
//
//  A reusable header component for sidebar sections (Bookmarks, Presets, etc.)
//

#if os(iOS)
import SwiftUI
import WaffleDesignSystem

struct SidebarSectionHeader: View {
    let title: LocalizedStringKey
    let icon: String
    let primaryAction: (label: LocalizedStringKey, icon: String, action: () -> Void)
    let secondaryAction: (label: LocalizedStringKey, icon: String, action: () -> Void)

    var body: some View {
        HStack {
            Group {
                WaffleSymbolTile(systemImage: icon, side: 40)
                Text(title)
            }
            .font(.system(.title2, design: .rounded, weight: .bold))

            Spacer()

            Menu {
                Button(primaryAction.label, systemImage: primaryAction.icon) { primaryAction.action() }
                Button(secondaryAction.label, systemImage: secondaryAction.icon) { secondaryAction.action() }
            } label: {
                Label("New", systemImage: "plus")
            }
            .menuStyle(.button)
            .buttonStyle(.waffleSecondary)
        }
        .padding(10)
        .padding(.horizontal, 10)
    }
}

struct BookmarksHeaderView: View {
    var onQuickSaveCurrent: () -> Void
    var onSaveAs: () -> Void

    var body: some View {
        SidebarSectionHeader(
            title: "Bookmarks",
            icon: "bookmark.fill",
            primaryAction: (label: "Save As…", icon: "square.and.pencil", action: onSaveAs),
            secondaryAction: (label: "Quick Save", icon: "square.and.arrow.down.fill", action: onQuickSaveCurrent)
        )
    }
}

struct PresetsHeaderView: View {
    var onQuickSave: () -> Void
    var onSaveAs: () -> Void

    var body: some View {
        SidebarSectionHeader(
            title: "Presets",
            icon: "square.grid.3x3.fill",
            primaryAction: (label: "Quick Save", icon: "square.and.arrow.down.fill", action: onQuickSave),
            secondaryAction: (label: "Save As…", icon: "square.and.pencil", action: onSaveAs)
        )
    }
}
#endif
