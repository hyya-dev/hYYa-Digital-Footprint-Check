// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.hyya.footprintinspector

import com.hyya.footprintinspector.catalogue.Catalogue
import com.hyya.footprintinspector.model.Advisory
import com.hyya.footprintinspector.model.Finding
import com.hyya.footprintinspector.model.FootprintScore
import com.hyya.footprintinspector.model.Group
import com.hyya.footprintinspector.model.Reading
import com.hyya.footprintinspector.model.Severity
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AdvisoryTest {
    private fun finding(id: String, raise: Severity? = null, kept: Boolean = false) =
        Finding(Catalogue.list.first { it.id == id }, Reading(id, "x", severityOverride = raise), kept)

    @Test fun permissionFindingsAreAdviceNotScored() {
        val permission = Catalogue.list.first { it.section.group == Group.PERMISSION }
        val f = Finding(permission, Reading(permission.id, "x", severityOverride = Severity.HIGH))
        assertEquals(Advisory.PERMISSION, f.advisory)
        assertFalse(f.isConcerning)
        assertEquals(0, FootprintScore.points(f))
        assertEquals(100, FootprintScore.of(listOf(f)).value)
    }

    @Test fun languagesAndKeyboardsAreFyi() {
        val all = listOf(finding("languages", Severity.MEDIUM), finding("keyboards", Severity.MEDIUM))
        assertTrue(all.all { it.advisory == Advisory.FYI && !it.canKeep })
        assertEquals(100, FootprintScore.of(all).value)
    }

    @Test fun keptFindingStopsCounting() {
        val restart = finding("boot-time", Severity.HIGH)
        assertTrue(restart.canKeep && restart.isConcerning)
        val kept = restart.copy(kept = true)
        assertEquals(Advisory.KEPT, kept.advisory)
        assertFalse(kept.isConcerning)
        assertEquals(100, FootprintScore.of(listOf(kept)).value)
    }
}
