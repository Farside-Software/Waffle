//
//  WaffleMark.swift
//  WaffleDesignSystem
//
//  The app icon's artwork drawn in code at any size: a gold waffle with a 3x3 grid of cream
//  pockets and a pat of butter. Geometry is the icon's own (1024-point artboard, the gold
//  square is 600 across), so the mark matches the launch screen image exactly. Each part
//  takes a 0...1 progress so a splash can build the mark up: pockets row by row, butter last.
//

import SwiftUI

public struct WaffleMark: View {
    /// Entrance progress for the waffle body, the three pocket rows and the butter.
    private let bodyProgress: CGFloat
    private let rowProgress: [CGFloat]
    private let butterProgress: CGFloat

    public init(bodyProgress: CGFloat = 1, rowProgress: [CGFloat] = [1, 1, 1], butterProgress: CGFloat = 1) {
        self.bodyProgress = bodyProgress
        self.rowProgress = rowProgress
        self.butterProgress = butterProgress
    }

    public static let gold = Color(red: 0xDF / 255, green: 0xA6 / 255, blue: 0x56 / 255)
    public static let cream = Color(red: 0xF4 / 255, green: 0xE3 / 255, blue: 0xA0 / 255)
    public static let butter = Color(red: 0xF5 / 255, green: 0xC6 / 255, blue: 0x3C / 255)

    public var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let k = side / 600
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 110 * k, style: .continuous)
                    .fill(Self.gold)
                    .frame(width: side, height: side)
                    .scaleEffect(0.82 + 0.18 * bodyProgress)
                    .opacity(Double(bodyProgress))

                ForEach(0..<9, id: \.self) { index in
                    let row = index / 3
                    let column = index % 3
                    let progress = rowProgress.indices.contains(row) ? rowProgress[row] : 1
                    RoundedRectangle(cornerRadius: 30 * k, style: .continuous)
                        .fill(Self.cream)
                        .frame(width: 140 * k, height: 140 * k)
                        .scaleEffect(0.6 + 0.4 * progress)
                        .opacity(Double(progress))
                        .offset(x: (50 + CGFloat(column) * 180) * k, y: (50 + CGFloat(row) * 180) * k)
                }

                RoundedRectangle(cornerRadius: 40 * k, style: .continuous)
                    .fill(Self.butter)
                    .frame(width: 190 * k, height: 190 * k)
                    .shadow(color: .black.opacity(0.18 * Double(butterProgress)), radius: 8 * k, y: 6 * k)
                    // The butter drops in from above and settles.
                    .offset(x: 290 * k, y: (122 - 90 * (1 - butterProgress)) * k)
                    .opacity(Double(min(1, butterProgress * 2)))
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

#Preview {
    WaffleMark().frame(width: 200, height: 200).padding()
}
