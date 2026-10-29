//
//  GIFRecording.swift
//  BetterCapture
//

import Foundation

/// A recording made to an intermediate video, which is converted into a GIF once recording stops.
@MainActor
@Observable
final class GIFRecording {

    let gifURL: URL
    let framesPerSecond: Int
    let videoURL = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).mp4")
    let partialGIFURL = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).gif")

    /// How much of the GIF `finish()` has written, from 0 to 1
    private(set) var exportProgress = 0.0

    /// Creates the GIF's folder and checks it can be written to, so an unusable destination fails
    /// before anything is recorded.
    init(gifURL: URL, framesPerSecond: Int) throws {
        try FileManager.default.createDirectory(at: gifURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Self.checkWritable(gifURL)
        self.gifURL = gifURL
        self.framesPerSecond = framesPerSecond
    }

    /// Converts the video into the GIF and deletes it. The GIF is written to the temporary directory and
    /// moved into place once complete. If the export fails, the video is kept as an MP4 beside where
    /// the GIF would have gone, or left where it is if it can't be moved there.
    /// - Returns: The URL of the file to hand to the user, and the export error if it fell back to video
    @concurrent
    nonisolated func finish() async -> (url: URL, exportError: Error?) {
        do {
            try await GIFExporter.export(videoAt: videoURL, to: partialGIFURL, framesPerSecond: framesPerSecond) {
                self.exportProgress = $0
            }
            try FileManager.default.moveItem(at: partialGIFURL, to: gifURL)
        } catch {
            try? FileManager.default.removeItem(at: partialGIFURL)
            return (keepVideo(), error)
        }

        try? FileManager.default.removeItem(at: videoURL)
        return (gifURL, nil)
    }

    private static func checkWritable(_ url: URL) throws {
        try Data().write(to: url)
        try FileManager.default.removeItem(at: url)
    }

    nonisolated private func keepVideo() -> URL {
        let keptURL = gifURL.deletingPathExtension().appendingPathExtension("mp4")
        do {
            try FileManager.default.moveItem(at: videoURL, to: keptURL)
            return keptURL
        } catch {
            return videoURL
        }
    }
}
