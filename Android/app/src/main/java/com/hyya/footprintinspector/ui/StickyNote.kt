// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.hyya.footprintinspector.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.fillMaxWidth

import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.draw.drawBehind
import androidx.compose.foundation.border
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.foundation.shape.GenericShape
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.unit.dp

/** The Mac Stickies colours; every ink on them is measured to WCAG 2.2 AA. */
enum class Paper(private val base: Long) {
    YELLOW(0xFFFBEB61), PINK(0xFFF3B6B3), GREEN(0xFFA2FC90),
    BLUE(0xFFA1EEFD), PURPLE(0xFFA1B5F8), GRAY(0xFFDADADB);

    /** The paper, moved [softening] of the way toward a pale warm white (#F4F2EE), as on iOS. Up to 0.5 every ink in
     *  Ink.kt keeps its own target (body 9:1, secondary 7:1, hints and meaning colours 6:1, amber marks 3.3:1). */
    val colour: Color get() = if (softening <= 0f) Color(base) else Color(base).let { c ->
        Color(c.red + (0xF4 / 255f - c.red) * softening, c.green + (0xF2 / 255f - c.green) * softening, c.blue + (0xEE / 255f - c.blue) * softening)
    }

    companion object {
        /** Plan D4: 0.3, the owner's choice from the renders (2026-11-14). Debug builds can override it for renders. */
        @Volatile var softening = 0.3f

        /** Green when well protected, blue in the middle, purple when heavy; gray before any check (no pink, little yellow). */
        fun forScore(score: Int?) = when {
            score == null -> GRAY
            score >= 75 -> GREEN
            score >= 50 -> BLUE
            else -> PURPLE
        }
    }
}


/** What an ink is for, on a sticky note. */
enum class InkRole { TEXT, MUTED, SUBTLE, ACCENT, CONCERN, FIX, EDGE, AMBER, RULE }

/** The paper the content sits on; null on the dark page. */
val LocalPaper = androidx.compose.runtime.staticCompositionLocalOf<Paper?> { null }

/**
 * The ink for each role on this paper ("the best colour for clear reading"), the same
 * table as iOS Ink.swift: body text in the paper's own hue, almost black (9 to 13:1); secondary 7:1 (AAA);
 * hints, headings and meaning colours 6:1; "worth knowing" marks 3.3:1, lighter so ring segments differ
 * in lightness as well as hue. Gray paper takes a warm charcoal.
 */
fun Paper.ink(role: InkRole): Color = Color(when (role) {
        InkRole.TEXT -> when (this) { Paper.YELLOW -> 0xFF25230E; Paper.PINK -> 0xFF251010; Paper.GREEN -> 0xFF162414; Paper.BLUE -> 0xFF042025; Paper.PURPLE -> 0xFF111526; Paper.GRAY -> 0xFF1A1511 }
        InkRole.MUTED -> when (this) { Paper.YELLOW -> 0xFF504D30; Paper.PINK -> 0xFF4C2E2D; Paper.GREEN -> 0xFF3D5039; Paper.BLUE -> 0xFF284E55; Paper.PURPLE -> 0xFF242B43; Paper.GRAY -> 0xFF49433E }
        InkRole.SUBTLE -> when (this) { Paper.YELLOW -> 0xFF59573D; Paper.PINK -> 0xFF553938; Paper.GREEN -> 0xFF485944; Paper.BLUE -> 0xFF36575E; Paper.PURPLE -> 0xFF2F364C; Paper.GRAY -> 0xFF534C47 }
        InkRole.ACCENT -> when (this) { Paper.YELLOW -> 0xFF7E4921; Paper.PINK -> 0xFF653205; Paper.GREEN -> 0xFF7D4820; Paper.BLUE -> 0xFF7A451D; Paper.PURPLE -> 0xFF582A00; Paper.GRAY -> 0xFF744017 }
        InkRole.CONCERN -> when (this) { Paper.YELLOW -> 0xFF9E2D23; Paper.PINK -> 0xFF830D09; Paper.GREEN -> 0xFF9C2C22; Paper.BLUE -> 0xFF99291F; Paper.PURPLE -> 0xFF740001; Paper.GRAY -> 0xFF93231A }
        InkRole.FIX -> when (this) { Paper.YELLOW -> 0xFF0D6332; Paper.PINK -> 0xFF014B23; Paper.GREEN -> 0xFF0B6231; Paper.BLUE -> 0xFF045F2E; Paper.PURPLE -> 0xFF023F1D; Paper.GRAY -> 0xFF005A2B }
        InkRole.EDGE -> when (this) { Paper.YELLOW -> 0xFF275792; Paper.PINK -> 0xFF0D4079; Paper.GREEN -> 0xFF255691; Paper.BLUE -> 0xFF23538E; Paper.PURPLE -> 0xFF01366E; Paper.GRAY -> 0xFF1D4E88 }
        InkRole.AMBER -> when (this) { Paper.YELLOW -> 0xFFAD721C; Paper.PINK -> 0xFF905B00; Paper.GREEN -> 0xFFAC701B; Paper.BLUE -> 0xFFA86D15; Paper.PURPLE -> 0xFF835201; Paper.GRAY -> 0xFFA3680A }
        InkRole.RULE -> when (this) { Paper.YELLOW -> 0xFFA19F82; Paper.PINK -> 0xFF9B7B79; Paper.GREEN -> 0xFF8EA28A; Paper.BLUE -> 0xFF7C9FA6; Paper.PURPLE -> 0xFF707891; Paper.GRAY -> 0xFF99928C }
})

/** How a note is held on the page: a note that holds a list of rows is taped across the top, a single note is pinned. */
enum class Fixing { PIN, TAPE }

/** How a note has aged. No coffee ring (it read as dirt). */
private enum class Wear { TORN, CUT_CORNER, CURL, DOG_EAR, AGED }

/**
 * A detective's sticky note: the content on light paper in dark ink (LocalOnPaper), pinned or
 * taped, slightly askew, with its own wear. Tilt, fixing and wear come from the seed, so a page
 * never shows two the same, yet a note looks the same every time. It grows with its content.
 */
@Composable
fun StickyNote(paper: Paper, seed: String, fixing: Fixing = Fixing.PIN, onClick: (() -> Unit)? = null, content: @Composable BoxScope.() -> Unit) {
    // Midnight Library (owner, 2026-11-16): a flat slate card on the charcoal page with a faint edge. No paper,
    // tilt, tape or pin. A card's meaning shows as a thin line down its leading edge: coral for "worth a look",
    // sage for a fix. Content stays on the dark ground (LocalOnPaper stays false).
    val shape = RoundedCornerShape(16.dp)
    val mark = when (paper) { Paper.PURPLE, Paper.PINK -> Brand.concern; Paper.GREEN -> Brand.green; else -> null }
    Box(
        Modifier.fillMaxWidth().padding(vertical = 2.dp)
            .then(if (onClick != null) Modifier.pressable(onClick) else Modifier)
            .clip(shape).background(Brand.surface)
            .border(1.dp, Color.White.copy(alpha = 0.05f), shape),
    ) {
        if (mark != null) Box(Modifier.matchParentSize().drawBehind { drawRect(mark, size = Size(3.dp.toPx(), size.height)) })
        content()
    }
}
