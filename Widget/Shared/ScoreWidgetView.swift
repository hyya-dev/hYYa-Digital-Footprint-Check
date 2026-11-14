// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import WidgetKit

// The widget's face. Shared with the app, so the app's "add the widget" card shows the real thing.

/// The Quiet Noir ground, or its warm paper version, following the system's light or dark mode.
private struct Palette {
    let base, glowTop, glowBottom, ink, muted, accent: Color

    init(_ scheme: ColorScheme) {
        func c(_ hex: UInt32) -> Color {
            Color(red: Double(hex >> 16 & 255) / 255, green: Double(hex >> 8 & 255) / 255, blue: Double(hex & 255) / 255)
        }
        if scheme == .dark {
            base = c(0x000000); glowTop = c(0x241C14); glowBottom = c(0x16100D)
            ink = c(0xF5F5F7); muted = c(0xA1A1A8); accent = c(0xD2AE88)
        } else {
            base = c(0xFAF7F2); glowTop = c(0xEEDECA); glowBottom = c(0xF3E9DD)
            ink = c(0x1C1814); muted = c(0x685E54); accent = c(0x7A5C40)
        }
    }
}

struct ScoreWidgetView: View {
    let score: WidgetScore?
    /// The app's pictures of the widget pick a size; on the home screen the system's size is used.
    var size: WidgetFamily? = nil
    @Environment(\.widgetFamily) private var systemFamily
    private var family: WidgetFamily { size ?? systemFamily }
    @Environment(\.colorScheme) private var scheme
    /// Tinted Home Screens, the Mac desktop behind a window, StandBy at night: the system draws the widget
    /// in one tint, so fixed colours and glows can vanish. There it uses the system's own text styles.
    @Environment(\.widgetRenderingMode) private var mode
    private var fullColor: Bool { mode == .fullColor }

    private var palette: Palette { Palette(scheme) }
    private var ink: AnyShapeStyle { fullColor ? AnyShapeStyle(palette.ink) : AnyShapeStyle(.primary) }
    private var muted: AnyShapeStyle { fullColor ? AnyShapeStyle(palette.muted) : AnyShapeStyle(.secondary) }
    private var accent: AnyShapeStyle { fullColor ? AnyShapeStyle(palette.accent) : AnyShapeStyle(.secondary) }

    var body: some View {
        Group {
            if family == .systemMedium { medium } else { small }
        }
        // Hidden while locked on surfaces such as StandBy.
        .privacySensitive()
        .containerBackground(for: .widget) {
            ZStack {
                palette.base
                if fullColor {
                    RadialGradient(colors: [palette.glowTop, palette.glowTop.opacity(0)], center: .top, startRadius: 0, endRadius: 150)
                    RadialGradient(colors: [palette.glowBottom, palette.glowBottom.opacity(0)], center: .bottomTrailing, startRadius: 0, endRadius: 130)
                }
            }
        }
    }

    /// Full colour only: a tinted mascot turns into a flat blob.
    @ViewBuilder private func mascot(height: CGFloat) -> some View {
        if fullColor { MascotArt().frame(height: height).accessibilityHidden(true) }
    }

    private var label: some View {
        Text("PRIVACY SCORE").font(.system(size: 11, weight: .semibold))
    }

    private var small: some View {
        ZStack(alignment: .bottomTrailing) {
            mascot(height: 60).padding(5)
            VStack(alignment: .leading, spacing: 0) {
                label.foregroundStyle(accent)
                if let score {
                    Text("\(score.score)").font(.system(size: 44, weight: .bold)).foregroundStyle(ink).widgetAccentable()
                        .minimumScaleFactor(0.7).lineLimit(1)
                    Text("out of 100").font(.system(size: 11, weight: .medium)).foregroundStyle(muted)
                    Spacer(minLength: 0)
                    Text("Last check").font(.system(size: 11, weight: .medium)).foregroundStyle(muted)
                    // Two lines, so a long date and time stays clear of the mascot.
                    Group {
                        Text(score.checkedAt, format: .dateTime.day().month(.abbreviated))
                        Text(score.checkedAt, format: .dateTime.hour().minute())
                    }
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(ink)
                } else {
                    Text("Not\nchecked\nyet").font(.system(size: 20, weight: .bold)).foregroundStyle(ink).padding(.top, 6)
                    Spacer(minLength: 0)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var medium: some View {
        ZStack(alignment: .trailing) {
            mascot(height: 132).padding(.trailing, 14)
            VStack(alignment: .leading, spacing: 0) {
                Text("hYYa Digital Footprint Check").font(.system(size: 12, weight: .semibold)).foregroundStyle(accent)
                label.foregroundStyle(muted).padding(.top, 8)
                if let score {
                    HStack(alignment: .lastTextBaseline, spacing: 8) {
                        Text("\(score.score)").font(.system(size: 52, weight: .bold)).foregroundStyle(ink).widgetAccentable()
                        Text("out of 100").font(.system(size: 12, weight: .medium)).foregroundStyle(muted)
                    }
                    Spacer(minLength: 0)
                    Text("Last check").font(.system(size: 11, weight: .medium)).foregroundStyle(muted)
                    Group {
                        Text(score.checkedAt, format: .dateTime.day().month(.abbreviated).year())
                        Text(score.checkedAt, format: .dateTime.hour().minute())
                    }
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(ink)
                } else {
                    Text("Not checked yet").font(.system(size: 22, weight: .bold)).foregroundStyle(ink).padding(.top, 6)
                    Spacer(minLength: 0)
                    Text("Open the app to run your first check").font(.system(size: 11, weight: .medium)).foregroundStyle(muted)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}
