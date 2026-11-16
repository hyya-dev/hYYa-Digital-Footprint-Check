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

    /// 1.1.0 "simple by default": the screens the tester found crowded, upright and sideways.
    func testSimple() {
        for (o, t) in [(UIDeviceOrientation.portrait, "up"), (.landscapeLeft, "side")] {
            tag = t
            launch([], o)
            threeChecks()
            shot("s02-results")
            app.swipeUp(velocity: .slow)
            shot("s02-results-2")
            let all = app.buttons.containing(NSPredicate(format: "label BEGINSWITH 'See everything apps can read'")).firstMatch
            scrollTo(all, max: 6)
            if all.exists { all.tap(); sleep(1) }
            app.swipeUp(velocity: .slow)
            shot("s02-results-all")
            tab("Score")
            shot("s01-score")

            launch(["-autoScan", "-openFinding", "audio-route"], o)
            sleep(16)
            shot("s03-finding")
            let more = app.buttons["More about this"].firstMatch
            scrollTo(more, max: 6)
            if more.exists { more.tap(); sleep(1) }
            app.swipeUp(velocity: .slow)
            shot("s03-finding-more")

            launch(["-startTab", "checkup"], o)
            shot("s04-checkup")
            let areas = app.buttons.containing(NSPredicate(format: "label BEGINSWITH 'More areas'")).firstMatch
            scrollTo(areas, max: 6)
            for _ in 0..<3 where !app.buttons.containing(NSPredicate(format: "label BEGINSWITH 'Hide the other areas'")).firstMatch.exists {
                if areas.exists { areas.tap(); sleep(1) }
            }
            app.swipeUp(velocity: .slow)
            shot("s04-checkup-more")
        }
    }
    /// Book pose (owner, 2026-11-16): two pages side by side on a wide, tall screen. Run on an iPad sideways
    /// (or the open Duo in Device Hub). Score | next check, Score | each check, then check | detail.
    func testBook() {
        tag = "book"
        launch(["-autoScan"], .landscapeLeft)
        sleep(14)
        tab("Score"); shot("b01-score")
        tab("Footprint"); shot("b02-footprint")
        launch(["-autoScan", "-openFinding", "audio-route"], .landscapeLeft)
        sleep(14)
        shot("b03-finding")
        launch(["-startTab", "sensitive"], .landscapeLeft)
        shot("b04-sensitive")
        launch(["-startTab", "checkup"], .landscapeLeft)
        shot("b05-checkup")
        let first = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Safety Check'")).firstMatch
        if first.waitForExistence(timeout: 5) { first.tap(); sleep(2) }
        shot("b06-checkup-step")
        launch(["-startTab", "tracker"], .landscapeLeft)
        shot("b07-tracker")
        launch(["-startTab", "settings"], .landscapeLeft)
        shot("b08-settings")
    }

    /// Just the score-rise and hYYa-suggestion shots, upright and sideways.
    func testRiseAndSuggestion() {
        for (o, t) in [(UIDeviceOrientation.portrait, "up"), (.landscapeLeft, "side")] {
            tag = t
            launch(["-previewRise"], o)
            tab("Footprint")
            let start = app.buttons["Start with check 1"].firstMatch
            if start.waitForExistence(timeout: 4) { start.tap() }
            _ = app.buttons["Scan again"].waitForExistence(timeout: 25)
            // Small steps: on a short sideways screen one swipe can jump right over the card.
            let share = app.buttons["Share your progress"].firstMatch
            let mid = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
            var steps = 0
            while steps < 40 && !(share.exists && share.frame.minY > 40 && share.frame.maxY < app.frame.maxY - 60) {
                mid.press(forDuration: 0.05, thenDragTo: mid.withOffset(CGVector(dx: 0, dy: -110)))
                steps += 1
            }
            shot("r03-score-rise")

            let photos = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Photos'")).firstMatch
            scrollTo(photos, max: 12)
            photos.tap(); sleep(2)
            let showMe = app.buttons["Show me"].firstMatch
            if showMe.waitForExistence(timeout: 3) {
                showMe.tap(); sleep(2)
                let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
                for label in ["Allow Full Access", "Allow Access to All Photos", "Allow"] {
                    let b = springboard.buttons[label]
                    if b.waitForExistence(timeout: 2) { b.tap(); break }
                }
                sleep(4)
            }
            let places = app.buttons.containing(NSPredicate(format: "label CONTAINS 'map where'")).firstMatch
            scrollTo(places, max: 6)
            places.tap(); sleep(2)
            scrollTo(app.buttons["No thanks"].firstMatch, max: 12)
            shot("r05-finding-suggestion")
        }
    }
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
        // Frames, not isHittable: for an element off screen, isHittable can throw instead of returning false.
        func onScreen() -> Bool { el.exists && app.frame.insetBy(dx: 0, dy: 40).contains(el.frame) }
        while !onScreen() && n < max { app.swipeUp(velocity: .slow); n += 1 }
        // A swipe can carry it just past the top: drag back a little.
        var back = 0
        while el.exists && el.frame.minY < 60 && back < 4 {
            let mid = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4))
            mid.press(forDuration: 0.05, thenDragTo: mid.withOffset(CGVector(dx: 0, dy: 140)))
            back += 1
        }
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
            let showMe = app.buttons["Show me"].firstMatch
            if showMe.waitForExistence(timeout: 3) {
                showMe.tap(); sleep(2)
                let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
                for label in ["Allow Full Access", "Allow Access to All Photos", "Allow"] {
                    let b = springboard.buttons[label]
                    if b.waitForExistence(timeout: 2) { b.tap(); break }
                }
                sleep(4)
            }
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
        scrollTo(app.staticTexts["Since your last scan"].firstMatch, max: 8)
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
            shot("r07-papers-\(soft.replacingOccurrences(of: ".", with: "p"))-results")
            tab("Score")
            app.swipeUp(velocity: .slow)
            shot("r07-papers-\(soft.replacingOccurrences(of: ".", with: "p"))-score")
            tab("Tracker")
            shot("r07-papers-\(soft.replacingOccurrences(of: ".", with: "p"))-tracker")
        }
    }
}
