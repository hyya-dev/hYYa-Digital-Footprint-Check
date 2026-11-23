// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.hyya.footprintinspector.agesignal

import android.content.Context

/**
 * Age-assurance laws (California's from 2027, among others) ask every app to request the age signal the store
 * holds. Footprint changes nothing with it: no feature depends on age.
 *
 * Asked only where Play says a law applies, at the first launch after install (or of the update that added
 * this), after a significant change, and otherwise at most once a year. The answer is never stored, logged,
 * sent or shown: the device keeps only the date it asked.
 */
object AgeSignalSchedule {
    const val CHECKED_ON_KEY = "ageSignal.checkedOn"
    private const val YEAR_MS = 365L * 24 * 3600 * 1000

    /** Raise this when an update changes the app in a way the law calls significant. Asks everyone again once. */
    const val LAST_SIGNIFICANT_CHANGE_MS = 1_795_392_000_000L // 2026-11-23

    fun isDue(checkedOnMs: Long?, nowMs: Long): Boolean {
        if (checkedOnMs == null) return true
        if (checkedOnMs < LAST_SIGNIFICANT_CHANGE_MS) return true
        return nowMs - checkedOnMs >= YEAR_MS || nowMs < checkedOnMs
    }

    private fun prefs(context: Context) = context.getSharedPreferences("app", Context.MODE_PRIVATE)

    fun isDue(context: Context, nowMs: Long = System.currentTimeMillis()): Boolean =
        isDue(prefs(context).getLong(CHECKED_ON_KEY, -1L).takeIf { it >= 0 }, nowMs)

    fun markChecked(context: Context, nowMs: Long = System.currentTimeMillis()) {
        prefs(context).edit().putLong(CHECKED_ON_KEY, nowMs).apply()
    }
}
