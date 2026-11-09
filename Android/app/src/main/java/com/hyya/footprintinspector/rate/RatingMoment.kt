// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.hyya.footprintinspector.rate

import java.time.Instant
import java.time.ZoneId

/**
 * When to ask for a rating. Only at a good moment: right after the score went up, or once the
 * person has come back and scanned on at least two different days. Never on the first scan, and at
 * most once per app version (Google Play also limits how often the prompt shows).
 */
object RatingMoment {
    const val ASKED_KEY = "rating.askedVersion"
    const val MINIMUM_SCANS = 3

    fun shouldAsk(scoreDelta: Int?, scanDates: List<Long>, askedVersion: String?, currentVersion: String,
                  zone: ZoneId = ZoneId.systemDefault()): Boolean {
        if (askedVersion == currentVersion || scanDates.size < 2) return false
        if (scoreDelta != null && scoreDelta > 0) return true
        val days = scanDates.map { Instant.ofEpochMilli(it).atZone(zone).toLocalDate() }.toSet()
        return scanDates.size >= MINIMUM_SCANS && days.size >= 2
    }
}
