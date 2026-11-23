// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Testing
import Foundation
import SensitiveContentAnalysis
@testable import FootprintInspector

private struct FakeProvider: AgeSignalProvider {
    let applies: Bool
    func lawApplies() async -> Bool { applies }
}

@MainActor
struct AgeSignalTests {
    private let day: TimeInterval = 24 * 3600

    private func freshDefaults() -> (UserDefaults, String) {
        let name = "age-signal-tests-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return (d, name)
    }

    @Test func dueOnFirstLaunch() {
        #expect(AgeSignalSchedule.isDue(checkedOn: nil))
    }

    @Test func notDueWithinAYear() {
        let checked = AgeSignalSchedule.lastSignificantChange.addingTimeInterval(day)
        #expect(!AgeSignalSchedule.isDue(checkedOn: checked, now: checked.addingTimeInterval(200 * day)))
    }

    @Test func dueAfterAYear() {
        let checked = AgeSignalSchedule.lastSignificantChange.addingTimeInterval(day)
        #expect(AgeSignalSchedule.isDue(checkedOn: checked, now: checked.addingTimeInterval(366 * day)))
    }

    @Test func dueAfterASignificantChange() {
        let checked = AgeSignalSchedule.lastSignificantChange.addingTimeInterval(-day)
        #expect(AgeSignalSchedule.isDue(checkedOn: checked, now: checked.addingTimeInterval(2 * day)))
    }

    @Test func asksNothingWhereNoLawApplies() async {
        let (d, name) = freshDefaults()
        var asked = false
        await AgeSignal.runIfDue(provider: FakeProvider(applies: false), defaults: d, domain: name) { asked = true }
        #expect(!asked)
        #expect(d.object(forKey: AgeSignalSchedule.checkedOnKey) == nil)
    }

    @Test func asksOnceWhereALawApplies() async {
        let (d, name) = freshDefaults()
        var count = 0
        let now = Date()
        await AgeSignal.runIfDue(provider: FakeProvider(applies: true), defaults: d, domain: name, now: now) { count += 1 }
        await AgeSignal.runIfDue(provider: FakeProvider(applies: true), defaults: d, domain: name, now: now.addingTimeInterval(60)) { count += 1 }
        #expect(count == 1)
        // Only the date is kept, never the answer.
        #expect(d.dictionaryRepresentation().keys.filter { $0.hasPrefix("ageSignal") } == [AgeSignalSchedule.checkedOnKey])
    }

    @Test func aDeclinedOrFailedRequestChangesNothing() async {
        let (d, name) = freshDefaults()
        struct Declined: Error {}
        await AgeSignal.runIfDue(provider: FakeProvider(applies: true), defaults: d, domain: name) { throw Declined() }
        #expect(d.object(forKey: AgeSignalSchedule.checkedOnKey) != nil)
    }

    @Test func contentSafetyStates() throws {
        #expect(ContentSafety.state(.descriptiveInterventions) == .childOrTeen)
        #expect(ContentSafety.state(.simpleInterventions) == .adultWarning)
        #expect(ContentSafety.state(.disabled) == .off)
        #expect(ContentSafety.reading(for: .childOrTeen).severityOverride == .high)
        // A child's protection must never cost points or invite turning it off.
        let def = try #require(SignalCatalogue.definition(ContentSafety.id))
        #expect(def.isFYI)
        #expect(def.fix.level == .onlyApple)
        for text in [def.title, def.reveals, def.why, def.fix.summary, def.headline, def.brief,
                     ContentSafety.reading(for: .childOrTeen).note ?? ""] {
            #expect(!text.localizedCaseInsensitiveContains("nud"), "Sensitive wording: \(text)")
        }
        // The adult card is separate and never mentions children.
        let adult = try #require(SignalCatalogue.definition(ContentSafety.adultID))
        #expect(adult.isFYI)
        #expect(ContentSafety.reading(for: .adultWarning).id == ContentSafety.adultID)
        #expect(ContentSafety.reading(for: .childOrTeen).id == ContentSafety.id)
        #expect(ContentSafety.reading(for: .off).id == ContentSafety.id)
        for text in [adult.title, adult.reveals, adult.why, adult.fix.summary, adult.headline, adult.brief] {
            for word in ["child", "teen", "young", "kid"] {
                #expect(!text.localizedCaseInsensitiveContains(word), "Adult card mentions \(word): \(text)")
            }
        }
    }
}
