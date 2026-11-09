// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import StoreKit
import SwiftUI

/// When to show Apple's standard rating prompt. Only at a good moment: right after the score went
/// up, or once the person has come back and scanned on at least two different days. Never on the
/// first scan, and at most once per app version (the system also caps it at three times a year).
enum RatingMoment {
    static let askedKey = "rating.askedVersion"
    static let minimumScans = 3

    static func shouldAsk(scoreDelta: Int?, scanDates: [Date], askedVersion: String?,
                          currentVersion: String, calendar: Calendar = .current) -> Bool {
        guard askedVersion != currentVersion, scanDates.count >= 2 else { return false }
        if let scoreDelta, scoreDelta > 0 { return true }
        let days = Set(scanDates.map { calendar.startOfDay(for: $0) })
        return scanDates.count >= minimumScans && days.count >= 2
    }

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }
}

/// Asks for a rating after a scan, when `RatingMoment` says the moment is right.
struct RatingPrompt: ViewModifier {
    @Environment(Scanner.self) private var scanner
    @Environment(HistoryStore.self) private var history
    @Environment(\.requestReview) private var requestReview
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(RatingMoment.askedKey) private var askedVersion = ""

    func body(content: Content) -> some View {
        content
            .onChange(of: history.latest?.id) { _, _ in
                guard !LaunchOptions.has("-sampleData"), scanner.phase == .done,
                      RatingMoment.shouldAsk(scoreDelta: scanner.comparison?.scoreDelta,
                                             scanDates: history.snapshots.map(\.date),
                                             askedVersion: askedVersion,
                                             currentVersion: RatingMoment.currentVersion) else { return }
                Task {
                    // Let the new score settle on screen first.
                    try? await Task.sleep(for: .seconds(2))
                    guard scenePhase == .active, scanner.phase == .done else { return }
                    askedVersion = RatingMoment.currentVersion
                    requestReview()
                }
            }
    }
}
