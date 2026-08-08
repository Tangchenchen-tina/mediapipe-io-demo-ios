import XCTest

final class WordDiffTests: XCTestCase {

    func testIdenticalTextIsEntirelyUnchanged() {
        let segments = computeWordDiff(original: "the quick fox", corrected: "the quick fox")
        XCTAssertEqual(segments, [.unchanged("the quick fox")])
    }

    func testSingleWordReplacementIsRemovedThenAdded() {
        let segments = computeWordDiff(original: "I confirm the plan", corrected: "I confirmed the plan")
        XCTAssertEqual(segments, [
            .unchanged("I "),
            .removed("confirm"),
            .added("confirmed"),
            .unchanged(" the plan"),
        ])
    }

    func testPureInsertionHasNoRemovedSegments() {
        let segments = computeWordDiff(original: "go home", corrected: "go straight home")
        XCTAssertEqual(segments, [
            .unchanged("go "),
            .added("straight "),
            .unchanged("home"),
        ])
    }

    func testPureDeletionHasNoAddedSegments() {
        let segments = computeWordDiff(original: "go straight home", corrected: "go home")
        XCTAssertEqual(segments, [
            .unchanged("go "),
            .removed("straight "),
            .unchanged("home"),
        ])
    }

    func testEmptyOriginalIsAllAdded() {
        XCTAssertEqual(computeWordDiff(original: "", corrected: "new text"), [.added("new text")])
    }

    func testEmptyCorrectedIsAllRemoved() {
        XCTAssertEqual(computeWordDiff(original: "old text", corrected: ""), [.removed("old text")])
    }

    func testBothEmptyProducesNoSegments() {
        XCTAssertEqual(computeWordDiff(original: "", corrected: ""), [])
    }

    func testMultipleCorrectionsAcrossSentenceAreAllCaptured() {
        let original = "Dave will handling the release, and Rachel will queues up the post."
        let corrected = "Dave will handle the release, and Rachel will queue up the post."
        let segments = computeWordDiff(original: original, corrected: corrected)

        let removed = segments.compactMap { segment -> String? in
            if case .removed(let text) = segment { return text }
            return nil
        }.joined()
        let added = segments.compactMap { segment -> String? in
            if case .added(let text) = segment { return text }
            return nil
        }.joined()

        XCTAssertEqual(removed, "handlingqueues")
        XCTAssertEqual(added, "handlequeue")
    }

    func testSegmentsReconstructOriginalAndCorrected() {
        let original = "the global product launch date are set"
        let corrected = "the global product launch date is set"
        let segments = computeWordDiff(original: original, corrected: corrected)

        let reconstructedOriginal = segments.map { segment -> String in
            switch segment {
            case .unchanged(let text), .removed(let text): return text
            case .added: return ""
            }
        }.joined()
        let reconstructedCorrected = segments.map { segment -> String in
            switch segment {
            case .unchanged(let text), .added(let text): return text
            case .removed: return ""
            }
        }.joined()

        XCTAssertEqual(reconstructedOriginal, original)
        XCTAssertEqual(reconstructedCorrected, corrected)
    }
}
