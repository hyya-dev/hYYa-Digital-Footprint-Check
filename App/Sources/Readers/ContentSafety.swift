// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import SensitiveContentAnalysis

/// Apple's Communication Safety and Sensitive Content Warning settings, which any app holding the content-analysis capability can read
/// with no prompt. Its three states tell apart a child's or teen's device (Communication Safety in
/// Screen Time), an adult who turned on Sensitive Content Warning, and neither.
///
/// The adult setting is shown on its own card (``adultDefinition``).
///
/// Read for display only. Never stored, sent or used to allow or block anything.
enum ContentSafety {
    static let id = "content-safety"
    /// The adult's own setting gets its own card, so its wording never sits beside a child's (owner, 2026-11-23).
    /// A device only ever shows one of the two.
    static let adultID = "content-warning"

    enum State: Equatable { case off, adultWarning, childOrTeen }

    static func state(_ policy: SCSensitivityAnalysisPolicy) -> State {
        switch policy {
        case .descriptiveInterventions: .childOrTeen
        case .simpleInterventions: .adultWarning
        default: .off
        }
    }

    static func reading(for state: State) -> SignalReading {
        switch state {
        case .childOrTeen:
            SignalReading(id: id, value: "Set up for a child or teen", severityOverride: .high,
                          note: "Apps can tell, without asking, that a young person uses this device. Keep the protection on: it's doing its job.")
        case .adultWarning:
            SignalReading(id: adultID, value: "On", severityOverride: .low)
        case .off:
            SignalReading(id: id, value: "Not set up", severityOverride: .low)
        }
    }

    static func read() -> SignalReading {
        // Renders for the owner's review (Debug only): `-previewContentSafety child|adult`.
        switch LaunchOptions.value(after: "-previewContentSafety") {
        case "child": return reading(for: .childOrTeen)
        case "adult": return reading(for: .adultWarning)
        default:
            #if targetEnvironment(simulator)
            // The Simulator has no real Screen Time and reports the child setting on every device
            // (checked 2026-11-23: raw value 2 on iOS 27.2). A signed Mac reads it correctly.
            return reading(for: .off)
            #else
            return reading(for: state(SCSensitivityAnalyzer().analysisPolicy))
            #endif
        }
    }

    static let definition = SignalDefinition(
        id: id, section: definitionSection, title: "Child or teen safety settings",
        reveals: "Whether this device is set up for a child or teen with Communication Safety, or whether an adult has turned on Sensitive Content Warning. An app can tell a young person's device apart without asking.",
        why: "So apps where people share photos and videos can offer the same protection as Apple's own apps.",
        persistence: .untilYouChangeIt, severity: .medium,
        fix: .leaveIt("Keep these protections on. The only way to hide them from apps is to turn them off, which isn't worth it. Only Apple could close this."))

    static let adultDefinition = SignalDefinition(
        id: adultID, section: definitionSection, title: "Sensitive Content Warning",
        reveals: "Whether you've turned on Sensitive Content Warning, which blurs photos and videos that may contain nudity before you see them.",
        why: "So apps where people share photos and videos can blur them the way Apple's own apps do.",
        persistence: .untilYouChangeIt, severity: .low,
        fix: .leaveIt("Nothing to change. It's your choice, and it tells apps very little."))

    private static var definitionSection: SignalSection {
        #if os(macOS)
        .accountAndApp
        #else
        .security
        #endif
    }
}
