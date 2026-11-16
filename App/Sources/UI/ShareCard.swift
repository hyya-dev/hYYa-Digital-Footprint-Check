// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

/// A picture to send to friends and family. It carries **no values from this device**: no IDs,
/// dates, names, addresses or app names. Only the privacy score and each check's part of it.
struct ShareCardView: View {
    let overall: OverallScore

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("MY PRIVACY SCORE")
                        .font(.brand(.caption, .semibold)).tracking(1.4)
                        .foregroundStyle(Brand.sand)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(overall.value ?? 0)").font(.system(size: 56, weight: .bold))
                        Text("/ 100").font(.brand(.title3, .semibold)).foregroundStyle(Brand.textMuted)
                    }
                    .foregroundStyle(Brand.ink)
                    Text(overall.level?.title ?? "")
                        .font(.brand(.title3, .semibold))
                        .foregroundStyle(ScoreHomeView.tint(overall.level))
                }
                Spacer(minLength: 0)
                MascotArt().frame(width: 110, height: 110)
            }
            VStack(spacing: 0) {
                ForEach(AppTab.checks) { tab in
                    HStack {
                        Text(tab.title).font(.brand(.body)).foregroundStyle(Brand.ink)
                        Spacer()
                        Text(part(tab).map { "\($0)" } ?? "not done yet")
                            .font(.brand(.body, .semibold).monospacedDigit())
                            .foregroundStyle(part(tab) == nil ? Brand.textSubtle : Brand.ink)
                    }
                    .padding(.vertical, 10)
                    .overlay(alignment: .bottom) { Rectangle().fill(Brand.rule).frame(height: 0.5) }
                }
            }
            Text("Check yours with hYYa Digital Footprint Check. Free, open source, and nothing leaves your device.")
                .font(.brand(.footnote))
                .foregroundStyle(Brand.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(28)
        .frame(width: 400)
        .background(Brand.page)
        .overlay(RoundedRectangle(cornerRadius: 0).strokeBorder(Brand.rule, lineWidth: 1))
        .environment(\.colorScheme, .dark)
    }

    private func part(_ tab: AppTab) -> Int? {
        switch tab {
        case .footprint: overall.parts[.footprint]
        case .sensitive: overall.parts[.sensitive]
        case .tracker: overall.parts[.tracker]
        case .checkup: overall.parts[.checkup]
        case .home, .settings: nil
        }
    }
}

/// The share button on the Score page: renders the card to an image on the device and hands it
/// to the share sheet.
struct OverallShareButton: View {
    let overall: OverallScore
    /// The main button once every check is done; an outline button before that.
    var prominent = false
    var title: LocalizedStringKey = "Share my result"
    var message: String? = nil
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        if let image = render() {
            if prominent {
                link(image).buttonStyle(PrimaryCTAButtonStyle())
            } else {
                link(image).buttonStyle(GhostButtonStyle())
            }
        }
    }

    private func link(_ image: Image) -> some View {
        ShareLink(item: image, message: message.map { Text($0) }, preview: SharePreview("My privacy score", image: image)) {
            Label(title, systemImage: "square.and.arrow.up")
        }
    }

    @MainActor
    private func render() -> Image? {
        let renderer = ImageRenderer(content: ShareCardView(overall: overall))
        renderer.scale = displayScale
        #if os(iOS)
        guard let ui = renderer.uiImage else { return nil }
        return Image(uiImage: ui)
        #else
        guard let ns = renderer.nsImage else { return nil }
        return Image(nsImage: ns)
        #endif
    }
}
