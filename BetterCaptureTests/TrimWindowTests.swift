//
//  TrimWindowTests.swift
//  BetterCaptureTests
//

import CoreMedia
import Testing
@testable import BetterCapture

@MainActor
struct TrimWindowTests {

    private let duration = CMTime(value: 10, timescale: 1)
    private let twoSeconds = CMTime(value: 2, timescale: 1)
    private let sixSeconds = CMTime(value: 6, timescale: 1)

    @Test func untouchedHandlesKeepTheWholeVideo() {
        #expect(TrimWindow.keptRange(trimStart: .invalid, trimEnd: .invalid, duration: duration) == nil)
    }

    @Test func handlesAtBothEndsKeepTheWholeVideo() {
        #expect(TrimWindow.keptRange(trimStart: .zero, trimEnd: duration, duration: duration) == nil)
    }

    @Test func movingOnlyTheEndKeepsFromTheStart() {
        let range = TrimWindow.keptRange(trimStart: .invalid, trimEnd: sixSeconds, duration: duration)
        #expect(range == CMTimeRange(start: .zero, end: sixSeconds))
    }

    @Test func movingOnlyTheStartKeepsToTheEnd() {
        let range = TrimWindow.keptRange(trimStart: twoSeconds, trimEnd: .invalid, duration: duration)
        #expect(range == CMTimeRange(start: twoSeconds, end: duration))
    }

    @Test func movingBothKeepsTheRangeBetweenThem() {
        let range = TrimWindow.keptRange(trimStart: twoSeconds, trimEnd: sixSeconds, duration: duration)
        #expect(range == CMTimeRange(start: twoSeconds, end: sixSeconds))
    }
}
