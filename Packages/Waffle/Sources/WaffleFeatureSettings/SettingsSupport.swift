//
//  SettingsSupport.swift
//  WaffleFeatureSettings
//
//  The pages of Settings, how the unfolded iPhone Duo decides on its full-page split, the
//  DEBUG launch arguments that open a page directly, and the presentation switch the
//  phone and iPad hosts use.
//

#if os(iOS)
import SwiftUI
import WaffleCore
import WaffleDesignSystem

/// One page of Settings. Rows in the top-level list open these.
enum SettingsPage: String, Hashable, CaseIterable, Identifiable {
    case search, contentBlocking, library, help, about
    #if DEBUG
    case debug
    #endif

    var id: String { rawValue }
}

/// Where Settings shows as a full page (split around the hinge) instead of a sheet.
public enum SettingsLayout {
    /// The unfolded iPhone Duo: the Duo, on its regular-width inner display.
    public static func usesSplit(horizontalSizeClass: UserInterfaceSizeClass?) -> Bool {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "WaffleDebugSettingsSplit") { return true }
        #endif
        return PhoneDuo.isDuo && horizontalSizeClass == .regular
    }

    #if DEBUG
    /// `-WaffleDebugSettingsPage search|contentBlocking|library|help|about|debug`
    static var debugPage: SettingsPage? {
        UserDefaults.standard.string(forKey: "WaffleDebugSettingsPage").flatMap(SettingsPage.init(rawValue:))
    }
    #endif
}

public extension View {
    /// Presents Settings as a sheet, or as a full page when `fullPage` (the unfolded Duo).
    func settingsPresentation<Content: View>(
        isPresented: Binding<Bool>,
        fullPage: Bool,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        modifier(SettingsPresentation(isPresented: isPresented, fullPage: fullPage, sheetContent: content))
    }
}

private struct SettingsPresentation<SheetContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let fullPage: Bool
    let sheetContent: () -> SheetContent

    // Both presentations hang off the same content. Branching on `fullPage` (if/else around
    // `content`) gave the content two identities, so folding or unfolding a Duo rebuilt the
    // whole workspace and created a second WebView for every open page, which traps inside
    // WebKit's SwiftUI layer.
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: presented(asFullPage: false), content: sheetContent)
            .fullScreenCover(isPresented: presented(asFullPage: true), content: sheetContent)
    }

    private func presented(asFullPage: Bool) -> Binding<Bool> {
        Binding(
            get: { isPresented && fullPage == asFullPage },
            set: { if !$0, fullPage == asFullPage { isPresented = false } }
        )
    }
}

/// The small coloured icon tile iPhone Settings puts before a row.
struct SettingsIconLabel: View {
    let title: LocalizedStringKey
    let systemImage: String
    var tint: Color = .gray

    var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: systemImage)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(tint, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
    }
}

struct SettingsChevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.tertiary)
            .accessibilityHidden(true)
    }
}

/// Splits the unfolded Duo's full page around the hinge: the list in the leading pane, the
/// chosen page to the right of the fold. Without a fold it falls back to a fixed leading width.
struct SettingsSplitLayout<List: View, Detail: View>: View {
    let list: List
    let detail: Detail

    init(@ViewBuilder list: () -> List, @ViewBuilder detail: () -> Detail) {
        self.list = list()
        self.detail = detail()
    }

    /// Clear space kept either side of the fold's centre line.
    private let foldClearance: CGFloat = 28

    var body: some View {
        GeometryReader { proxy in
            let fold = proxy.foldCenterXIfAvailable
            let leadingWidth = fold.map { max(280, $0 - foldClearance) } ?? 340
            let detailStart = fold.map { max(leadingWidth, $0 + foldClearance) } ?? leadingWidth + 1
            HStack(spacing: 0) {
                list.frame(width: leadingWidth)
                Rectangle()
                    .fill(fold == nil ? AnyShapeStyle(.separator) : AnyShapeStyle(.clear))
                    .frame(width: detailStart - leadingWidth)
                    .accessibilityHidden(true)
                detail.frame(maxWidth: .infinity)
            }
        }
    }
}
#endif
