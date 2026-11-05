import XCTest

@MainActor
final class DiskUsageUITests: XCTestCase {
    func testMediumWidgetDisplaysAndCyclesThroughWritableVolumes() {
        let app = launch(size: "medium", language: "en")
        let window = app.windows["Widget Preview"]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        XCTAssertTrue(window.staticTexts["Macintosh HD"].waitForExistence(timeout: 10))
        XCTAssertTrue(window.staticTexts["Archive"].exists)
        XCTAssertTrue(window.staticTexts["7.0% free"].exists)
        XCTAssertTrue(window.staticTexts["Total 2 TB"].exists)
        XCTAssertTrue(window.staticTexts["Free 140 GB"].exists)
        XCTAssertTrue(window.descendants(matching: .any)["93.0% used"].exists)

        let cycle = window.buttons["Next Volume"]
        XCTAssertTrue(cycle.exists)
        cycle.click()
        XCTAssertTrue(window.staticTexts["Backup"].waitForExistence(timeout: 5))
        XCTAssertTrue(window.staticTexts["Macintosh HD"].exists)
        XCTAssertTrue(window.staticTexts["30.0% free"].exists)
        XCTAssertFalse(window.staticTexts["Installer"].exists)

        cycle.click()
        XCTAssertTrue(window.staticTexts["Archive"].waitForExistence(timeout: 5))
        XCTAssertFalse(window.staticTexts["Installer"].exists)
    }

    func testSmallWidgetFitsBothRowsInJapaneseAndEnglish() {
        for (language, free, total, next) in [
            ("en", "Free 140 GB (7.0%)", "Total 2 TB", "Next Volume"),
            ("ja", "空き 140 GB（7.0%）", "全容量 2 TB", "次のボリューム"),
        ] {
            let app = launch(size: "small", language: language)
            let window = app.windows["Widget Preview"]
            XCTAssertTrue(window.waitForExistence(timeout: 10))
            XCTAssertEqual(window.frame.width, 164, accuracy: 4)
            let title = window.staticTexts["Macintosh HD"]
            XCTAssertTrue(title.waitForExistence(timeout: 10))
            let capacity = window.staticTexts[free]
            XCTAssertTrue(capacity.exists)
            XCTAssertTrue(window.staticTexts[total].exists)
            XCTAssertGreaterThan(capacity.frame.minY, title.frame.minY)
            XCTAssertTrue(window.frame.contains(capacity.frame))
            let cycle = window.buttons[next]
            XCTAssertTrue(cycle.exists)
            cycle.click()
            XCTAssertTrue(window.staticTexts["Backup"].waitForExistence(timeout: 5))
            XCTAssertTrue(title.exists)
            app.terminate()
        }
    }

    private func launch(size: String, language: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "--widget-ui-test", size,
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", language == "ja" ? "ja_JP" : "en_US",
        ]
        app.launch()
        return app
    }
}
