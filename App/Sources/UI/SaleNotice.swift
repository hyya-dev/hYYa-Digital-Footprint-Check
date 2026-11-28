// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
#if os(iOS)
import StoreKit
#else
import AppKit
#endif

/// "Other hYYa apps are on sale" (owner, 2026-11-23: offline, App Store only).
///
/// The sale is built into the app, so nothing is fetched and nothing leaves the device. Footprint
/// itself is free and discounts nothing. Shown once per sale: as a card on the Score page for people
/// who have used the app, as a short toast on a new install's first open. Never on Android (Google
/// Play counts it as an ad), never a notification.
enum SaleNotice {
    struct App: Identifiable, Sendable {
        let id: String
        let name: String
        let appStoreID: String
        let icon: String
    }

    struct Sale: Sendable {
        let id: String
        let start: Date
        let end: Date
        let title: String
        let body: String
        let apps: [App]
    }

    /// From Marketing's owner-approved sale file (hyya.com/promo/sales.json, read 2026-11-23).
    static let current = Sale(
        id: "seasonal-2026",
        start: Date(timeIntervalSince1970: 1_795_478_400), // 2026-11-24T00:00:00Z
        end: Date(timeIntervalSince1970: 1_798_761_599),   // 2026-12-31T23:59:59Z
        title: "Seasonal sale on hYYa apps",
        body: "Other hYYa apps are up to 50% off until 31 December.",
        apps: [
            // Full names, as on the App Store (read 2026-11-23); ids pinned here, never taken from anywhere else.
            // hYYa ink left out (owner, 2026-11-28): its sale runs on different dates from "until 31 December".
            App(id: "folder", name: "hYYa Encrypted Folder", appStoreID: "6786135330", icon: "SaleFolder"),
            App(id: "notes", name: "hYYa Encrypted Notes", appStoreID: "6792328099", icon: "SaleNotes"),
            App(id: "tracker", name: "hYYa Subscription Tracker", appStoreID: "6760548018", icon: "SaleTracker"),
        ])

    static let seenKey = "sale.seen"

    /// Renders for the owner's review only (Debug): `-previewSale`.
    static var preview: Bool { LaunchOptions.has("-previewSale") }

    static func isLive(_ sale: Sale = current, now: Date = .now) -> Bool { now >= sale.start && now <= sale.end }

    /// Due when the sale is on and this device hasn't shown it yet. Never in screenshot runs with made-up data.
    static func isDue(seen: String?, sale: Sale = current, now: Date = .now) -> Bool {
        if preview { return true }
        if LaunchOptions.has("-sampleData") { return false }
        return isLive(sale, now: now) && seen != sale.id
    }
}

/// The notice itself: title, one line, and the apps on sale, each opening its App Store page.
struct SaleNoticeCard: View {
    var sale: SaleNotice.Sale = SaleNotice.current
    let close: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ToneCard(tone: .context, title: sale.title, symbol: "sparkles") {
            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.brand(.footnote, .semibold))
                    .foregroundStyle(Brand.textMuted)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        } content: {
            Text(sale.body)
                .font(.brand(.subheadline)).foregroundStyle(Brand.textMuted)
                .fixedSize(horizontal: false, vertical: true)
            // Three in a row, names wrapping onto two lines; one under another only at the largest text sizes.
            // Never a lone tile under a full row.
            if typeSize.isAccessibilitySize {
                VStack(spacing: 8) { ForEach(sale.apps) { app in tile(app) } }
            } else {
                row(sale.apps, minWidth: 0)
            }
        }
    }

    /// Tiles side by side, all the same height.
    private func row(_ apps: [SaleNotice.App], minWidth: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(apps) { app in tile(app).frame(minWidth: minWidth, maxWidth: .infinity, maxHeight: .infinity) }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func tile(_ app: SaleNotice.App) -> some View {
        Button { AppStorePage.open(app.appStoreID) } label: {
            VStack(spacing: 8) {
                Image(app.icon)
                    .resizable().scaledToFill()
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityHidden(true)
                Text(app.name)
                    .font(.brand(.caption, .semibold)).foregroundStyle(Brand.ink)
                    .multilineTextAlignment(.center)
                    // Three to a row: "hYYa / Encrypted / Folder" may need three lines; never cut a name short.
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.vertical, 12).padding(.horizontal, 6)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.05)))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableCardStyle())
        .accessibilityLabel("\(app.name), opens the App Store")
    }
}

/// Opens an app's App Store page: inside the app on iPhone and iPad, the App Store app on a Mac.
@MainActor
enum AppStorePage {
    static func open(_ id: String) {
        #if os(iOS)
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first(where: { $0.activationState == .foregroundActive }),
              var top = scene.keyWindow?.rootViewController else { return }
        while let next = top.presentedViewController { top = next }
        let presenter = top
        // Load first and show only a page that loaded: presenting first leaves a blank sheet with no way out
        // when the App Store can't be reached (hYYa Subscription Tracker's finding, 2026-11-23). Otherwise the
        // App Store app opens the page.
        let store = SKStoreProductViewController()
        store.delegate = Closer.shared
        store.loadProduct(withParameters: [SKStoreProductParameterITunesItemIdentifier: id]) { loaded, _ in
            Task { @MainActor in
                if loaded, presenter.presentedViewController == nil {
                    presenter.present(store, animated: true)
                } else if !loaded, let url = URL(string: "https://apps.apple.com/app/id\(id)") {
                    UIApplication.shared.open(url)
                }
            }
        }
        #else
        if let url = URL(string: "macappstore://apps.apple.com/app/id\(id)") { NSWorkspace.shared.open(url) }
        #endif
    }
}

#if os(iOS)
/// Closes the App Store page when the person taps Done.
private final class Closer: NSObject, SKStoreProductViewControllerDelegate {
    @MainActor static let shared = Closer()
    func productViewControllerDidFinish(_ viewController: SKStoreProductViewController) {
        viewController.dismiss(animated: true)
    }
}
#endif
