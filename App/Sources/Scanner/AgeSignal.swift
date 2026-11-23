// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import SwiftUI
#if canImport(DeclaredAgeRange)
import DeclaredAgeRange
#endif

/// Age-assurance laws (California's from 2027, among others) ask every app to request the age
/// range the system holds. Footprint changes nothing with it: no feature depends on age.
///
/// - A silent check first. Only where Apple says a law applies is anything asked, through Apple's
///   own sheet.
/// - Asked at the first launch after install (or of the update that added this), after a
///   significant change to the app, and otherwise at most once a year.
/// - The answer is never stored, logged, sent or shown. The device keeps only the date it asked.
enum AgeSignalSchedule {
    static let checkedOnKey = "ageSignal.checkedOn"
    static let interval: TimeInterval = 365 * 24 * 3600
    /// Raise this when an update changes the app in a way the law calls significant (age rating,
    /// features, data practices). Asks everyone again once.
    static let lastSignificantChange = Date(timeIntervalSince1970: 1_795_392_000) // 2026-11-23

    static func isDue(checkedOn: Date?, now: Date = .now) -> Bool {
        guard let checkedOn else { return true }
        if checkedOn < lastSignificantChange { return true }
        return now.timeIntervalSince(checkedOn) >= interval || now < checkedOn
    }
}

/// The silent check and the request, behind a protocol so tests use a fake.
protocol AgeSignalProvider: Sendable {
    /// Whether Apple says an age-assurance law applies to this person. Shows nothing.
    func lawApplies() async -> Bool
}

struct SystemAgeSignalProvider: AgeSignalProvider {
    func lawApplies() async -> Bool {
        #if canImport(DeclaredAgeRange)
        if #available(iOS 26.4, macOS 26.4, *) {
            let required = (try? await AgeRangeService.shared.requiredRegulatoryFeatures) ?? []
            return required.contains(.declaredAgeRangeRequired)
        }
        if #available(iOS 26.2, macOS 26.2, *) {
            return (try? await AgeRangeService.shared.isEligibleForAgeFeatures) ?? false
        }
        #endif
        // iOS and macOS 26.0–26.1 have neither check; there the system offers no signal.
        return false
    }
}

@MainActor
enum AgeSignal {
    /// Runs the schedule: silent check, then Apple's request where due. Every outcome is accepted
    /// and nothing changes; the answer goes out of scope unread.
    static func runIfDue(provider: AgeSignalProvider = SystemAgeSignalProvider(),
                         defaults: UserDefaults = .standard,
                         domain: String? = Bundle.main.bundleIdentifier,
                         now: Date = .now,
                         request: () async throws -> Void) async {
        // The app's own saved domain, not launch arguments, which UserDefaults would otherwise let
        // any local program use to skip the request on a Mac.
        let checkedOn = domain.flatMap(defaults.persistentDomain(forName:))?[AgeSignalSchedule.checkedOnKey] as? Date
        guard AgeSignalSchedule.isDue(checkedOn: checkedOn, now: now) else { return }
        guard await provider.lawApplies() else { return }
        defaults.set(now, forKey: AgeSignalSchedule.checkedOnKey)
        try? await request()
    }
}

/// Asks once the main screen is up, never over the integrity screen (it sits inside the gate).
struct AgeSignalOnLaunch: ViewModifier {
    #if canImport(DeclaredAgeRange)
    @Environment(\.requestAgeRange) private var requestAgeRange
    #endif

    func body(content: Content) -> some View {
        content.task {
            guard !LaunchOptions.has("-sampleData") else { return }
            #if canImport(DeclaredAgeRange)
            await AgeSignal.runIfDue {
                // 18 is the only gate Footprint could ever need, and it uses none.
                _ = try await requestAgeRange(ageGates: 18)
            }
            #endif
        }
    }
}
