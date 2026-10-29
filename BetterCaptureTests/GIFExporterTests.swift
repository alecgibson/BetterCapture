//
//  GIFExporterTests.swift
//  BetterCaptureTests
//

import AVFoundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import BetterCapture

@MainActor
struct GIFExporterTests {

    private static let redPixel: [UInt8] = [0, 0, 255, 255]
    private static let bluePixel: [UInt8] = [255, 0, 0, 255]

    // MARK: - Tests

    @Test(arguments: GIFFrameRate.allCases)
    func exportsLoopingGIFAtTheGIFFrameRate(rate: GIFFrameRate) async throws {
        let oneSecondOfFrames = Int(TestMovie.framesPerSecond)
        let movieURL = try await TestMovie.make(frameCount: oneSecondOfFrames)
        defer { try? FileManager.default.removeItem(at: movieURL) }
        let gifURL = makeGIFURL()
        defer { try? FileManager.default.removeItem(at: gifURL) }

        try await GIFExporter.export(videoAt: movieURL, to: gifURL, framesPerSecond: rate.rawValue) { _ in }

        let source = try #require(CGImageSourceCreateWithURL(gifURL as CFURL, nil))
        #expect(CGImageSourceGetType(source) as String? == UTType.gif.identifier)
        #expect(CGImageSourceGetCount(source) == rate.rawValue)

        let fileProperties = try #require(CGImageSourceCopyProperties(source, nil) as? [CFString: Any])
        let fileGIFProperties = try #require(fileProperties[kCGImagePropertyGIFDictionary] as? [CFString: Any])
        #expect(fileGIFProperties[kCGImagePropertyGIFLoopCount] as? Int == 0)

        let frameProperties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        #expect(frameProperties[kCGImagePropertyPixelWidth] as? Int == Int(TestMovie.size.width))
        #expect(frameProperties[kCGImagePropertyPixelHeight] as? Int == Int(TestMovie.size.height))

        let frameGIFProperties = try #require(frameProperties[kCGImagePropertyGIFDictionary] as? [CFString: Any])
        let delay = try #require(frameGIFProperties[kCGImagePropertyGIFUnclampedDelayTime] as? Double)
        #expect(abs(delay - 1.0 / Double(rate.rawValue)) < 0.001)
    }

    @Test func partialTrailingFrameIsKept() async throws {
        // 35 frames at 30 fps is 1.17s, which needs 23.3 GIF frames at 20 fps
        let movieURL = try await TestMovie.make(frameCount: 35)
        defer { try? FileManager.default.removeItem(at: movieURL) }
        let gifURL = makeGIFURL()
        defer { try? FileManager.default.removeItem(at: gifURL) }

        try await GIFExporter.export(videoAt: movieURL, to: gifURL, framesPerSecond: 20) { _ in }

        let source = try #require(CGImageSourceCreateWithURL(gifURL as CFURL, nil))
        #expect(CGImageSourceGetCount(source) == 24)
    }

    @Test func wholeNumberOfGIFFramesGetsNoExtraFrame() async throws {
        // 33 frames at 30 fps is 1.1s, which is 55 GIF frames at 50 fps, but 1.1 * 50 is 55.00000000000001 as a Double
        let movieURL = try await TestMovie.make(frameCount: 33)
        defer { try? FileManager.default.removeItem(at: movieURL) }
        let gifURL = makeGIFURL()
        defer { try? FileManager.default.removeItem(at: gifURL) }

        try await GIFExporter.export(videoAt: movieURL, to: gifURL, framesPerSecond: 50) { _ in }

        let source = try #require(CGImageSourceCreateWithURL(gifURL as CFURL, nil))
        #expect(CGImageSourceGetCount(source) == 55)
    }

    @Test func eachGIFFrameShowsTheVideoFrameOnScreenAtThatTime() async throws {
        let halfASecondOfFrames = Int(TestMovie.framesPerSecond) / 2
        let movieURL = try await TestMovie.make(frameCount: halfASecondOfFrames * 2) { frame in
            frame < halfASecondOfFrames ? Self.redPixel : Self.bluePixel
        }
        defer { try? FileManager.default.removeItem(at: movieURL) }
        let gifURL = makeGIFURL()
        defer { try? FileManager.default.removeItem(at: gifURL) }

        try await GIFExporter.export(videoAt: movieURL, to: gifURL, framesPerSecond: 10) { _ in }

        let source = try #require(CGImageSourceCreateWithURL(gifURL as CFURL, nil))
        let lastRedFrame = try pixel(ofFrame: 4, in: source)
        let firstBlueFrame = try pixel(ofFrame: 5, in: source)
        #expect(isClose(lastRedFrame, to: Self.redPixel))
        #expect(isClose(firstBlueFrame, to: Self.bluePixel))
    }

    @Test func gifOfATrimmedRecordingStartsExactlyAtTheTrimPoint() async throws {
        let fps = Int(TestMovie.framesPerSecond)
        let movieURL = try await TestMovie.make(frameCount: fps * 2) { frame in
            frame < fps * 3 / 2 ? Self.redPixel : Self.bluePixel
        }
        defer { try? FileManager.default.removeItem(at: movieURL) }
        let gifURL = makeGIFURL()
        defer { try? FileManager.default.removeItem(at: gifURL) }

        let lastSecond = CMTimeRange(start: CMTime(value: 1, timescale: 1), end: CMTime(value: 2, timescale: 1))
        try await VideoTrimmer.trim(videoAt: movieURL, to: lastSecond)
        try await GIFExporter.export(videoAt: movieURL, to: gifURL, framesPerSecond: 10) { _ in }

        let source = try #require(CGImageSourceCreateWithURL(gifURL as CFURL, nil))
        let lastRedFrame = try pixel(ofFrame: 4, in: source)
        let firstBlueFrame = try pixel(ofFrame: 5, in: source)
        #expect(CGImageSourceGetCount(source) == 10)
        #expect(isClose(lastRedFrame, to: Self.redPixel))
        #expect(isClose(firstBlueFrame, to: Self.bluePixel))
    }

    @Test func reportsProgressAfterEachGIFFrame() async throws {
        let movieURL = try await TestMovie.make(frameCount: Int(TestMovie.framesPerSecond))
        defer { try? FileManager.default.removeItem(at: movieURL) }
        let gifURL = makeGIFURL()
        defer { try? FileManager.default.removeItem(at: gifURL) }
        var progress: [Double] = []

        try await GIFExporter.export(videoAt: movieURL, to: gifURL, framesPerSecond: 10) { progress.append($0) }

        #expect(progress == (1...10).map { Double($0) / 10 })
    }

    @Test func moreExportsAtOnceThanThereAreCoresAllFinish() async throws {
        let movieURL = try await TestMovie.make(frameCount: Int(TestMovie.framesPerSecond))
        defer { try? FileManager.default.removeItem(at: movieURL) }
        let exportCount = ProcessInfo.processInfo.activeProcessorCount * 2
        let gifURLs = (0..<exportCount).map { _ in makeGIFURL() }
        defer { gifURLs.forEach { try? FileManager.default.removeItem(at: $0) } }

        try await withThrowingTaskGroup(of: Void.self) { group in
            for gifURL in gifURLs {
                group.addTask {
                    try await GIFExporter.export(videoAt: movieURL, to: gifURL, framesPerSecond: 10) { _ in }
                }
            }
            try await group.waitForAll()
        }

        #expect(gifURLs.allSatisfy { FileManager.default.fileExists(atPath: $0.path()) })
    }

    @Test func gifRecordingCreatesTheGIFFolderUpFront() throws {
        let folderURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folderURL) }
        let gifURL = folderURL.appending(path: "recording.gif")

        _ = try GIFRecording(gifURL: gifURL, framesPerSecond: 20)

        #expect(FileManager.default.fileExists(atPath: folderURL.path()))
        #expect(!FileManager.default.fileExists(atPath: gifURL.path()))
    }

    @Test func gifRecordingFailsUpFrontIfTheGIFFolderIsReadOnly() throws {
        let folderURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: folderURL.path())
        defer { try? FileManager.default.removeItem(at: folderURL) }

        #expect(throws: (any Error).self) {
            _ = try GIFRecording(gifURL: folderURL.appending(path: "recording.gif"), framesPerSecond: 20)
        }
    }

    @Test func gifRecordingFinishesAsTheGIF() async throws {
        let gifURL = makeGIFURL()
        defer { try? FileManager.default.removeItem(at: gifURL) }
        let recording = try GIFRecording(gifURL: gifURL, framesPerSecond: 20)
        let movieURL = try await TestMovie.make(frameCount: 1)
        try FileManager.default.moveItem(at: movieURL, to: recording.videoURL)

        let (url, exportError) = await recording.finish()

        #expect(url == gifURL)
        #expect(exportError == nil)
        #expect(recording.exportProgress == 1)
        #expect(FileManager.default.fileExists(atPath: gifURL.path()))
        #expect(!FileManager.default.fileExists(atPath: recording.partialGIFURL.path()))
        #expect(!FileManager.default.fileExists(atPath: recording.videoURL.path()))
    }

    @Test func failedGIFExportKeepsTheRecordingAsVideo() async throws {
        let gifURL = makeGIFURL()
        let keptURL = gifURL.deletingPathExtension().appendingPathExtension("mp4")
        defer { try? FileManager.default.removeItem(at: keptURL) }
        let recording = try await makeGIFRecordingThatFailsToExport(to: gifURL)
        defer { try? FileManager.default.removeItem(at: gifURL) }

        let (url, exportError) = await recording.finish()

        #expect(url == keptURL)
        #expect(exportError != nil)
        #expect(FileManager.default.fileExists(atPath: keptURL.path()))
        #expect(!FileManager.default.fileExists(atPath: recording.partialGIFURL.path()))
        #expect(!FileManager.default.fileExists(atPath: recording.videoURL.path()))
    }

    @Test func gifRecordingStaysInPlaceIfItCannotBeKeptBesideTheGIF() async throws {
        let gifURL = makeGIFURL()
        let keptURL = gifURL.deletingPathExtension().appendingPathExtension("mp4")
        try Data().write(to: keptURL)
        defer { try? FileManager.default.removeItem(at: keptURL) }
        let recording = try await makeGIFRecordingThatFailsToExport(to: gifURL)
        defer { try? FileManager.default.removeItem(at: gifURL) }
        defer { try? FileManager.default.removeItem(at: recording.videoURL) }

        let (url, exportError) = await recording.finish()

        #expect(url == recording.videoURL)
        #expect(exportError != nil)
        #expect(FileManager.default.fileExists(atPath: recording.videoURL.path()))
    }

    // MARK: - Helpers

    private func makeGIFURL() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).gif")
    }

    /// A folder in the GIF's place stops the finished GIF being moved there.
    private func makeGIFRecordingThatFailsToExport(to gifURL: URL) async throws -> GIFRecording {
        let recording = try GIFRecording(gifURL: gifURL, framesPerSecond: 20)
        try FileManager.default.createDirectory(at: gifURL, withIntermediateDirectories: true)
        let movieURL = try await TestMovie.make(frameCount: 1)
        try FileManager.default.moveItem(at: movieURL, to: recording.videoURL)
        return recording
    }

    /// A solid-color GIF frame drawn into a single sRGB BGRA pixel.
    private func pixel(ofFrame index: Int, in source: CGImageSource) throws -> [UInt8] {
        let image = try #require(CGImageSourceCreateImageAtIndex(source, index, nil))
        let sRGB = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(
            data: nil,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: sRGB,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ))
        context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        let data = try #require(context.data).assumingMemoryBound(to: UInt8.self)
        return Array(UnsafeBufferPointer(start: data, count: 4))
    }

    private func isClose(_ pixel: [UInt8], to expected: [UInt8]) -> Bool {
        zip(pixel, expected).allSatisfy { abs(Int($0) - Int($1)) < 40 }
    }
}
