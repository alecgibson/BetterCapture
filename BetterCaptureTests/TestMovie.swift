//
//  TestMovie.swift
//  BetterCaptureTests
//

import AVFoundation
import Testing
import UniformTypeIdentifiers

/// Writes H.264 movies for tests to read back.
@MainActor
enum TestMovie {

    static let framesPerSecond: Int32 = 30
    static let size = CGSize(width: 640, height: 480)
    static let blackPixel: [UInt8] = [0, 0, 0, 255]

    /// Writes a movie at `framesPerSecond`, each frame filled with one BGRA pixel.
    static func make(
        frameCount: Int,
        fileType: AVFileType = .mp4,
        pixelOfFrame: (Int) -> [UInt8] = { _ in TestMovie.blackPixel }
    ) async throws -> URL {
        let fileExtension = try #require(UTType(fileType.rawValue)?.preferredFilenameExtension)
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).\(fileExtension)")
        let writer = try AVAssetWriter(outputURL: url, fileType: fileType)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
            AVVideoCompressionPropertiesKey: [AVVideoMaxKeyFrameIntervalKey: Int(framesPerSecond) * 2]
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)
        writer.add(input)

        #expect(writer.startWriting())
        writer.startSession(atSourceTime: .zero)

        for frame in 0..<frameCount {
            let pixelBuffer = try makePixelBuffer(filledWith: pixelOfFrame(frame))
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(for: .milliseconds(10))
            }
            let presentationTime = CMTime(value: CMTimeValue(frame), timescale: framesPerSecond)
            #expect(adaptor.append(pixelBuffer, withPresentationTime: presentationTime))
        }

        input.markAsFinished()
        writer.endSession(atSourceTime: CMTime(value: CMTimeValue(frameCount), timescale: framesPerSecond))
        await writer.finishWriting()
        #expect(writer.status == .completed)

        return url
    }

    private static func makePixelBuffer(filledWith pixel: [UInt8]) throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32BGRA,
            [kCVPixelBufferIOSurfacePropertiesKey as String: [:] as CFDictionary] as CFDictionary,
            &pixelBuffer
        )
        #expect(status == kCVReturnSuccess)
        let buffer = try #require(pixelBuffer)

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        let baseAddress = try #require(CVPixelBufferGetBaseAddress(buffer))
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let row = Array([[UInt8]](repeating: pixel, count: Int(size.width)).joined())
        for rowIndex in 0..<Int(size.height) {
            (baseAddress + rowIndex * bytesPerRow).copyMemory(from: row, byteCount: row.count)
        }
        return buffer
    }
}
