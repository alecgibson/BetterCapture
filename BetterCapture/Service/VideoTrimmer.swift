//
//  VideoTrimmer.swift
//  BetterCapture
//

import AVFoundation
import UniformTypeIdentifiers

/// Cuts a recording down to a time range without re-encoding it.
nonisolated enum VideoTrimmer {

    /// Replaces the video at `url` with the part of it inside `timeRange`.
    ///
    /// The trimmed copy is written beside the original so the swap stays on one volume. If anything
    /// fails, the original is left untouched.
    @concurrent
    static func trim(videoAt url: URL, to timeRange: CMTimeRange) async throws {
        guard let session = AVAssetExportSession(asset: AVURLAsset(url: url), presetName: AVAssetExportPresetPassthrough),
              let contentType = UTType(filenameExtension: url.pathExtension) else {
            throw VideoTrimmerError.failedToCreateExport
        }
        session.timeRange = timeRange

        let trimmedURL = url.deletingLastPathComponent().appending(path: "\(UUID().uuidString).\(url.pathExtension)")
        do {
            try await session.export(to: trimmedURL, as: AVFileType(rawValue: contentType.identifier))
            _ = try FileManager.default.replaceItemAt(url, withItemAt: trimmedURL)
        } catch {
            try? FileManager.default.removeItem(at: trimmedURL)
            throw error
        }
    }
}
