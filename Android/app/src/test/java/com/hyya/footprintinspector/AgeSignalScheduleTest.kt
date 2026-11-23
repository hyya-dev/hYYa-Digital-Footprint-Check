// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.hyya.footprintinspector

import com.hyya.footprintinspector.agesignal.AgeSignalSchedule
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AgeSignalScheduleTest {
    private val day = 24L * 3600 * 1000
    private val base = AgeSignalSchedule.LAST_SIGNIFICANT_CHANGE_MS

    @Test fun dueOnFirstLaunch() = assertTrue(AgeSignalSchedule.isDue(null, base))
    @Test fun notDueWithinAYear() = assertFalse(AgeSignalSchedule.isDue(base + day, base + 200 * day))
    @Test fun dueAfterAYear() = assertTrue(AgeSignalSchedule.isDue(base + day, base + 367 * day))
    @Test fun dueAfterASignificantChange() = assertTrue(AgeSignalSchedule.isDue(base - day, base + day))
    @Test fun dueIfTheClockWentBack() = assertTrue(AgeSignalSchedule.isDue(base + 10 * day, base + day))
}
