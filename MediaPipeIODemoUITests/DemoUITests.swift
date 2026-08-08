import XCTest

/// Drives the four flows shown in the README's demo clips — not a correctness test suite (that's
/// `MediaPipeIODemoTests`), just enough real, deterministic navigation to record a clean screen
/// capture of each. Run individually (`-only-testing:MediaPipeIODemoUITests/DemoUITests/<name>`)
/// while `xcrun simctl io booted recordVideo` is capturing, against a freshly installed app so
/// each flow starts from its natural "nothing done yet" state.
@MainActor
final class DemoUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testDemoChatsEmbedding() throws {
        let app = XCUIApplication()
        app.launch()

        let reembedButton = app.buttons["Re-embed all"]
        XCTAssertTrue(reembedButton.waitForExistence(timeout: 20))
        reembedButton.tap()

        // Re-embedding all 5 threads means embedding every individual message in each, not just
        // the threads themselves — real on-device inference for dozens of items, genuinely slow
        // on the Simulator's CPU path, not a stuck/broken run.
        let done = app.staticTexts["5/5 chats embedded"]
        XCTAssertTrue(done.waitForExistence(timeout: 180))
        Thread.sleep(forTimeInterval: 1.5)
    }

    func testDemoArchiveSummarize() throws {
        let app = XCUIApplication()
        app.launch()

        app.tabBars.buttons["Archive"].tap()
        let card = app.staticTexts["Attention Is All You Need"]
        XCTAssertTrue(card.waitForExistence(timeout: 20))
        card.tap()

        let pdfView = app.descendants(matching: .any)["archivePDFView"]
        XCTAssertTrue(pdfView.waitForExistence(timeout: 20))

        app.segmentedControls.buttons["Select Page"].tap()
        pdfView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4)).tap()

        let summarizeButton = app.buttons["archiveSummarizeButton"]
        XCTAssertTrue(summarizeButton.waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 0.5)
        summarizeButton.tap()

        Thread.sleep(forTimeInterval: 8)
    }

    func testDemoEmailProofread() throws {
        let app = XCUIApplication()
        app.launch()

        app.tabBars.buttons["Email"].tap()
        let row = app.staticTexts["Architecture Review Alignment"]
        XCTAssertTrue(row.waitForExistence(timeout: 20))
        row.tap()

        let proofreadButton = app.buttons["emailProofreadButton"]
        XCTAssertTrue(proofreadButton.waitForExistence(timeout: 10))
        proofreadButton.tap()

        Thread.sleep(forTimeInterval: 8)
    }

    func testDemoStickerGenerator() throws {
        let app = XCUIApplication()
        app.launch()

        app.tabBars.buttons["Stickers"].tap()
        app.buttons["New Sticker"].tap()

        let libraryButton = app.buttons["Choose from Library"]
        XCTAssertTrue(libraryButton.waitForExistence(timeout: 10))
        libraryButton.tap()

        // `app.images` alone also matches the Stickers tab bar's own icon glyph (an Image
        // sharing the app's accessibility tree) — scope to the picker's actual photo cells, whose
        // accessibility labels are all "Photo, <date>". The grid is sorted newest-first and the
        // demo source image is added via `simctl addmedia` immediately before recording, so it's
        // reliably the first match.
        let photoCells = app.images.matching(NSPredicate(format: "label BEGINSWITH %@", "Photo,"))
        let firstPhoto = photoCells.firstMatch
        XCTAssertTrue(firstPhoto.waitForExistence(timeout: 10))
        firstPhoto.tap()

        let statusText = app.staticTexts["stickerStatusText"]
        XCTAssertTrue(statusText.waitForExistence(timeout: 20))
        let ready = NSPredicate(format: "label == %@", "Draw on the subject to select it")
        _ = XCTWaiter.wait(for: [expectation(for: ready, evaluatedWith: statusText)], timeout: 15)

        let canvas = app.descendants(matching: .any)["stickerCanvas"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 10))
        let start = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
        let end = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.62, dy: 0.55))
        start.press(forDuration: 0.05, thenDragTo: end)

        let readyAfterStroke = NSPredicate(format: "label == %@", "Ready")
        _ = XCTWaiter.wait(for: [expectation(for: readyAfterStroke, evaluatedWith: statusText)], timeout: 20)
        Thread.sleep(forTimeInterval: 1)

        let saveButton = app.buttons["Save Sticker"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        saveButton.tap()

        Thread.sleep(forTimeInterval: 1.5)
    }
}
