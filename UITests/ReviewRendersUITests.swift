// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import XCTest

/// Renders for the owner's review of a UI change (plan of 2026-11-14), upright and sideways.
/// Sample data only; run on a Simulator, never a real phone. Each screen is attached as `rNN-name`.
/// Before the run, grant Photos on the Simulator so the Photos findings show:
///   xcrun simctl privacy <udid> grant photos com.hyya.footprintinspector
final class ReviewRendersUITests: XCTestCase {
    private var app: XCUIApplication!
    private var tag = ""

    override func setUp() { continueAfterFailure = true }

    func testUpright() { renders(.portrait, "up") }
    func testSideways() { renders(.landscapeLeft, "side") }

    private func launch(_ extra: [String] = [], _ orientation: UIDeviceOrientation) {
        app?.terminate()
        app = XCUIApplication()
        app.launchArguments = ["-sampleData"] + extra
        app.launch()
        XCUIDevice.shared.orientation = orientation
        sleep(2)
    }

    private func shot(_ name: String) {
        sleep(1)
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = "\(name)-\(tag)"
        a.lifetime = .keepAlways
        add(a)
    }

    private func tab(_ name: String) { app.buttons[name].firstMatch.tap(); sleep(2) }

    private func scrollTo(_ el: XCUIElement, max: Int = 10) {
        var n = 0
        while (!el.exists || !el.isHittable) && n < max { app.swipeUp(velocity: .slow); n += 1 }
    }

    /// Checks 2 and 3, then the Footprint scan: the state most people reach first.
    private func threeChecks() {
        tab("Sensitive apps")
        for name in ["Dating and LGBTQ+", "Health and fertility"] {
            let row = app.buttons.containing(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
            scrollTo(row, max: 4)
            if row.exists && !row.isSelected { row.tap() }
        }
        let check = app.buttons.containing(NSPredicate(format: "label BEGINSWITH 'Check '")).firstMatch
        scrollTo(check, max: 6)
        if check.exists { check.tap(); sleep(2) }
        tab("Tracker")
        tab("Footprint")
        let start = app.buttons["Start with check 1"].firstMatch
        if start.waitForExistence(timeout: 4) { start.tap() }
        _ = app.buttons["Scan again"].waitForExistence(timeout: 25)
        sleep(2)
    }

    private func renders(_ orientation: UIDeviceOrientation, _ tag: String) {
        self.tag = tag

        // D1, D2, D5: the Score page and the Footprint results.
        launch([], orientation)
        threeChecks()
        shot("r02-results")                             // D2: Fix them with me first
        tab("Score")
        shot("r01-score")                               // D1: the next check first

        // D6, D3: the fix walk.
        tab("Footprint")
        app.buttons["Fix them with me"].firstMatch.tap()
        sleep(2)
        shot("r04-fix-walk")
        app.buttons["Close"].firstMatch.tap()
        sleep(3)

        // S1: a Photos finding with the hYYa Encrypted Folder suggestion.
        let photos = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Photos'")).firstMatch
        scrollTo(photos, max: 12)
        if photos.exists {
            photos.tap(); sleep(2)
            let places = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Places in your photos'")).firstMatch
            if places.waitForExistence(timeout: 4) { places.tap(); sleep(2) }
            let card = app.staticTexts["From the makers of this app"].firstMatch
            scrollTo(card, max: 12)
            app.swipeUp(velocity: .slow)
            shot("r05-finding-suggestion")
        }

        // S3, S1: Settings.
        tab("Settings")
        shot("r06-settings-top")
        scrollTo(app.staticTexts["Enjoying hYYa Digital Footprint Check?"].firstMatch, max: 6)
        shot("r06-settings-rate")
        scrollTo(app.switches.firstMatch, max: 8)
        app.swipeUp(velocity: .slow)
        shot("r06-settings-more")

        // S2: after a scan that raised the score.
        launch(["-previewRise"], orientation)
        tab("Footprint")
        let start = app.buttons["Start with check 1"].firstMatch
        if start.waitForExistence(timeout: 4) { start.tap() }
        _ = app.buttons["Scan again"].waitForExistence(timeout: 25)
        let share = app.buttons["Share your progress"].firstMatch
        scrollTo(share, max: 8)
        app.swipeUp(velocity: .slow)
        shot("r03-score-rise")

        // Owed: the "add the widget" card, and the widget's face in each rendering mode.
        launch(["-previewWidgetOffer"], orientation)
        threeChecks()
        tab("Score")
        scrollTo(app.staticTexts["Your score on your home screen"].firstMatch, max: 8)
        app.swipeUp(velocity: .slow)
        shot("r08-widget-card")
        launch(["-widgetLab"], orientation)
        shot("r09-widget-modes")
        app.swipeUp(velocity: .slow)
        shot("r09-widget-modes-2")

        // D4: the note papers at three strengths.
        for soft in ["0", "0.3", "0.5"] {
            launch(["-paperSoft", soft], orientation)
            threeChecks()
            app.swipeUp(velocity: .slow); app.swipeUp(velocity: .slow)
            shot("r07-papers-\(soft)-results")
            tab("Tracker")
            shot("r07-papers-\(soft)-tracker")
        }
    }
}
