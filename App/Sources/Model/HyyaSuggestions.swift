// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// A hYYa app that genuinely helps with a finding, shown after the free fix.
struct HyyaSuggestion: Sendable {
    let appName: String
    /// One honest sentence on how it helps with this finding.
    let reason: String
    let url: URL
}

/// Which hYYa app goes with which finding. **Deliberately empty**: each pairing is decided case by case
/// case by case, when the time comes. Add an entry here and the suggestion appears on
/// that finding's detail page, below the free fix. Bring back the Settings switch
/// ("Suggest hYYa apps in fixes", key `settingKey`) with the first entry; it was removed while the
/// list is empty because it did nothing.
///
/// Rules: the free fix always comes first; label it "From the makers of this app"; never suggest an
/// app that doesn't truly fix that finding; no tracking of taps.
enum HyyaSuggestions {
    static let settingKey = "showHyyaSuggestions"

    /// Hidden for good once tapped or turned down: the suggestion is shown until then, never again after.
    static let seenKey = "hyyaSuggestionsSeen"

    /// Owner, 2026-11-14 (plan S1): proposed pairs, pending the owner's yes on the renders.
    /// Encrypted Folder genuinely fixes the Photos findings: what's kept there isn't in the photo library
    /// that apps with Photos access read. (Encrypted Notes was weighed for the clipboard finding and left
    /// out: copying out of a note still goes through the clipboard.)
    private static let folder = HyyaSuggestion(
        appName: "hYYa Encrypted Folder",
        reason: "Keep private photos and videos in an encrypted folder instead of your photo library. Apps you give Photos access can't see what's in it.",
        url: URL(string: "https://apps.apple.com/app/id6786135330")!)

    static let bySignal: [String: HyyaSuggestion] = [
        "photo-places": folder,
        "photo-home-work": folder,
        "photo-library": folder,
    ]

    static func suggestion(for signalID: String) -> HyyaSuggestion? { bySignal[signalID] }
}
