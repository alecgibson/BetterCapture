//
//  GIFExporter.swift
//  BetterCapture
//

import AVFoundation
import VideoToolbox

/// Converts a finished recording into a looping animated GIF.
nonisolated enum GIFExporter {

    /// Samples the video at `framesPerSecond` and writes the frames to `destinationURL` as a GIF.
    ///
    /// Frames are decoded and written one at a time, so memory use doesn't grow with the length of the recording.
    /// After each frame, `progress` is told how much of the GIF has been written, from 0 to 1.
    @concurrent
    static func export(
        videoAt sourceURL: URL,
        to destinationURL: URL,
        framesPerSecond: Int,
        progress: @MainActor (Double) -> Void
    ) async throws {
        try await withTaskExecutorPreference(BlockingIOExecutor()) {
            try await writeGIF(videoAt: sourceURL, to: destinationURL, framesPerSecond: framesPerSecond, progress: progress)
        }
    }

    /// Does the work of `export`, reading frames with calls that block.
    @concurrent
    private static func writeGIF(
        videoAt sourceURL: URL,
        to destinationURL: URL,
        framesPerSecond: Int,
        progress: @MainActor (Double) -> Void
    ) async throws {
        let asset = AVURLAsset(url: sourceURL)
        let duration = try await asset.load(.duration)
        let durationInFrames = duration.convertScale(CMTimeScale(framesPerSecond), method: .roundTowardPositiveInfinity)
        let frameCount = max(1, Int(durationInFrames.value))
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw GIFExporterError.failedToReadVideo
        }

        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ])
        reader.add(output)
        guard reader.startReading() else {
            throw reader.error ?? GIFExporterError.failedToReadVideo
        }
        guard var currentFrame = try nextSample(from: output, of: reader)?.imageBuffer else {
            throw GIFExporterError.failedToReadVideo
        }

        let gif = try GIFFileWriter(
            url: destinationURL,
            width: CVPixelBufferGetWidth(currentFrame),
            height: CVPixelBufferGetHeight(currentFrame),
            centisecondsPerFrame: 100 / framesPerSecond
        )

        var upcomingSample = try nextSample(from: output, of: reader)
        for index in 0..<frameCount {
            let time = CMTime(value: CMTimeValue(index), timescale: CMTimeScale(framesPerSecond))
            try autoreleasepool {
                while let sample = upcomingSample, sample.presentationTimeStamp <= time {
                    guard let imageBuffer = sample.imageBuffer else {
                        throw GIFExporterError.failedToReadVideo
                    }
                    currentFrame = imageBuffer
                    upcomingSample = try nextSample(from: output, of: reader)
                }
                try gif.append(makeImage(from: currentFrame))
            }
            await progress(Double(index + 1) / Double(frameCount))
        }
        try gif.finish()
    }

    /// The next sample that holds a frame, skipping marker buffers.
    /// - Returns: `nil` once the whole video has been read
    private static func nextSample(from output: AVAssetReaderTrackOutput, of reader: AVAssetReader) throws -> CMSampleBuffer? {
        while let sample = output.copyNextSampleBuffer() {
            if sample.numSamples > 0 {
                return sample
            }
        }
        if reader.status == .failed {
            throw reader.error ?? GIFExporterError.failedToReadVideo
        }
        return nil
    }

    private static func makeImage(from pixelBuffer: CVPixelBuffer) throws -> CGImage {
        var image: CGImage?
        VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &image)
        guard let image else {
            throw GIFExporterError.failedToReadVideo
        }
        return image
    }
}
