//
//  GIFExporterError.swift
//  BetterCapture
//

import Foundation

enum GIFExporterError: LocalizedError {
    case failedToReadVideo
    case failedToEncodeFrame

    var errorDescription: String? {
        switch self {
        case .failedToReadVideo:
            return "Failed to read the recorded video."
        case .failedToEncodeFrame:
            return "Failed to encode a GIF frame."
        }
    }
}
