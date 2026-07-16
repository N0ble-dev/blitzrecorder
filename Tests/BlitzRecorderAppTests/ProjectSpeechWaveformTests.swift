import XCTest
@testable import BlitzRecorderApp

final class ProjectSpeechWaveformTests: XCTestCase {
    func testSpeechSegmentsLeaveVisibleSilenceGaps() {
        let segments = [
            RecordingTranscript.Segment(
                id: UUID(),
                speakerID: "Speaker 1",
                startTime: 10,
                endTime: 20,
                text: "A short spoken section with several words.",
                confidence: 0.9
            ),
            RecordingTranscript.Segment(
                id: UUID(),
                speakerID: "Speaker 2",
                startTime: 70,
                endTime: 90,
                text: "Another spoken section later in the recording.",
                confidence: 0.8
            )
        ]

        let samples = ProjectSpeechWaveform.samples(.init(
            segments: segments,
            duration: 100,
            bucketCount: 10
        ))

        XCTAssertEqual(samples.count, 10)
        XCTAssertGreaterThan(samples[1], 0)
        XCTAssertEqual(samples[4], 0)
        XCTAssertGreaterThan(samples[7], 0)
    }
}
