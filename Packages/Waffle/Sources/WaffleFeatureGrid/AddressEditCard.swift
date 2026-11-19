//
//  AddressEditCard.swift
//  WaffleFeatureGrid
//
//  The iPhone Duo's address editor: with the controls in the trailing toolbar there is no bar
//  to type into, so tapping the address button opens this small card. The field takes focus
//  at once with the whole address selected; Return or Go loads it (the same search/URL
//  normalisation as the bar, done by the caller), Cancel closes it.
//

#if os(iOS)
import SwiftUI
import WaffleCore
import WaffleDesignSystem

public struct AddressEditCard: View {
    @Binding var text: String
    var onSubmit: () -> Void
    var onCancel: () -> Void

    @State private var isEditing = false

    public init(text: Binding<String>, onSubmit: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self._text = text
        self.onSubmit = onSubmit
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Address", systemImage: "globe")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .labelStyle(.titleAndIcon)

            AddressTextField(
                text: $text,
                placeholder: String(localized: "Search or enter a URL"),
                isEditing: $isEditing,
                onSubmit: onSubmit,
                focusOnAppear: true
            )
            .padding(.horizontal, 14)
            .frame(height: AppConfiguration.barControlHeight)
            .background(.fill.tertiary, in: .capsule)
            .accessibilityLabel(Text("Address bar"))

            HStack(spacing: 10) {
                Spacer(minLength: 0)
                Button(action: onCancel) {
                    Text("Cancel")
                        .padding(.horizontal, 16)
                        .frame(minWidth: 44, minHeight: AppConfiguration.barControlHeight)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .capsule)

                Button(action: onSubmit) {
                    Label("Go", systemImage: "arrow.right")
                        .labelStyle(.titleAndIcon)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.waffleTertiary)
                        .padding(.horizontal, 18)
                        .frame(minWidth: 44, minHeight: AppConfiguration.barControlHeight)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.tint(Color.wafflePrimary).interactive(), in: .capsule)
            }
        }
        .padding(16)
        .background(.regularMaterial, in: .rect(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 16, y: 6)
    }
}
#endif
