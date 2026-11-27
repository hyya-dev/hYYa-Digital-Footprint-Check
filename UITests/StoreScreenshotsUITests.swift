// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import XCTest

/// Captures the raw screens for the App Store slides. Run it on a Simulator (never a real phone:
/// a real device's values, such as its vendor ID, must not end up in public screenshots).
///
///   xcodebuild test -scheme "hYYa Digital Footprint Check UITests" \
///     -only-testing:hYYaFootprintInspectorUITests/StoreScreenshotsUITests \
///     -destination "platform=iOS Simulator,name=iPhone 17 Pro Max" -resultBundlePath …
///
/// Each screen is attached as `store-NN-name`. `scripts/make-store-slides.py` turns them into slides.
final class StoreScreenshotsUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        // Made-up values only: never a real device's, and the Tracker shows its sample report.
        app.launchArguments = ["-sampleData"]
    }

    private func shot(_ name: String) {
        sleep(1)
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    /// A store shot of a screen that has finished: it fails the run rather than photograph a
    /// loading screen or the wrong page, which is how 1.0.4's blank slides got through.
    private func shot(_ name: String, showing element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: 30), "\(name): the screen never finished")
        XCTAssertFalse(app.activityIndicators.firstMatch.exists, "\(name): still loading")
        shot(name)
    }

    private func tap(_ label: String, timeout: TimeInterval = 8) {
        let el = app.buttons[label].firstMatch
        if el.waitForExistence(timeout: timeout) {
            el.tap()
        } else {
            let alt = app.staticTexts[label].firstMatch
            if alt.waitForExistence(timeout: 2) { alt.tap() }
        }
    }

    /// Tabs are a bottom tab bar on iPhone and a floating bar at the top on iPad.
    private func tab(_ name: String) {
        let bar = app.tabBars.buttons[name]
        if bar.exists { bar.tap() } else { app.buttons[name].firstMatch.tap() }
    }

    /// Back: in the top bar on most devices, in the side strip on a folded iPhone Duo.
    private func back() {
        let bar = app.navigationBars.buttons.element(boundBy: 0)
        if bar.exists { bar.tap() } else { app.buttons["BackButton"].firstMatch.tap() }
    }

    private func scrollTo(_ element: XCUIElement, max: Int = 10) {
        var n = 0
        while !element.isHittable && n < max { app.swipeUp(velocity: .slow); n += 1 }
    }

    /// The Settings screen from top to bottom, attached as `settings-1…`, for design review.
    /// Candidate screens for a stronger slide, attached as `cand-…`. Grants permissions when asked.
    func testCaptureCandidates() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        app.launch()
        sleep(2)
        tab("Footprint"); tap("Start with check 1")
        XCTAssertTrue(app.buttons["Scan again"].waitForExistence(timeout: 20))
        for group in ["Remembered after deleting", "Location", "Photos", "Contacts", "Web fingerprint", "Account and App Store"] {
            app.swipeDown(velocity: .fast); app.swipeDown(velocity: .fast)
            let row = app.buttons.containing(NSPredicate(format: "label BEGINSWITH %@", group)).firstMatch
            scrollTo(row, max: 16)
            guard row.exists else { continue }
            row.tap()
            sleep(1)
            let show = app.buttons["Show me"].firstMatch
            if show.waitForExistence(timeout: 2) {
                show.tap()
                for label in ["Allow While Using App", "Allow Full Access", "Allow", "Continue", "OK"] {
                    let b = springboard.buttons[label]
                    if b.waitForExistence(timeout: 3) { b.tap(); sleep(1) }
                }
                sleep(4)
            }
            shot("cand-\(group)")
            app.swipeUp(velocity: .slow)
            shot("cand-\(group)-2")
            back()
            sleep(1)
        }
    }

    /// Screens changed in the plain-language pass, attached as `review-…`.
    func testCaptureReview() {
        app.launch()
        sleep(2)
        tab("Footprint"); tap("Start with check 1")
        XCTAssertTrue(app.buttons["Scan again"].waitForExistence(timeout: 20))
        for group in ["Device identity", "Motion sensors", "Graphics and mobile network"] {
            app.swipeDown(velocity: .fast); app.swipeDown(velocity: .fast)
            let row = app.buttons.containing(NSPredicate(format: "label BEGINSWITH %@", group)).firstMatch
            scrollTo(row, max: 16)
            guard row.exists else { continue }
            row.tap(); sleep(1)
            shot("review-\(group)")
            back(); sleep(1)
        }
        tab("Sensitive apps"); sleep(1)
        app.swipeUp(velocity: .fast); app.swipeUp(velocity: .fast); sleep(1)
        shot("review-sensitive-bottom")
        app.buttons.containing(NSPredicate(format: "label BEGINSWITH 'Check'")).firstMatch.tap()
        sleep(2)
        app.swipeDown(velocity: .fast); app.swipeDown(velocity: .fast); sleep(1)
        shot("review-sensitive-result")
    }

    /// Product page test version B (score rise): the Footprint page after a made-up earlier scan 12
    /// points lower (`-previewRise`), with "Since your last scan" in view. Attached as `ppo-b-rise`.
    func testCapturePPORise() {
        app.launchArguments += ["-previewRise"]
        app.launch()
        sleep(2)
        tab("Footprint"); tap("Start with check 1")
        XCTAssertTrue(app.buttons["Scan again"].waitForExistence(timeout: 20))
        sleep(2)
        // Exactly as far as the page's own header ("Check 1 · Footprint", "N things you can fix"), which then
        // sits just under the status bar with the fixes and "Since your last scan" below it.
        let header = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'things you can fix' OR label CONTAINS[c] 'thing you can fix'")).firstMatch
        XCTAssertTrue(header.waitForExistence(timeout: 10), "The fixes header isn't on the page")
        let win = app.windows.firstMatch.frame
        let lift = header.frame.minY - win.minY - 120
        if lift > 10 {
            let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
            from.press(forDuration: 0.1, thenDragTo: from.withOffset(CGVector(dx: 0, dy: -lift)), withVelocity: 300, thenHoldForDuration: 0.5)
            sleep(1)
        }
        // Narrow screens (the folded Duo): the whole rise card matters more than the header.
        let share = app.buttons["Share your progress"]
        if share.exists && share.frame.maxY > win.maxY - 70 {
            let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.8))
            from.press(forDuration: 0.1, thenDragTo: from.withOffset(CGVector(dx: 0, dy: -(share.frame.maxY - win.maxY + 90))),
                       withVelocity: 300, thenHoldForDuration: 0.5)
            sleep(1)
        }
        shot("ppo-b-rise", showing: app.buttons["Share your progress"])
    }

    /// Product page test version A's small device: the Sensitive apps result with three made-up finds
    /// (`-previewSensitive`), names still hidden as in the app. Attached as `ppo-a-sensitive`.
    func testCapturePPOSensitive() {
        app.launchArguments += ["-previewSensitive", "-startTab", "sensitive", "-sensitiveCategories", "dating,faith,health,money"]
        app.launch()
        sleep(2)
        let check = app.buttons.containing(NSPredicate(format: "label BEGINSWITH 'Check '")).firstMatch
        scrollTo(check, max: 6)
        XCTAssertTrue(check.exists, "The Check button isn't on the page")
        check.tap()
        sleep(2)
        // The result card: the ring, "3 apps could reveal you" and the hidden names, under the status bar.
        let heading = app.staticTexts["3 apps could reveal you"].firstMatch
        XCTAssertTrue(heading.waitForExistence(timeout: 10), "The result never showed")
        let win = app.windows.firstMatch.frame
        let show = app.buttons["Show the apps"].firstMatch
        if show.exists && show.frame.maxY > win.maxY - 110 {
            let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.8))
            from.press(forDuration: 0.1, thenDragTo: from.withOffset(CGVector(dx: 0, dy: -(show.frame.maxY - win.maxY + 140))),
                       withVelocity: 300, thenHoldForDuration: 0.5)
            sleep(1)
        }
        shot("ppo-a-sensitive", showing: show)
    }

    func testCaptureSettings() {
        app.launch()
        sleep(2)
        tab("Settings")
        shot("settings-1")
        for i in 2...4 { app.swipeUp(velocity: .slow); shot("settings-\(i)") }
    }

    func testCaptureStoreScreens() { captureStoreScreens() }

    /// The App Store preview: a calm walk through the four checks, recorded with
    /// `simctl io recordVideo` while it runs (sample data only). About 30 seconds.
    func testPreviewTour() {
        app.launchArguments += ["-sensitiveCategories", "dating,health,circumvention"]
        app.launch()
        sleep(3)                                                    // the first page
        tab("Footprint"); tap("Start with check 1")
        _ = app.buttons["Scan again"].waitForExistence(timeout: 20)
        sleep(3)                                                    // the privacy score
        app.swipeUp(velocity: .slow); sleep(1)
        let clue = app.buttons.containing(NSPredicate(format: "label CONTAINS 'last restart'")).firstMatch
        scrollTo(clue, max: 8)
        if clue.exists { clue.tap(); sleep(3); back(); sleep(1) }  // one finding, in plain words
        tab("Sensitive apps"); sleep(2)
        let check = app.buttons.containing(NSPredicate(format: "label BEGINSWITH 'Check '")).firstMatch
        scrollTo(check, max: 6)
        if check.exists { check.tap() }
        sleep(3)                                                    // which apps give you away
        tab("Tracker"); sleep(3)                                    // what apps really did
        app.swipeUp(velocity: .slow); sleep(2)
        tab("Check-up"); sleep(3)                                   // the guided check-up
        tab("Footprint"); sleep(3)                                  // back to the score
    }

    /// The scripted App Store preview video (Marketing, 2026-11-20), recorded with
    /// `xcrun simctl io <device> recordVideo` while it runs: open, check 1, the score, one finding and
    /// its details, then "Fix them with me" with its Settings steps. Sample data only. Every pause
    /// is here, so a retake is a re-run. Trimmed to 15–30 s afterwards.
    func testPreviewVideo() {
        app.launchArguments += ["-firstRun"]
        app.launch()
        sleep(3)                                                        // the first page (the lead-in is trimmed)
        tab("Footprint"); sleep(1)
        tap("Start with check 1")
        XCTAssertTrue(app.buttons["Scan again"].waitForExistence(timeout: 20))
        sleep(2)                                                        // the score and what to fix
        let clue = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Rename your headphones'")).firstMatch
        XCTAssertTrue(clue.waitForExistence(timeout: 5), "The headphones finding isn't on the page")
        clue.tap(); sleep(2)                                            // one finding, in plain words
        app.swipeUp(velocity: 500); sleep(1)
        let details = app.buttons.containing(NSPredicate(format: "label BEGINSWITH 'All the details'")).firstMatch
        if details.waitForExistence(timeout: 2) && details.isHittable {
            details.tap(); sleep(2)                                     // what an app reads
        }
        back(); sleep(1)
        let fix = app.buttons["Fix them with me"]
        XCTAssertTrue(fix.waitForExistence(timeout: 5), "Fix them with me isn't on the page")
        fix.tap(); sleep(3)                                             // fix 1: the steps
        app.buttons["Done, next"].firstMatch.tap(); sleep(4)            // fix 2: where in Settings, and the score it could reach
    }

    /// The same screens sideways, for the iPhone Duo's landscape slides (its controls sit on the
    /// side). Captures come out rotated; `scripts/make-landscape-slides.py` turns them upright.
    func testCaptureStoreScreensLandscape() { captureStoreScreens(landscape: true) }

    private func captureStoreScreens(landscape: Bool = false) {
        // The first page as a new user sees it, with no check done (store plan M3, slide 7).
        app.launchArguments += ["-firstRun"]
        app.launch()
        if landscape { XCUIDevice.shared.orientation = .landscapeLeft }
        sleep(2)
        shot("store-01-home")
        app.terminate()
        app.launchArguments.removeAll { $0 == "-firstRun" }
        app.launch()
        if landscape { XCUIDevice.shared.orientation = .landscapeLeft }
        sleep(2)

        // Checks 2 and 3 first, so the results show one privacy score built from three checks.
        tab("Sensitive apps")
        sleep(1)
        for name in ["Dating and LGBTQ+", "Health and fertility", "VPN, Tor and censorship tools"] {
            let row = app.buttons.containing(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
            scrollTo(row, max: 4)
            if row.exists && !row.isSelected { row.tap() }
        }
        app.swipeDown(velocity: .fast)
        sleep(1)
        shot("store-05-sensitive", showing: app.staticTexts["Which apps could reveal you?"])
        let check = app.buttons.containing(NSPredicate(format: "label BEGINSWITH 'Check '")).firstMatch
        scrollTo(check, max: 6)
        if check.exists { check.tap(); sleep(1) }

        tab("Tracker")
        sleep(2)
        shot("store-08-tracker", showing: app.staticTexts["Here's what they did"])

        tab("Check-up")
        sleep(1)
        shot("store-06-checkup", showing: app.staticTexts["Start with Safety Check"])

        tab("Footprint")
        tab("Footprint"); tap("Start with check 1")
        XCTAssertTrue(app.buttons["Scan again"].waitForExistence(timeout: 20))
        sleep(2)
        shot("store-03-footprint", showing: app.buttons["Scan again"])
        // The Score page with all the checks done so far, the app's first page.
        tab("Score")
        sleep(2)
        shot("store-02-results", showing: app.buttons["Share my result"])
        tab("Footprint")
        XCTAssertTrue(app.buttons["Scan again"].waitForExistence(timeout: 20))

        // A different finding from the fix slide's (store plan M2): the headphones' name.
        let clue = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Rename your headphones'")).firstMatch
        scrollTo(clue, max: 14)
        XCTAssertTrue(clue.exists, "The headphones finding isn't on the page")
        clue.tap()
        shot("store-04-finding", showing: app.staticTexts["Apps can see your headphones' name"])
        back()
        sleep(1)
        app.swipeDown(velocity: .fast); app.swipeDown(velocity: .fast)

        // The score explained, with "Fix them with me", then the first fix step.
        let fix = app.buttons["Fix them with me"]
        scrollTo(fix, max: 6)
        XCTAssertTrue(fix.exists, "Fix them with me isn't on the page")
        if fix.exists {
            app.swipeUp(velocity: .slow)
            sleep(1)
            shot("store-10-score")
            fix.tap()
            sleep(3) // let the sheet finish rising before the shot
            shot("store-09-fix", showing: app.buttons["Done, next"])
            app.buttons["Close"].firstMatch.tap()
        }

        tab("Footprint")
        let board = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Privacy scoreboard'")).firstMatch
        scrollTo(board, max: 14)
        if board.exists { board.tap(); sleep(2); shot("store-07-scoreboard") }
    }
}
