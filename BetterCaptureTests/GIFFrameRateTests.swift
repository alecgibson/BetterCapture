//
//  GIFFrameRateTests.swift
//  BetterCaptureTests
//

import Testing
@testable import BetterCapture

struct GIFFrameRateTests {

    @Test(arguments: GIFFrameRate.allCases)
    func everyRateDividesOneHundredCentiseconds(rate: GIFFrameRate) {
        #expect(100.isMultiple(of: rate.rawValue))
    }

    @Test func displayName() {
        #expect(GIFFrameRate.fps20.displayName == "20 fps")
    }
}
