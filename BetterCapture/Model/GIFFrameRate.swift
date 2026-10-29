//
//  GIFFrameRate.swift
//  BetterCapture
//

import Foundation

/// Frame rate options for GIF recordings
///
/// GIF frame delays are stored in whole centiseconds, so only rates that divide 100
/// play back at true speed.
enum GIFFrameRate: Int, CaseIterable, Identifiable {
    case fps10 = 10
    case fps20 = 20
    case fps25 = 25
    case fps50 = 50

    var id: Int { rawValue }

    var displayName: String {
        "\(rawValue) fps"
    }
}
