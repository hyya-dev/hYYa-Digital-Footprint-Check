// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.hyya.footprintinspector

import com.hyya.footprintinspector.rate.RatingMoment
import java.time.ZoneOffset
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RatingMomentTest {
    private val day = 86_400_000L
    private val start = 1_800_000_000_000L
    private val utc = ZoneOffset.UTC

    @Test fun neverOnTheFirstScan() {
        assertFalse(RatingMoment.shouldAsk(null, listOf(start), null, "1.0.7", utc))
    }

    @Test fun asksWhenTheScoreGoesUp() {
        assertTrue(RatingMoment.shouldAsk(4, listOf(start, start + 60_000), null, "1.0.7", utc))
        assertFalse(RatingMoment.shouldAsk(0, listOf(start, start + 60_000), null, "1.0.7", utc))
        assertFalse(RatingMoment.shouldAsk(-3, listOf(start, start + 60_000), null, "1.0.7", utc))
    }

    @Test fun asksWhenTheyComeBackOnAnotherDay() {
        assertFalse(RatingMoment.shouldAsk(0, listOf(start, start + 60_000, start + 120_000), null, "1.0.7", utc))
        assertTrue(RatingMoment.shouldAsk(0, listOf(start, start + 60_000, start + 2 * day), null, "1.0.7", utc))
    }

    @Test fun onlyOncePerVersion() {
        val dates = listOf(start, start + 2 * day, start + 4 * day)
        assertFalse(RatingMoment.shouldAsk(5, dates, "1.0.7", "1.0.7", utc))
        assertTrue(RatingMoment.shouldAsk(5, dates, "1.0.6", "1.0.7", utc))
    }
}
