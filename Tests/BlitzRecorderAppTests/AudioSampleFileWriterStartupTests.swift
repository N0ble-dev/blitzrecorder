import AVFoundation
import CoreMedia
import XCTest
@testable import BlitzRecorderApp

final class AudioSampleFileWriterStartupTests: XCTestCase {
    func testFirstSampleNotificationFiresAfterMediaIsWritten() async throws {
        let directory = temporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let url = directory.appendingPathComponent("audio.m4a")
        let writer = try AudioSampleFileWriter(url: url)
        let firstSampleWritten = expectation(description: "first sample written")
        writer.onFirstSampleWritten = {
            firstSampleWritten.fulfill()
        }

        writer.append(try makeSilentAudioSampleBuffer())
        await fulfillment(of: [firstSampleWritten], timeout: 1)
        let completion = try await writer.finish()

        XCTAssertTrue(completion.wroteMedia)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func testWriterFailureIsReportedBeforeRecordingCanStart() async throws {
        let directory = temporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let blockingFile = directory.appendingPathComponent("not-a-directory")
        try Data().write(to: blockingFile)
        let url = blockingFile.appendingPathComponent("audio.m4a")
        let writer = try AudioSampleFileWriter(url: url)
        let failureReported = expectation(description: "writer failure reported")
        let firstSampleWritten = expectation(description: "first sample not written")
        firstSampleWritten.isInverted = true
        writer.onFirstSampleWritten = {
            firstSampleWritten.fulfill()
        }
        writer.onFailure = { _ in
            failureReported.fulfill()
        }

        writer.append(try makeSilentAudioSampleBuffer())
        await fulfillment(
            of: [failureReported, firstSampleWritten],
            timeout: 1
        )

        await XCTAssertThrowsErrorAsync {
            _ = try await writer.finish()
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    private func temporaryDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
    }

    private func makeSilentAudioSampleBuffer() throws -> CMSampleBuffer {
        var description = AudioStreamBasicDescription(
            mSampleRate: 48_000,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 4,
            mFramesPerPacket: 1,
            mBytesPerFrame: 4,
            mChannelsPerFrame: 2,
            mBitsPerChannel: 16,
            mReserved: 0
        )
        var formatDescription: CMAudioFormatDescription?
        let formatStatus = CMAudioFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            asbd: &description,
            layoutSize: 0,
            layout: nil,
            magicCookieSize: 0,
            magicCookie: nil,
            extensions: nil,
            formatDescriptionOut: &formatDescription
        )
        guard formatStatus == noErr, let formatDescription else {
            throw RecorderError.writerNotReady
        }

        let frames: CMItemCount = 480
        let byteCount = Int(frames) * Int(description.mBytesPerFrame)
        var blockBuffer: CMBlockBuffer?
        let blockStatus = CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault,
            memoryBlock: nil,
            blockLength: byteCount,
            blockAllocator: kCFAllocatorDefault,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: byteCount,
            flags: 0,
            blockBufferOut: &blockBuffer
        )
        guard blockStatus == noErr, let blockBuffer else {
            throw RecorderError.writerNotReady
        }

        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: 48_000),
            presentationTimeStamp: .zero,
            decodeTimeStamp: .invalid
        )
        var sampleBuffer: CMSampleBuffer?
        let sampleStatus = CMSampleBufferCreateReady(
            allocator: kCFAllocatorDefault,
            dataBuffer: blockBuffer,
            formatDescription: formatDescription,
            sampleCount: frames,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleSizeEntryCount: 0,
            sampleSizeArray: nil,
            sampleBufferOut: &sampleBuffer
        )
        guard sampleStatus == noErr, let sampleBuffer else {
            throw RecorderError.writerNotReady
        }
        return sampleBuffer
    }
}

private func XCTAssertThrowsErrorAsync(
    _ expression: () async throws -> Void
) async {
    do {
        try await expression()
        XCTFail("Expected error")
    } catch {}
}
