// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Testing
@testable import FootprintInspector

struct RatingMomentTests {
    let day: TimeInterval = 86_400
    let start = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func neverOnTheFirstScan() {
        #expect(!RatingMoment.shouldAsk(scoreDelta: nil, scanDates: [start], askedVersion: nil, currentVersion: "1.0.7"))
    }

    @Test func asksWhenTheScoreGoesUp() {
        #expect(RatingMoment.shouldAsk(scoreDelta: 4, scanDates: [start, start + 60], askedVersion: nil, currentVersion: "1.0.7"))
        #expect(!RatingMoment.shouldAsk(scoreDelta: 0, scanDates: [start, start + 60], askedVersion: nil, currentVersion: "1.0.7"))
        #expect(!RatingMoment.shouldAsk(scoreDelta: -3, scanDates: [start, start + 60], askedVersion: nil, currentVersion: "1.0.7"))
    }

    @Test func asksWhenTheyComeBackOnAnotherDay() {
        let sameDay = [start, start + 60, start + 120]
        #expect(!RatingMoment.shouldAsk(scoreDelta: 0, scanDates: sameDay, askedVersion: nil, currentVersion: "1.0.7"))
        let twoDays = [start, start + 60, start + 2 * day]
        #expect(RatingMoment.shouldAsk(scoreDelta: 0, scanDates: twoDays, askedVersion: nil, currentVersion: "1.0.7"))
    }

    @Test func onlyOncePerVersion() {
        let dates = [start, start + 2 * day, start + 4 * day]
        #expect(!RatingMoment.shouldAsk(scoreDelta: 5, scanDates: dates, askedVersion: "1.0.7", currentVersion: "1.0.7"))
        #expect(RatingMoment.shouldAsk(scoreDelta: 5, scanDates: dates, askedVersion: "1.0.6", currentVersion: "1.0.7"))
    }
}
