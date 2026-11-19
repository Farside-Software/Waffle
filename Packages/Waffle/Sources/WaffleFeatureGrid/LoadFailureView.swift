//
//  LoadFailureView.swift
//  WaffleFeatureGrid
//
//  Shown over a cell or pane whose page could not be loaded (offline, unknown host, refused
//  connection), in the same calm style as the start page, with one Try Again button. Falls back
//  to the title alone as the cell shrinks.
//

#if os(iOS)
import SwiftUI
import WaffleDesignSystem

struct LoadFailureView: View {
    let retry: () -> Void

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)

            ViewThatFits(in: .vertical) {
                VStack(spacing: 12) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Text("Can't Open This Page")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                    Text("Check your connection and the address, then try again.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button(action: retry) {
                        Label("Try Again", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.wafflePrimary)
                    .padding(.top, 4)
                }
                .padding(32)

                VStack(spacing: 8) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Text("Can't Open This Page")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                }
                .padding(16)

                Text("Can't Open This Page")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(8)
            }
        }
    }
}
#endif
