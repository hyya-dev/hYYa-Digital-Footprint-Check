// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.hyya.footprintinspector.ui

import android.content.Intent
import android.provider.Settings
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.SubcomposeLayout
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hyya.footprintinspector.catalogue.Directions
import com.hyya.footprintinspector.secure.IntegrityFinding
import com.hyya.footprintinspector.secure.IntegrityProblem

/** What was found, naming it where the check knows it. */
private fun found(f: IntegrityFinding): String {
    val thing = f.detail?.let { " ($it)" } ?: ""
    return when (f.problem) {
        IntegrityProblem.MODIFIED_SYSTEM ->
            "This device is rooted$thing: its built-in protections were removed, so other apps could read or change what this app shows."
        IntegrityProblem.HOOKING_TOOL ->
            "A tool that changes how apps run is active in this app$thing. It could change what the app shows you."
        IntegrityProblem.DEBUGGER ->
            "A computer is debugging this app, for example from Android Studio."
        IntegrityProblem.MODIFIED_APP ->
            "This copy of the app was changed or re-signed after it was published, so it isn't the genuine app."
    }
}

/** Exactly what to do, step by step. */
private fun steps(f: IntegrityFinding): List<String> = when (f.problem) {
    IntegrityProblem.MODIFIED_SYSTEM -> listOf(
        "If you rooted it with Magisk: open the Magisk app, tap Uninstall Magisk, then Complete Uninstall.",
        "Otherwise, put back the device maker's original software. The maker's support page for your model explains how, or ask the shop that rooted it.",
        "Restart the device and open the app again.",
    )
    IntegrityProblem.HOOKING_TOOL -> listOf(
        "If you use LSPosed or another Xposed manager: open it and turn off every module for hYYa Digital Footprint Check, or remove the manager.",
        "If a computer is running Frida on this device, stop it and unplug the cable.",
        "Restart the device and open the app again.",
    )
    IntegrityProblem.DEBUGGER -> listOf(
        "On the computer that's debugging the app, stop the debugging session and unplug the cable.",
        "In ${Directions.here.developerOptions}, set Select debug app to None and turn off Wait for debugger.",
        "Close the app and open it again.",
    )
    IntegrityProblem.MODIFIED_APP -> listOf(
        "Uninstall this copy: touch and hold the app's icon, then tap Uninstall.",
        "Install hYYa Digital Footprint Check from Google Play, or from the project's GitHub Releases page.",
    )
}

/** The only screen a store build shows when `DeviceIntegrity` finds a problem. Everything fits on one
 *  screen: the text shrinks step by step until it does, and only scrolls at the very largest text sizes. */
@Composable
fun IntegrityBlock(finding: IntegrityFinding) {
    Frame { scale -> Words(finding, scale) }
}

/**
 * The F-Droid edition's root warning (owner, 2026-11-13): said once, then the app carries on. The steps to
 * remove root are there, folded away, for anyone who wants them.
 */
@Composable
fun RootWarning(finding: IntegrityFinding, onContinue: () -> Unit) {
    var showSteps by rememberSaveable { mutableStateOf(false) }
    // With the steps open the detective steps back, so everything still fits without scrolling.
    Frame(compact = showSteps) { scale ->
        Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy((14 * scale).dp)) {
            Eyebrow("hYYa Digital Footprint Check")
            Text("This device is rooted${finding.detail?.let { " ($it)" } ?: ""}", color = Brand.ink,
                fontSize = (24 * scale).sp, lineHeight = (30 * scale).sp, fontWeight = FontWeight.Bold)
            Text("Other apps with root access can change what this app shows, so some results may not be reliable. " +
                "You can still use the app.", color = Brand.textMuted, fontSize = (16 * scale).sp, lineHeight = (22 * scale).sp)
            if (showSteps) Steps(finding, scale)
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
                Button(onClick = onContinue,
                    colors = ButtonDefaults.buttonColors(containerColor = Brand.cta, contentColor = Brand.onCta),
                ) { Text("Continue", fontSize = (16 * scale).sp, fontWeight = FontWeight.SemiBold) }
                if (!showSteps) TextButton(onClick = { showSteps = true }) {
                    Text("How to fix it", color = Brand.sand, fontSize = (16 * scale).sp, fontWeight = FontWeight.SemiBold)
                }
            }
        }
    }
}

/** The mascot and the words, side by side when sideways, fitted to the screen. */
@Composable
private fun Frame(compact: Boolean = false, content: @Composable (Float) -> Unit) {
    val m = if (compact) 0.55f else 1f // sideways only: upright has the room
    BoxWithConstraints(Modifier.fillMaxSize().background(Color.Black).safeDrawingPadding()) {
        val wide = maxWidth > maxHeight
        val height = maxHeight.value
        Box(Modifier.fillMaxSize().padding(horizontal = 24.dp, vertical = 12.dp), contentAlignment = Alignment.Center) {
            if (wide) {
                Row(Modifier.widthIn(max = 960.dp), verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(24.dp)) {
                    Mascot(size = (minOf(200f, height * 0.6f) * m).toInt())
                    FitToHeight(Modifier.weight(1f), content)
                }
            } else {
                Column(Modifier.widthIn(max = 560.dp), horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Mascot(size = minOf(120, (height * 0.16f).toInt()))
                    FitToHeight(Modifier.fillMaxWidth(), content)
                }
            }
        }
    }
}

@Composable
private fun Words(finding: IntegrityFinding, scale: Float) {
    val context = LocalContext.current
    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy((14 * scale).dp)) {
        Eyebrow("hYYa Digital Footprint Check")
        Text("For security reasons, the app can't run on this device", color = Brand.ink,
            fontSize = (24 * scale).sp, lineHeight = (30 * scale).sp, fontWeight = FontWeight.Bold)
        Text(found(finding), color = Brand.textMuted, fontSize = (16 * scale).sp, lineHeight = (22 * scale).sp)
        Steps(finding, scale)
        if (finding.problem == IntegrityProblem.DEBUGGER) {
            Button(
                onClick = { runCatching { context.startActivity(Intent(Settings.ACTION_APPLICATION_DEVELOPMENT_SETTINGS)) }
                    .onFailure { context.startActivity(Intent(Settings.ACTION_SETTINGS)) } },
                colors = ButtonDefaults.buttonColors(containerColor = Brand.cta, contentColor = Brand.onCta),
            ) { Text("Open Developer options", fontSize = (16 * scale).sp, fontWeight = FontWeight.SemiBold) }
        }
    }
}

@Composable
private fun Steps(finding: IntegrityFinding, scale: Float) {
    Column(
        Modifier.fillMaxWidth().background(Brand.surface, RoundedCornerShape(14.dp))
            .border(1.dp, Color.White.copy(alpha = 0.08f), RoundedCornerShape(14.dp)).padding((14 * scale).dp),
        verticalArrangement = Arrangement.spacedBy((8 * scale).dp),
    ) {
        Eyebrow("How to fix it")
        steps(finding).forEachIndexed { i, step ->
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("${i + 1}.", color = Brand.sand, fontSize = (16 * scale).sp, lineHeight = (22 * scale).sp,
                    fontWeight = FontWeight.SemiBold, modifier = Modifier.alignByBaseline())
                Text(step, color = Brand.ink, fontSize = (16 * scale).sp, lineHeight = (22 * scale).sp,
                    modifier = Modifier.alignByBaseline())
            }
        }
    }
}

/** Lays out the content at the largest scale whose height fits; scrolls only if even the smallest doesn't. */
@Composable
private fun FitToHeight(modifier: Modifier, content: @Composable (Float) -> Unit) {
    val scales = listOf(1f, 0.9f, 0.8f, 0.72f, 0.64f)
    SubcomposeLayout(modifier) { c ->
        val free = c.copy(minHeight = 0, maxHeight = Constraints.Infinity)
        val chosen = scales.withIndex().firstOrNull { (i, s) ->
            subcompose("try$i") { content(s) }.sumOf { it.measure(free).height } <= c.maxHeight
        }?.value
        val placeables = subcompose("final") {
            if (chosen != null) content(chosen)
            else Column(Modifier.verticalScroll(rememberScrollState())) { content(scales.last()) }
        }.map { it.measure(c.copy(minHeight = 0)) }
        val height = placeables.sumOf { it.height }.coerceAtMost(c.maxHeight)
        layout(c.maxWidth, height) {
            var y = 0
            placeables.forEach { it.place(0, y); y += it.height }
        }
    }
}
