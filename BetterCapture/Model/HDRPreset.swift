//
//  HDRPreset.swift
//  BetterCapture
//

import Foundation

/// Describes which ScreenCaptureKit HDR configuration is active, so the
/// ``AssetWriter`` can tag the output container with matching colorimetry.
enum HDRPreset {
    /// SDR capture — no HDR color properties needed.
    case sdr

    /// Manual BT.2020 / PQ configuration applied to a plain
    /// `SCStreamConfiguration`. Used on macOS 15–25 to produce
    /// HDR10-compatible output (BT.2020 primaries, PQ transfer
    /// function, BT.2020 YCbCr matrix).
    case hdr10Manual

    /// ``SCStreamConfiguration.Preset.captureHDRRecordingPreservedSDRHDR10``
    /// (macOS 26+). Same BT.2020 / PQ colorimetry as `.hdr10Manual`, but
    /// also injects static HDR10 mastering metadata and preserves SDR UI
    /// appearance on HDR screens.
    case hdr10PreservedSDR
}
