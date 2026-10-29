//
//  GIFFileWriter.swift
//  BetterCapture
//

import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Writes an animated GIF to disk one frame at a time.
///
/// `CGImageDestination` holds every frame in memory until it is finalized, which a long Retina
/// recording can't afford. Instead, ImageIO encodes each frame as a GIF of its own, and that GIF's
/// image block is copied into this file with its color table made local to the frame.
nonisolated struct GIFFileWriter {

    private static let signature = Array("GIF89a".utf8)
    private static let loopForever: [UInt8] = [0x21, 0xFF, 0x0B] + Array("NETSCAPE2.0".utf8) + [0x03, 0x01, 0x00, 0x00, 0x00]
    private static let trailer: UInt8 = 0x3B
    private static let extensionIntroducer: UInt8 = 0x21
    private static let graphicControlLabel: UInt8 = 0xF9
    private static let extensionHeaderLength = 2
    private static let imageSeparator: UInt8 = 0x2C
    private static let screenFlagsOffset = 10
    private static let screenDescriptorEnd = 13
    private static let imageDescriptorLength = 10
    private static let imageFlagsOffset = 9
    private static let colorTableFlag: UInt8 = 0x80
    private static let colorTableSizeBits: UInt8 = 0x07

    private let file: FileHandle
    private let graphicControlExtension: [UInt8]

    /// Creates the file and writes a header that loops the animation forever.
    init(url: URL, width: Int, height: Int, centisecondsPerFrame: Int) throws {
        try Data().write(to: url)
        file = try FileHandle(forWritingTo: url)
        graphicControlExtension = [Self.extensionIntroducer, Self.graphicControlLabel, 0x04, 0x00] + Self.littleEndian(centisecondsPerFrame) + [0x00, 0x00]

        let screenDescriptor = Self.littleEndian(width) + Self.littleEndian(height) + [0x00, 0x00, 0x00]
        try file.write(contentsOf: Self.signature + screenDescriptor + Self.loopForever)
    }

    func append(_ image: CGImage) throws {
        let gif = try Self.encode(image)
        try file.write(contentsOf: graphicControlExtension + Self.imageBlock(of: gif))
    }

    func finish() throws {
        try file.write(contentsOf: [Self.trailer])
        try file.close()
    }

    private static func encode(_ image: CGImage) throws -> [UInt8] {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data as CFMutableData, UTType.gif.identifier as CFString, 1, nil) else {
            throw GIFExporterError.failedToEncodeFrame
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw GIFExporterError.failedToEncodeFrame
        }
        return [UInt8](data as Data)
    }

    /// The image descriptor and image data of a single-frame GIF, carrying the global color table
    /// as a local one when the frame has none of its own.
    private static func imageBlock(of gif: [UInt8]) throws -> [UInt8] {
        guard gif.count > screenDescriptorEnd, gif.last == trailer else {
            throw GIFExporterError.failedToEncodeFrame
        }
        let screenFlags = gif[screenFlagsOffset]
        let globalColorTableEnd = screenDescriptorEnd + colorTableLength(flags: screenFlags)
        let descriptorStart = try endOfExtensions(in: gif, from: globalColorTableEnd)
        let descriptorEnd = descriptorStart + imageDescriptorLength
        guard gif[descriptorStart] == imageSeparator, descriptorEnd < gif.count else {
            throw GIFExporterError.failedToEncodeFrame
        }

        var descriptor = Array(gif[descriptorStart..<descriptorEnd])
        let imageData = gif[descriptorEnd...].dropLast()
        guard descriptor[imageFlagsOffset] & colorTableFlag == 0 else {
            return descriptor + imageData
        }

        descriptor[imageFlagsOffset] |= colorTableFlag | (screenFlags & colorTableSizeBits)
        return descriptor + gif[screenDescriptorEnd..<globalColorTableEnd] + imageData
    }

    /// Skips extension blocks, each an introducer and label followed by data sub-blocks that end
    /// with an empty one.
    private static func endOfExtensions(in gif: [UInt8], from start: Int) throws -> Int {
        var offset = start
        while offset < gif.count, gif[offset] == extensionIntroducer {
            offset += extensionHeaderLength
            while offset < gif.count, gif[offset] != 0 {
                offset += Int(gif[offset]) + 1
            }
            offset += 1
        }
        guard offset < gif.count else {
            throw GIFExporterError.failedToEncodeFrame
        }
        return offset
    }

    private static func colorTableLength(flags: UInt8) -> Int {
        guard flags & colorTableFlag != 0 else {
            return 0
        }
        return 3 << (Int(flags & colorTableSizeBits) + 1)
    }

    private static func littleEndian(_ value: Int) -> [UInt8] {
        [UInt8(truncatingIfNeeded: value), UInt8(truncatingIfNeeded: value >> 8)]
    }
}
