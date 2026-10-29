//
//  GIFSettingsTests.swift
//  BetterCaptureTests
//

import Testing
import Foundation
@testable import BetterCapture

/// Tests for how SettingsStore adjusts the other settings while GIF is selected.
@MainActor
struct GIFSettingsTests {

    private func makeStore() -> SettingsStore {
        let suiteName = "com.sattlerjoshua.BetterCaptureTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return SettingsStore(defaults: defaults)
    }

    @Test func switchingToGIFSelectsH264() {
        let store = makeStore()
        store.containerFormat = .gif
        #expect(store.videoCodec == .h264)
        #expect(store.containerFormat == .gif)
    }

    @Test func switchingToGIFDisablesHDRAndAlpha() {
        let store = makeStore()
        store.videoCodec = .proRes4444
        store.captureHDR = true

        store.containerFormat = .gif

        #expect(store.captureHDR == false)
        #expect(store.captureAlphaChannel == false)
        #expect(store.hdrPreset == .sdr)
    }

    @Test func settingHEVCOnGIFSwitchesContainerToMOV() {
        let store = makeStore()
        store.containerFormat = .gif
        store.videoCodec = .hevc
        #expect(store.containerFormat == .mov)
        #expect(store.videoCodec == .hevc)
    }

    @Test func defaultGIFFrameRateIs20() {
        let store = makeStore()
        #expect(store.gifFrameRate == .fps20)
    }

    @Test func gifCapturesAtTheGIFFrameRateUntilSwitchingBack() {
        let store = makeStore()
        store.frameRate = .fps30
        store.gifFrameRate = .fps10
        #expect(store.captureFrameRate == 30)

        store.containerFormat = .gif
        #expect(store.captureFrameRate == 10)

        store.containerFormat = .mov
        #expect(store.captureFrameRate == 30)
    }

    @Test func switchingToGIFWithPCMKeepsGIF() {
        let store = makeStore()
        store.audioCodec = .pcm
        store.containerFormat = .gif
        #expect(store.containerFormat == .gif)
        #expect(store.audioCodec == .pcm)
    }

    @Test func gifDisablesAudioCaptureUntilSwitchingBack() {
        let store = makeStore()
        store.captureSystemAudio = true
        store.captureMicrophone = true

        store.containerFormat = .gif
        #expect(store.captureSystemAudio == false)
        #expect(store.captureMicrophone == false)

        store.containerFormat = .mov
        #expect(store.captureSystemAudio == true)
        #expect(store.captureMicrophone == true)
    }
}
