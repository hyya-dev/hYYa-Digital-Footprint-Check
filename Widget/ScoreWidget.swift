// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import WidgetKit

@main
struct ScoreWidgetBundle: WidgetBundle {
    var body: some Widget { ScoreWidget() }
}

struct ScoreWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ScoreWidget", provider: ScoreProvider()) { entry in
            ScoreWidgetView(score: entry.score)
        }
        .configurationDisplayName("hYYa Digital Footprint Check")
        .description("Keep your privacy score in sight and know when to check again.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

struct ScoreEntry: TimelineEntry {
    let date = Date()
    let score: WidgetScore?
}

/// One entry and no schedule: the app asks for a redraw whenever the score changes.
struct ScoreProvider: TimelineProvider {
    func placeholder(in context: Context) -> ScoreEntry { ScoreEntry(score: nil) }

    func getSnapshot(in context: Context, completion: @escaping (ScoreEntry) -> Void) {
        completion(ScoreEntry(score: WidgetScore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ScoreEntry>) -> Void) {
        completion(Timeline(entries: [ScoreEntry(score: WidgetScore.load())], policy: .never))
    }
}
