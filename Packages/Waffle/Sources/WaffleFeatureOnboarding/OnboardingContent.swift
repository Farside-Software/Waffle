//
//  OnboardingContent.swift
//  WaffleFeatureOnboarding
//
//  What each tour page says, per device. Pure data: a symbol, a title, one line, a few rows.
//  The interactive part of each page (the mock grid, the panes, the fold) is chosen by `kind`.
//

#if os(iOS)
import SwiftUI
import WaffleCore

/// Which device the tour is written for. The iPad tour describes the grid, toolbar and
/// sidebar; the phone tours describe stacked panes and the bottom bar.
public enum OnboardingVariant: Sendable, Equatable {
    case iPad
    case iPhone
    /// iPhone Duo: the iPhone tour plus a page on the inner display and Desk Mode.
    case iPhoneDuo

    var isPhone: Bool { self != .iPad }
}

struct OnboardingFeature: Identifiable {
    let systemImage: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    var requiresSyrup = false

    var id: String { systemImage }
}

struct OnboardingPage: Identifiable {
    enum Kind {
        // iPad
        case grid, shape, library
        // iPhone and iPhone Duo
        case panes, size, layouts, unfold
        // Everywhere
        case syrup
    }

    let kind: Kind
    let systemImage: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    var features: [OnboardingFeature] = []
    var footnote: LocalizedStringKey?

    var id: Int { Self.order(kind) }
    private static func order(_ kind: Kind) -> Int {
        switch kind {
        case .grid: 0
        case .shape: 1
        case .library: 2
        case .panes: 3
        case .size: 4
        case .layouts: 5
        case .unfold: 6
        case .syrup: 7
        }
    }

    static func pages(for variant: OnboardingVariant) -> [OnboardingPage] {
        switch variant {
        case .iPad: [grid, shape, library, ipadSyrup]
        case .iPhone: [panes, size, layouts, phoneSyrup(isDuo: false)]
        case .iPhoneDuo: [panesDuo, size, layouts, unfold, phoneSyrup(isDuo: true)]
        }
    }

    // MARK: iPad

    static let grid = OnboardingPage(
        kind: .grid,
        systemImage: "square.grid.2x2",
        title: "Your pages, side by side",
        subtitle: "Waffle shows several webpages at once in a grid. Tap a cell to make it yours.",
        features: [
            .init(systemImage: "hand.tap", title: "Tap a cell", detail: "The selected cell takes the address bar, back and reload."),
            .init(systemImage: "magnifyingglass", title: "Search or type an address", detail: "Anything that is not a web address becomes a search."),
            .init(systemImage: "keyboard", title: "Keyboard shortcuts", detail: "Command-L jumps to the address bar."),
        ]
    )

    static let shape = OnboardingPage(
        kind: .shape,
        systemImage: "rectangle.split.3x3",
        title: "Shape your grid",
        subtitle: "Add a row or a column and every page makes room. Try it below.",
        features: [
            .init(systemImage: "plus.rectangle.on.rectangle", title: "Rows and columns", detail: "Use the grid menu in the toolbar to add or remove them."),
            .init(systemImage: "square.grid.2x2", title: "Free up to \(AppConfiguration.maxFreeRows)×\(AppConfiguration.maxFreeCols)", detail: "Larger grids come with Syrup."),
        ]
    )

    static let library = OnboardingPage(
        kind: .library,
        systemImage: "sidebar.left",
        title: "Your library",
        subtitle: "Bookmarks and presets live in the sidebar and sync through iCloud.",
        features: [
            .init(systemImage: "bookmark", title: "Bookmarks", detail: "Tap one to open it in the selected cell."),
            .init(systemImage: "square.grid.3x3", title: "Presets", detail: "A preset is a whole grid of pages you can bring back in one tap.", requiresSyrup: true),
            .init(systemImage: "magnifyingglass", title: "Search the library", detail: "The field at the top of the sidebar finds any bookmark or preset."),
        ]
    )

    static let ipadSyrup = OnboardingPage(
        kind: .syrup,
        systemImage: "drop.fill",
        title: "Pour on the Syrup",
        subtitle: "Waffle is free in a \(AppConfiguration.maxFreeRows)×\(AppConfiguration.maxFreeCols) grid. A one-time Syrup purchase adds the rest.",
        features: [
            .init(systemImage: "rectangle.split.3x3", title: "Larger grids", detail: "Grow your waffle up to \(AppConfiguration.maxPremiumRows)×\(AppConfiguration.maxPremiumCols) cells.", requiresSyrup: true),
            .init(systemImage: "arrow.left.arrow.right.square", title: "Rearrange", detail: "Drag cells into a new order.", requiresSyrup: true),
            .init(systemImage: "rectangle.on.rectangle", title: "Pop out and fullscreen", detail: "Give a cell its own window, or the whole screen.", requiresSyrup: true),
            .init(systemImage: "square.grid.3x3", title: "Presets", detail: "Save grid layouts and restore them anytime.", requiresSyrup: true),
        ],
        footnote: "You will see Syrup after this tour, and anytime later in Settings."
    )

    // MARK: iPhone and iPhone Duo

    static let panes = OnboardingPage(
        kind: .panes,
        systemImage: "rectangle.split.1x2",
        title: "Two pages, one screen",
        subtitle: "Waffle stacks live pages in panes. Tap a pane, then use the bar below it.",
        features: [
            .init(systemImage: "hand.tap", title: "Tap a pane", detail: "The bar at the bottom controls the selected pane."),
            .init(systemImage: "keyboard", title: "Type an address or a search", detail: "Anything that is not a web address becomes a search."),
            .init(systemImage: "ellipsis", title: "The ••• menu", detail: "It adds panes, opens layouts and bookmarks, and Settings."),
        ]
    )

    /// iPhone Duo: the controls are a toolbar along the display's edge, not a bar below the panes.
    static let panesDuo = OnboardingPage(
        kind: .panes,
        systemImage: "rectangle.split.1x2",
        title: "Two pages, one screen",
        subtitle: "Waffle stacks live pages in panes. Tap a pane, then use the toolbar along the edge.",
        features: [
            .init(systemImage: "hand.tap", title: "Tap a pane", detail: "The toolbar controls the selected pane."),
            .init(systemImage: "keyboard", title: "Type an address or a search", detail: "Tap the address, type, and anything that is not a web address becomes a search."),
            .init(systemImage: "ellipsis", title: "The ••• menu", detail: "It adds panes, opens layouts and bookmarks, and Settings."),
        ]
    )

    static let size = OnboardingPage(
        kind: .size,
        systemImage: "arrow.up.and.down",
        title: "Size your panes",
        subtitle: "Drag the divider to give one page more room. Try it below.",
        features: [
            .init(systemImage: "arrow.up.left.and.arrow.down.right", title: "Maximize a pane", detail: "Focus on one page, then come back to both."),
            .init(systemImage: "arrow.clockwise", title: "Reload on a timer", detail: "Touch and hold Reload to refresh a pane automatically."),
        ]
    )

    static let layouts = OnboardingPage(
        kind: .layouts,
        systemImage: "square.stack",
        title: "Save your layouts",
        subtitle: "Keep the pages you open together and bring them back in one tap.",
        features: [
            .init(systemImage: "square.and.arrow.down", title: "Save a layout", detail: "From the ••• menu, in Layouts & Bookmarks."),
            .init(systemImage: "bookmark", title: "Bookmarks", detail: "Open any bookmark in the selected pane."),
        ]
    )

    static let unfold = OnboardingPage(
        kind: .unfold,
        systemImage: "rectangle.portrait.on.rectangle.portrait",
        title: "Unfold for more",
        subtitle: "On iPhone Duo the inner display opens up to four panes around the fold.",
        features: [
            .init(systemImage: "rectangle.split.2x2", title: "Up to four panes", detail: "Two on each side of the fold.", requiresSyrup: true),
            .init(systemImage: "laptopcomputer", title: "Desk Mode", detail: "Half-fold it: pages on top, controls below.", requiresSyrup: true),
            .init(systemImage: "arrow.left.arrow.right", title: "Fold it shut", detail: "Back to two panes; the rest wait for you."),
        ]
    )

    static func phoneSyrup(isDuo: Bool) -> OnboardingPage {
        var features: [OnboardingFeature] = [
            .init(systemImage: "rectangle.stack", title: "Unlimited layouts", detail: "One saved layout is free; Syrup keeps as many as you like.", requiresSyrup: true),
        ]
        if isDuo {
            features += [
                .init(systemImage: "rectangle.split.2x2", title: "Third and fourth panes", detail: "On the unfolded inner display.", requiresSyrup: true),
                .init(systemImage: "laptopcomputer", title: "Desk Mode", detail: "Pages on top, controls below.", requiresSyrup: true),
            ]
        }
        return OnboardingPage(
            kind: .syrup,
            systemImage: "drop.fill",
            title: "Pour on the Syrup",
            subtitle: "Free: two panes, one saved layout, auto-refresh and content blocking. A one-time Syrup purchase adds the rest.",
            features: features,
            footnote: isDuo
                ? "You never have to buy it. Syrup also works on iPad. Find it anytime in Settings."
                : "You never have to buy it. Syrup also unlocks more on iPad and iPhone Duo. Find it anytime in Settings."
        )
    }
}
#endif
