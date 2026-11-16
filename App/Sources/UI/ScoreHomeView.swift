// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import WidgetKit

/// The home page: one privacy score for all four checks, each check's own part, and the way to
/// share it. The score is kept between launches and moves as soon as any check changes
///.
struct ScoreHomeView: View {
    @Environment(Scanner.self) private var scanner
    @Environment(HistoryStore.self) private var history
    @Environment(PrivacyCheck.self) private var check
    @Environment(\.goToTab) private var goToTab
    @CheckStored(\.checkUpDone) private var checkUpStored
    @CheckStored(\.trackerChecked) private var trackerStored
    @State private var showingFormula = false
    #if os(iOS)
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    private var short: Bool { verticalSizeClass == .compact }
    #else
    private let short = false
    #endif

    var body: some View {
        let overall = OverallScore.current(scanner: scanner, history: history, check: check,
                                           checkUpStored: checkUpStored, trackerStored: trackerStored)
        NavigationStack {
            Page {
                if let value = overall.value {
                    scoreHeader(overall, value: value)
                } else {
                    welcome
                }
                SectionTitle(title: "Your checks", trailing: "\(overall.doneCount) of \(overall.total)")
                ChecksPanel(overall: overall)
                if overall.value != nil {
                    ToneCard(tone: .context, title: "Stay on top of it", symbol: "calendar.badge.clock") {
                        Text("A restart once a week clears some kinds of spyware and gives apps a new restart time. I can remind you.")
                            .font(.brand(.subheadline)).foregroundStyle(Brand.textMuted).fixedSize(horizontal: false, vertical: true)
                        WeeklyReminderToggle()
                    }
                    WidgetOfferCard(value: overall.value ?? 0)
                }
            }
            .hiddenNavigationBar()
            .sheet(isPresented: $showingFormula) { FormulaSheet() }
        }
    }

    /// Before any check: what the app does and the first step.
    private var welcome: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Sideways on a phone the mascot shrinks, so the first step stays on screen.
            LivingMascot(mood: .idle, size: short ? 90 : 200)
                .frame(maxWidth: .infinity)
                .padding(.top, short ? 0 : 12)
            VStack(alignment: .leading, spacing: 12) {
                Brand.eyebrow("hYYa Digital Footprint Check")
                AccentRule()
                Text("What do your apps know about you?")
                    .scaledFont(34, weight: .bold, relativeTo: .largeTitle)
                    .foregroundStyle(Brand.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Four quick checks show what apps can learn about you, then help you fix it.")
                    .font(.brand(.body))
                    .foregroundStyle(Brand.textMuted)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(spacing: 14) {
                Button("Start with check 1") {
                    goToTab(.footprint)
                    Task { await scanner.scan() }
                }
                .buttonStyle(PrimaryCTAButtonStyle())
                Text("Nothing leaves your device · Open source")
                    .font(.brand(.footnote))
                    .foregroundStyle(Brand.textSubtle)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func scoreHeader(_ overall: OverallScore, value: Int) -> some View {
        let left = overall.total - overall.doneCount
        return VStack(alignment: .leading, spacing: 18) {
            // Side by side when they fit; stacked at the largest text sizes, where the ring grows.
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center) {
                    ScoreOrb(value: value, size: 128, tint: Self.tint(overall.level))
                    Spacer()
                    LivingMascot(mood: overall.level == .good ? .happy : .concerned, size: 132)
                }
                VStack(alignment: .leading, spacing: 12) {
                    LivingMascot(mood: overall.level == .good ? .happy : .concerned, size: 104)
                    ScoreOrb(value: value, size: 128, tint: Self.tint(overall.level))
                }
            }
            .padding(.top, 12)
            VStack(alignment: .leading, spacing: 6) {
                Brand.eyebrow(left == 0 ? "Your privacy score" : "Your privacy score so far")
                Text(overall.level?.title ?? "")
                    .scaledFont(30, weight: .bold, relativeTo: .largeTitle)
                    .foregroundStyle(Brand.ink)
                AccentRule().padding(.vertical, 4)
                Text(left == 0 ? "All \(overall.total) checks done. Higher is better." :
                        "\(overall.doneCount) of \(overall.total) checks done. Higher is better.")
                    .font(.brand(.body))
                    .foregroundStyle(Brand.textMuted)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                Button("How the score works") { showingFormula = true }
                    .buttonStyle(.plain)
                    .font(.brand(.footnote))
                    .foregroundStyle(Brand.textSubtle)
                    .padding(.top, 2)
            }
            // Until every check is done, the next check is the one obvious step; sharing waits.
            if let next = Self.nextCheck(overall) {
                Button("Do check \(next.step ?? 0): \(next.title)") {
                    goToTab(next)
                    if next == .footprint { Task { await scanner.scan() } }
                }
                .buttonStyle(PrimaryCTAButtonStyle())
                OverallShareButton(overall: overall)
                    .frame(maxWidth: .infinity)
            } else {
                OverallShareButton(overall: overall, prominent: true)
            }
        }
    }

    /// The first check not done yet, in the app's order.
    static func nextCheck(_ overall: OverallScore) -> AppTab? {
        let tabs: [OverallScore.Part: AppTab] = [.footprint: .footprint, .sensitive: .sensitive, .tracker: .tracker, .checkup: .checkup]
        return OverallScore.Part.onThisPlatform.first { overall.parts[$0] == nil }.flatMap { tabs[$0] }
    }

    static func tint(_ level: OverallScore.Level?) -> InkStyle {
        switch level {
        case .good?: Tone.fix.tint
        case .fair?: Brand.sand
        default: Tone.alert.tint
        }
    }
}


/// "Add the widget": a picture of the real widget with the score, and the steps. Apps on these systems
/// can't add a widget for you, so there's nothing to wait on. Shown until "Got it" or until a widget is
/// added; never in sample-data runs, so the store screenshots stay as they are.
private struct WidgetOfferCard: View {
    let value: Int
    @Environment(HistoryStore.self) private var history
    @AppStorage("widgetOfferDismissed") private var dismissed = false
    @State private var hasWidget = true

    var body: some View {
        Group {
            if Self.preview || (!dismissed && !hasWidget && !LaunchOptions.has("-sampleData")) {
                ToneCard(tone: .context, title: Self.title, symbol: "square.grid.2x2") {
                    HStack(alignment: .top, spacing: 16) {
                        ScoreWidgetView(score: WidgetScore(score: value, checkedAt: history.latest?.date ?? .now), size: .systemSmall)
                            .environment(\.colorScheme, .dark)
                            // Drawn at the real small-widget size, then scaled, so it looks exactly as it will.
                            .frame(width: 158, height: 158)
                            .background(Brand.page)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Brand.border, lineWidth: 1))
                            .scaleEffect(0.81, anchor: .topLeading)
                            .frame(width: 128, height: 128, alignment: .topLeading)
                            .accessibilityHidden(true)
                        Text("See your privacy score and your last check at a glance.")
                            .font(.brand(.subheadline)).foregroundStyle(Brand.ink).fixedSize(horizontal: false, vertical: true)
                    }
                    StepList(steps: Self.steps, tint: Brand.sand)
                    Button("Got it") { withAnimation { dismissed = true } }
                        .buttonStyle(GhostButtonStyle())
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .task {
            let configs = (try? await WidgetCenter.shared.currentConfigurations()) ?? []
            hasWidget = !configs.isEmpty
        }
    }

    /// Renders for the owner's review only.
    static var preview: Bool {
        #if DEBUG
        LaunchOptions.has("-previewWidgetOffer")
        #else
        false
        #endif
    }

    #if os(macOS)
    static let title = "Your score on your desktop"
    static let steps = [
        "Control-click an empty spot on the desktop and choose Edit Widgets.",
        "Search for hYYa, then drag the widget onto your desktop.",
    ]
    #else
    static let title = "Your score on your home screen"
    static let steps = [
        "Touch and hold an empty spot on your home screen until the apps jiggle.",
        "Tap Edit at the top, then Add Widget.",
        "Search for hYYa, choose a size and tap Add Widget.",
    ]
    #endif
}
