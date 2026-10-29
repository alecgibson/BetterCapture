//
//  GIFExportBanner.swift
//  BetterCapture
//

import SwiftUI

/// A banner showing how far a finished recording has been converted into a GIF
struct GIFExportBanner: View {
    let progress: Double

    var body: some View {
        ProgressView(value: progress) {
            Text("Converting to GIF…")
                .font(.system(size: 13, weight: .semibold))
        } currentValueLabel: {
            Text(progress, format: .percent.precision(.fractionLength(0)))
                .font(.system(size: 11))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
