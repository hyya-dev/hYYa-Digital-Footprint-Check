// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

/// The only screen a store build shows when `DeviceIntegrity` finds a problem: exactly what was
/// found, why the app won't run, and numbered steps to get it running again. Calm, no alarm.
struct IntegrityBlockView: View {
    let finding: IntegrityFinding

    /// What was found, naming it where the check knows it.
    private var found: String {
        let thing = finding.detail.map { " (\($0))" } ?? ""
        return switch finding.problem {
        case .modifiedSystem:
            "This device is jailbroken\(thing): its built-in protections were removed, so other apps could read or change what this app shows."
        case .hookingTool:
            "A tool that changes how apps run is loaded into this app\(thing). It could change what the app shows you."
        case .debugger:
            "A computer is debugging this app, for example from Xcode."
        case .modifiedApp:
            "This copy of the app was changed or re-signed after it left the App Store, so it isn't the genuine app."
        }
    }

    /// Exactly what to do, step by step.
    private var steps: [String] {
        #if os(macOS)
        switch finding.problem {
        case .modifiedSystem, .hookingTool:
            ["Quit the app (⌘Q).",
             "Remove the tool that adds code to other apps\(finding.detail.map { " (\($0))" } ?? ""), or turn it off, then restart the Mac.",
             "Open the app again."]
        case .debugger:
            ["On the computer that's debugging the app, stop the debugging session.",
             "Quit the app (⌘Q) and open it again."]
        case .modifiedApp:
            ["Quit the app (⌘Q) and move it to the Trash.",
             "Install hYYa Digital Footprint Check from the Mac App Store."]
        }
        #else
        switch finding.problem {
        case .modifiedSystem:
            ["Back up this device to iCloud, or to a computer.",
             "Connect it to a computer. On a Mac, open Finder; on Windows, open the Apple Devices app. Select the device and click Restore. This puts back the standard system.",
             "Restore your backup when asked, then install the app from the App Store."]
        case .hookingTool:
            ["Delete this copy: touch and hold the app's icon, tap Remove App, then Delete App.",
             "Install hYYa Digital Footprint Check from the App Store.",
             "If this screen comes back, the device is jailbroken: restore it with a computer (Finder on a Mac, Apple Devices on Windows)."]
        case .debugger:
            ["On the computer that's debugging the app, stop the debugging session and unplug the cable.",
             "Close the app: open the app switcher and swipe the app away.",
             "Open the app again."]
        case .modifiedApp:
            ["Delete this copy: touch and hold the app's icon, tap Remove App, then Delete App.",
             "Install hYYa Digital Footprint Check from the App Store."]
        }
        #endif
    }

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width > geo.size.height
            Group {
                if wide {
                    // Sideways: the detective beside the words, so everything fits on one screen.
                    HStack(alignment: .center, spacing: 28) {
                        MascotArt()
                            .frame(width: min(geo.size.width * 0.24, 240), height: geo.size.height * 0.6)
                            .accessibilityHidden(true)
                        fitted
                    }
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        MascotArt()
                            .frame(maxWidth: .infinity)
                            .frame(height: min(120, geo.size.height * 0.16))
                            .accessibilityHidden(true)
                        fitted
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .frame(maxWidth: wide ? 960 : 560)
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .background(Color.black.ignoresSafeArea())
    }

    /// The words at the largest size that fits the space left, never cut off. A scrolling copy is
    /// the last resort, for the very largest accessibility text sizes.
    private var fitted: some View {
        ViewThatFits(in: .vertical) {
            words(title: .title2, body: .body, gap: 16)
            words(title: .title3, body: .callout, gap: 12)
            words(title: .headline, body: .footnote, gap: 8)
            words(title: .subheadline, body: .caption, gap: 6)
            ScrollView { words(title: .subheadline, body: .caption, gap: 6) }
        }
    }

    private func words(title: Font, body: Font, gap: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: gap) {
            Brand.eyebrow("hYYa Digital Footprint Check")
            Text("For security reasons, the app can't run on this device")
                .font(title.weight(.bold))
                .foregroundStyle(Brand.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(found)
                .font(body)
                .foregroundStyle(Brand.textMuted)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: gap * 0.6) {
                Text("HOW TO FIX IT")
                    .font(.caption.weight(.semibold)).tracking(1.2)
                    .foregroundStyle(Brand.sand)
                ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(i + 1).")
                            .font(body.weight(.semibold).monospacedDigit())
                            .foregroundStyle(Brand.sand)
                        Text(step)
                            .font(body)
                            .foregroundStyle(Brand.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(gap < 16 ? 10 : 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Brand.surface, in: .rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Brand.border, lineWidth: 1))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
