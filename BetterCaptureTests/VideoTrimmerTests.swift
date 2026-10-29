//
//  VideoTrimmerTests.swift
//  BetterCaptureTests
//

import AVFoundation
import Testing
@testable import BetterCapture

@MainActor
struct VideoTrimmerTests {

    @Test(arguments: [AVFileType.mov, .mp4])
    func trimsTheVideoInPlace(fileType: AVFileType) async throws {
        let movieURL = try await makeMovieInOwnFolder(frameCount: Int(TestMovie.framesPerSecond) * 2, fileType: fileType)
        defer { try? FileManager.default.removeItem(at: movieURL.deletingLastPathComponent()) }

        let middleSecond = CMTimeRange(start: CMTime(value: 1, timescale: 2), duration: CMTime(value: 1, timescale: 1))
        try await VideoTrimmer.trim(videoAt: movieURL, to: middleSecond)

        let duration = try await AVURLAsset(url: movieURL).load(.duration)
        #expect(abs(duration.seconds - 1) < 0.05)
        #expect(try folderContents(containing: movieURL) == [movieURL.lastPathComponent])
    }

    @Test func failedTrimLeavesTheOriginalUntouched() async throws {
        let folderURL = try makeFolder()
        defer { try? FileManager.default.removeItem(at: folderURL) }
        let movieURL = folderURL.appending(path: "recording.mov")
        let unreadable = Data("not a movie".utf8)
        try unreadable.write(to: movieURL)

        let allOfIt = CMTimeRange(start: .zero, duration: CMTime(value: 1, timescale: 1))
        await #expect(throws: (any Error).self) {
            try await VideoTrimmer.trim(videoAt: movieURL, to: allOfIt)
        }

        #expect(try Data(contentsOf: movieURL) == unreadable)
        #expect(try folderContents(containing: movieURL) == [movieURL.lastPathComponent])
    }

    // MARK: - Helpers

    private func makeFolder() throws -> URL {
        let folderURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        return folderURL
    }

    private func makeMovieInOwnFolder(frameCount: Int, fileType: AVFileType) async throws -> URL {
        let folderURL = try makeFolder()
        let movieURL = try await TestMovie.make(frameCount: frameCount, fileType: fileType)
        let movedURL = folderURL.appending(path: movieURL.lastPathComponent)
        try FileManager.default.moveItem(at: movieURL, to: movedURL)
        return movedURL
    }

    private func folderContents(containing url: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: url.deletingLastPathComponent().path())
    }
}
