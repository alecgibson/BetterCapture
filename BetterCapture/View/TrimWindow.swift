//
//  TrimWindow.swift
//  BetterCapture
//

import AppKit
import AVKit
import Combine

/// A window showing QuickTime's trim controls, so a recording can be trimmed before it is saved.
@MainActor
enum TrimWindow {

    /// Shows the video with trim handles and waits for the user to press Trim or Cancel.
    /// - Returns: The part of the video to keep, or `nil` to keep all of it because the user cancelled,
    ///   left the handles where they were, or the video failed to load
    static func trimRange(forVideoAt url: URL) async -> CMTimeRange? {
        let item = AVPlayerItem(url: url)
        let playerView = AVPlayerView()
        playerView.controlsStyle = .inline
        playerView.player = AVPlayer(playerItem: item)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 960, height: 600),
            styleMask: [.titled, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Trim Recording"
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        window.contentView = playerView
        window.center()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        defer {
            playerView.player?.pause()
            window.close()
        }

        let loadedStatus = await firstValue(of: item.publisher(for: \.status)) { $0 != .unknown }
        guard loadedStatus == .readyToPlay else {
            return nil
        }

        while !playerView.canBeginTrimming {
            guard await firstValue(of: playerView.publisher(for: \.canBeginTrimming), where: { $0 }) != nil else {
                return nil
            }
        }
        guard await playerView.beginTrimming() == .okButton else {
            return nil
        }

        return keptRange(trimStart: item.reversePlaybackEndTime, trimEnd: item.forwardPlaybackEndTime, duration: item.duration)
    }

    /// Unlike `publisher.values.first(where:)`, this can't miss a value the publisher sends while `AsyncPublisher` has
    /// no outstanding demand.
    private static func firstValue<Value>(
        of publisher: some Publisher<Value, Never>,
        where predicate: @escaping (Value) -> Bool
    ) async -> Value? {
        await publisher.first(where: predicate).values.first { _ in true }
    }

    /// The range between the trim handles, which `AVPlayerView` reports as the player item's playback end times.
    /// An invalid time means that end of the video was left in place.
    /// - Returns: `nil` if the range covers the whole video
    static func keptRange(trimStart: CMTime, trimEnd: CMTime, duration: CMTime) -> CMTimeRange? {
        let fullRange = CMTimeRange(start: .zero, duration: duration)
        let trimmedRange = CMTimeRange(
            start: trimStart.isValid ? trimStart : fullRange.start,
            end: trimEnd.isValid ? trimEnd : fullRange.end
        )
        return trimmedRange == fullRange ? nil : trimmedRange
    }
}
