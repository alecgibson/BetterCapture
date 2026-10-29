//
//  ContainerFormatTests.swift
//  BetterCaptureTests
//
//  Created by Joshua Sattler on 28.03.26.
//

import Testing
@testable import BetterCapture

struct ContainerFormatTests {

    // MARK: - supportedVideoCodecs

    @Test func movSupportsAllCodecs() {
        let codecs = ContainerFormat.mov.supportedVideoCodecs
        #expect(codecs == VideoCodec.allCases)
    }

    @Test func mp4SupportsOnlyH264AndHEVC() {
        let codecs = ContainerFormat.mp4.supportedVideoCodecs
        #expect(codecs == [.h264, .hevc])
        #expect(!codecs.contains(.proRes422))
        #expect(!codecs.contains(.proRes4444))
    }

    @Test func gifSupportsOnlyH264() {
        #expect(ContainerFormat.gif.supportedVideoCodecs == [.h264])
    }

    // MARK: - supportsAlphaChannel

    @Test func supportsAlphaChannel() {
        #expect(ContainerFormat.mov.supportsAlphaChannel == true)
        #expect(ContainerFormat.mp4.supportsAlphaChannel == false)
        #expect(ContainerFormat.gif.supportsAlphaChannel == false)
    }

    // MARK: - supportedAudioCodecs

    @Test func movSupportsAllAudioCodecs() {
        let codecs = ContainerFormat.mov.supportedAudioCodecs
        #expect(codecs == AudioCodec.allCases)
    }

    @Test func mp4SupportsOnlyAAC() {
        let codecs = ContainerFormat.mp4.supportedAudioCodecs
        #expect(codecs == [.aac])
        #expect(!codecs.contains(.pcm))
    }

    @Test func gifSupportsNoAudio() {
        #expect(ContainerFormat.gif.supportedAudioCodecs.isEmpty)
    }

    // MARK: - supportsAudio

    @Test func supportsAudio() {
        #expect(ContainerFormat.mov.supportsAudio == true)
        #expect(ContainerFormat.mp4.supportsAudio == true)
        #expect(ContainerFormat.gif.supportsAudio == false)
    }

    // MARK: - fileExtension

    @Test func fileExtension() {
        #expect(ContainerFormat.mov.fileExtension == "mov")
        #expect(ContainerFormat.mp4.fileExtension == "mp4")
        #expect(ContainerFormat.gif.fileExtension == "gif")
    }

    // MARK: - Identifiable & RawValue

    @Test func rawValues() {
        #expect(ContainerFormat.mov.rawValue == "mov")
        #expect(ContainerFormat.mp4.rawValue == "mp4")
        #expect(ContainerFormat.gif.rawValue == "gif")
    }

    @Test func identifiable() {
        for format in ContainerFormat.allCases {
            #expect(format.id == format.rawValue)
        }
    }

    @Test func allCasesCount() {
        #expect(ContainerFormat.allCases.count == 3)
    }
}
