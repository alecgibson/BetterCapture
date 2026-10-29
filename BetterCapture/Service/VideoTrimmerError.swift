//
//  VideoTrimmerError.swift
//  BetterCapture
//

import Foundation

enum VideoTrimmerError: LocalizedError {
    case failedToCreateExport

    var errorDescription: String? {
        "Failed to prepare the recording for trimming."
    }
}
