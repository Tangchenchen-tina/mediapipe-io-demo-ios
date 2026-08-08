import XCTest

final class EmailBodySplitterTests: XCTestCase {

    func testTypicalEmailSplitsIntoGreetingMiddleClosing() {
        let body = "Hi team,\n\nPlease review the attached docs.\n\nThanks,\nAlex"
        let parts = splitEmailBody(body)
        XCTAssertEqual(parts.greeting, "Hi team,")
        XCTAssertEqual(parts.middle, "Please review the attached docs.")
        XCTAssertEqual(parts.closing, "Thanks,\nAlex")
    }

    func testMultipleMiddleParagraphsAreAllKeptOutOfGreetingAndClosing() {
        let body = "Hi all,\n\nFirst paragraph.\n\nSecond paragraph.\n\nThird paragraph.\n\nRegards,\nTeam"
        let parts = splitEmailBody(body)
        XCTAssertEqual(parts.greeting, "Hi all,")
        XCTAssertEqual(parts.middle, "First paragraph.\n\nSecond paragraph.\n\nThird paragraph.")
        XCTAssertEqual(parts.closing, "Regards,\nTeam")
    }

    func testTooFewParagraphsTreatsWholeBodyAsMiddle() {
        let body = "Just one paragraph, no greeting or sign-off."
        let parts = splitEmailBody(body)
        XCTAssertEqual(parts.greeting, "")
        XCTAssertEqual(parts.middle, body)
        XCTAssertEqual(parts.closing, "")
    }

    func testGreetingAndClosingOnlyWithNoMiddleStillTreatsWholeBodyAsMiddle() {
        let body = "Hi,\n\nThanks,\nAlex"
        let parts = splitEmailBody(body)
        // Only 2 paragraphs — doesn't meet the 3-paragraph shape, so nothing is assumed safe to
        // carve out untouched.
        XCTAssertEqual(parts.greeting, "")
        XCTAssertEqual(parts.middle, body)
        XCTAssertEqual(parts.closing, "")
    }

    func testJoinedReconstructsTheOriginalTypicalEmail() {
        let body = "Hi team,\n\nPlease review the attached docs.\n\nThanks,\nAlex"
        let parts = splitEmailBody(body)
        XCTAssertEqual(parts.joined(), body)
    }

    func testJoinedWithReplacedMiddleOnlyChangesTheMiddle() {
        let parts = splitEmailBody("Hi team,\n\nPlease review the attached docs.\n\nThanks,\nAlex")
        let corrected = EmailBodyParts(greeting: parts.greeting, middle: "Please review the attached documents.", closing: parts.closing)
        XCTAssertEqual(corrected.joined(), "Hi team,\n\nPlease review the attached documents.\n\nThanks,\nAlex")
    }
}
