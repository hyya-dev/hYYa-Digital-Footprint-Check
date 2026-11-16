// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

/// The paper a section is written on (every section is a detective's sticky
/// note). Yellow before a check; then the colour of what it found.
enum Paper: CaseIterable, Sendable {
    case yellow, pink, green, blue, purple, gray

    /// The Mac Stickies colours. Every ink used on them is measured to reach
    /// WCAG 2.2 AA, 4.5:1 for text and 3:1 for marks, on all six (see Color(dark:paper:)).
    var colour: Color {
        let hex: UInt32 = switch self {
        case .yellow: 0xFBEB61
        case .pink: 0xF3B6B3
        case .green: 0xA2FC90
        case .blue: 0xA1EEFD
        case .purple: 0xA1B5F8
        case .gray: 0xDADADB
        }
        return Color(hex: Self.softened(hex, by: Self.softening))
    }

    /// How far each paper moves toward a pale warm white (0 = full colour). Plan D4: 0.3, the owner's choice.
    static var softening: Double {
        #if DEBUG
        if let v = LaunchOptions.value(after: "-paperSoft").flatMap(Double.init) { return v }
        #endif
        return 0.3   // owner's choice from the renders, 2026-11-14
    }

    /// Mixes a colour toward a pale warm white, #F4F2EE, in sRGB. Up to 0.5, every ink in Ink.swift keeps its own target
    /// (body 9:1, secondary 7:1, hints and meaning colours 6:1, amber marks 3.3:1; measured 2026-11-14).
    static func softened(_ hex: UInt32, by t: Double) -> UInt32 {
        guard t > 0 else { return hex }
        let target = [0xF4, 0xF2, 0xEE]
        let parts = [16, 8, 0].enumerated().map { i, shift -> Int in
            let c = Double((hex >> shift) & 0xFF)
            return Int((c + (Double(target[i]) - c) * t).rounded()) << shift
        }.reduce(0, |)
        return UInt32(parts)
    }

    /// The paper for a role: purple for "worth a look", green for fixes, blue for what a clue tells
    /// an app, gray for background and for "only Apple can fix". No pink,
    /// and as little yellow as possible .
    static func `for`(_ tone: Tone) -> Paper {
        switch tone {
        case .alert: .purple
        case .explain: .blue
        case .context: .gray
        case .fix: .green
        case .limit: .gray
        }
    }

    /// The paper for a 0–100 score: green when well protected, blue in the middle, purple when heavy; gray before any check.
    static func `for`(score: Int?) -> Paper {
        guard let score else { return .gray }
        return score >= 75 ? .green : score >= 50 ? .blue : .purple
    }
}

/// A sticky note: the content on light paper, written in dark ink, pinned or taped, slightly
/// askew. Each note's tilt, fixing and wear come from its seed, so a page never shows two the
/// same and nothing sits perfectly level, yet a note looks the same every time it's drawn.
struct StickyNote: ViewModifier {
    let paper: Paper
    let seed: String
    /// How it's fixed to the page. One rule : a note that holds a
    /// list of rows is taped across the top; a single note is pinned.
    let fixing: NoteFixing
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The note's height: a tall note tilts less, so no corner swings more than 6 points out.
    @State private var height: CGFloat = 0

    private var hash: UInt64 {
        seed.utf8.reduce(1469598103934665603) { ($0 ^ UInt64($1)) &* 1099511628211 }
    }

    private func capped(_ degrees: Double) -> Double {
        guard height > 24 else { return degrees }
        let limit = asin(min(1, 6 / (height / 2))) * 180 / .pi
        return min(abs(degrees), limit) * (degrees < 0 ? -1 : 1)
    }

    func body(content: Content) -> some View {
        // Midnight Library (owner, 2026-11-16): a flat slate card on the warm charcoal page, edged by a
        // faint line. No paper, tilt, tape or pin. A card's meaning shows as a thin coloured line down
        // its leading edge: coral for "worth a look", sage for a fix. Content stays in the dark scheme.
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        content
            .background(Brand.surface)
            .overlay(alignment: .leading) {
                if let mark = Self.mark(for: paper) {
                    Rectangle().fill(mark).frame(width: 3).accessibilityHidden(true)
                }
            }
            .clipShape(shape)
            .overlay(shape.strokeBorder(Color.white.opacity(0.05), lineWidth: 1))
            .padding(.vertical, 2)
    }

    /// The leading line: only cards with a meaning get one.
    static func mark(for paper: Paper) -> Color? {
        switch paper {
        case .purple, .pink: Brand.concern.color
        case .green: Brand.green.color
        default: nil
        }
    }
}

extension View {
    /// Writes this section on a sticky note. Give each call site its own seed; the default is the
    /// caller's file and line, so two notes on a page never match.
    func stickyNote(_ paper: Paper = .gray, seed: String? = nil, fixing: NoteFixing = .pin, file: String = #fileID, line: Int = #line) -> some View {
        modifier(StickyNote(paper: paper, seed: seed ?? "\(file):\(line)", fixing: fixing))
    }
}

/// How a note is held on the page.
enum NoteFixing: Sendable { case pin, tape }

/// How a note has aged. Each note gets one, from its seed. No coffee ring (it read as dirt).
enum Wear: CaseIterable { case torn, cutCorner, curl, dogEar, aged }

/// The paper's outline: a ragged bottom edge, a snipped corner or a rolled corner; otherwise square.
struct NoteShape: Shape {
    let wear: Wear
    let seed: UInt64
    func path(in r: CGRect) -> Path {
        var p = Path()
        switch wear {
        case .torn:
            p.move(to: r.origin); p.addLine(to: CGPoint(x: r.maxX, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - 4))
            var x = r.maxX, i: UInt64 = 0
            while x > r.minX {
                i += 1; x -= CGFloat(7 + (seed >> (i % 40)) % 9)
                p.addLine(to: CGPoint(x: max(x, r.minX), y: r.maxY - CGFloat((seed >> ((i * 3) % 50)) % 7)))
            }
            p.addLine(to: CGPoint(x: r.minX, y: r.maxY - 3))
        case .cutCorner:
            p.move(to: CGPoint(x: r.minX + 22, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX, y: r.minY + 22))
        case .curl:
            p.move(to: r.origin); p.addLine(to: CGPoint(x: r.maxX, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - 30))
            p.addLine(to: CGPoint(x: r.maxX - 30, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        case .dogEar:
            p.move(to: r.origin); p.addLine(to: CGPoint(x: r.maxX - 24, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.minY + 24))
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        case .aged:
            p.addRect(r)
        }
        p.closeSubpath()
        return p
    }
}

/// Marks on the paper itself: a faint coffee ring, or yellowed edges and a crease. Kept light so
/// text over them keeps its contrast.
struct WearMarks: View {
    let wear: Wear
    var body: some View {
        GeometryReader { g in
            switch wear {
            case .aged:
                ZStack {
                    RoundedRectangle(cornerRadius: 2).strokeBorder(Color(hex: 0x7A5420, alpha: 0.18), lineWidth: 10).blur(radius: 6)
                    Path { p in p.move(to: CGPoint(x: g.size.width * 0.64, y: 0)); p.addLine(to: CGPoint(x: g.size.width * 0.58, y: g.size.height)) }
                        .stroke(Color.black.opacity(0.07), lineWidth: 1.5)
                }
            default: EmptyView()
            }
        }
        .allowsHitTesting(false)
    }
}
