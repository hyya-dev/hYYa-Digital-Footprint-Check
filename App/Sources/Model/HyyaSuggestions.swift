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
    /// The app's own icon, only when its team approved showing it (asset name).
    var icon: String? = nil
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

    /// Encrypted Folder on the Photos findings: text, name, link and icon confirmed by its own team
    /// (2026-11-14). Their rules: it's an "encrypted folder", never a vault, safe or locker, and it doesn't
    /// "hide" photos; importing keeps the original in Photos until the person removes it, so the sentence
    /// says to remove them; no sync, no price, no "nothing leaves your device". Needs macOS 26 on Apple
    /// silicon, so it's never shown on an Intel Mac. (Encrypted Notes was weighed for the clipboard finding
    /// and left out: copying out of a note still goes through the clipboard.)
    private static let folder = HyyaSuggestion(
        appName: "hYYa Encrypted Folder",
        reason: "Move private photos and videos into an encrypted folder, then remove them from your photo library. Apps you give Photos access can't see them there.",
        url: URL(string: "https://apps.apple.com/app/id6786135330")!,
        icon: "EncryptedFolderIcon")

    static let bySignal: [String: HyyaSuggestion] = [
        "photo-places": folder,
        "photo-home-work": folder,
        "photo-library": folder,
    ]

    /// Apps whose own team has confirmed the name, wording, link and any logo shown here (owner's rule,
    /// 2026-11-14: anything about another hYYa app is confirmed by that app first). Until an app is listed,
    /// its suggestion never shows. Encrypted Folder: confirmed 2026-11-14.
    static let confirmedApps: Set<String> = {
        #if os(macOS) && arch(x86_64)
        return []          // Encrypted Folder runs only on Apple silicon Macs
        #else
        return ["hYYa Encrypted Folder"]
        #endif
    }()

    static func suggestion(for signalID: String) -> HyyaSuggestion? {
        bySignal[signalID].flatMap { confirmedApps.contains($0.appName) ? $0 : nil }
    }

    /// The Settings switch shows only when some suggestion can appear.
    static var anyLive: Bool { bySignal.values.contains { confirmedApps.contains($0.appName) } }
}
