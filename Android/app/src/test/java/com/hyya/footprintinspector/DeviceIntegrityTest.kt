// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.hyya.footprintinspector

import com.hyya.footprintinspector.secure.DeviceIntegrity
import com.hyya.footprintinspector.secure.IntegrityFinding
import com.hyya.footprintinspector.secure.IntegrityProblem
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class DeviceIntegrityTest {
    private val play = "10b7f5342c1aabd68e063ea677228ac6c0fa9e6db33355c6578d2bdab397603d"

    private fun probe(
        files: Set<String> = emptySet(), classes: Set<String> = emptySet(),
        maps: List<String> = listOf("7f00 r-xp /system/lib64/libc.so"), threads: List<String> = listOf("main", "RenderThread"),
        debugger: Boolean = false, tracer: Int = 0, certs: List<String> = listOf(play), checkSignature: Boolean = true,
    ) = DeviceIntegrity.Probe({ it in files }, { it in classes }, { maps }, { threads }, { debugger }, { tracer }, { certs }, checkSignature)

    private fun found(p: DeviceIntegrity.Probe) = DeviceIntegrity.problem(p)?.problem

    @Test fun aNormalPlayInstallRuns() = assertNull(found(probe()))

    @Test fun theGithubApkRuns() =
        assertNull(found(probe(certs = listOf("b02c93bd33825a0c9609a51130cc662ef427b7051e019bbaac5d4e74fa99dce7"))))

    @Test fun rootIsFound() {
        assertEquals(IntegrityProblem.MODIFIED_SYSTEM, found(probe(files = setOf("/system/xbin/su"))))
        assertEquals(IntegrityFinding(IntegrityProblem.MODIFIED_SYSTEM, "Magisk"), DeviceIntegrity.problem(probe(files = setOf("/sbin/.magisk"))))
    }

    @Test fun hookingToolsAreFound() {
        assertEquals(IntegrityProblem.HOOKING_TOOL, found(probe(classes = setOf("de.robv.android.xposed.XposedBridge"))))
        assertEquals(IntegrityFinding(IntegrityProblem.HOOKING_TOOL, "frida-agent-64.so"),
            DeviceIntegrity.problem(probe(maps = listOf("7f00 r-xp /data/local/tmp/frida-agent-64.so"))))
        assertEquals(IntegrityProblem.HOOKING_TOOL, found(probe(threads = listOf("main", "gum-js-loop"))))
    }

    @Test fun randomFolderNamesNeverMatch() {
        // Android's random install folders can spell anything; only library file names count.
        assertNull(found(probe(maps = listOf("7f00 r--p /data/app/~~FrIdAxEdXp==/com.hyya.footprintinspector-1/base.apk"))))
        assertNull(found(probe(threads = listOf("main", "pool-frame-1", "gmain"))))
    }

    @Test fun aDebuggerIsFound() {
        assertEquals(IntegrityProblem.DEBUGGER, found(probe(debugger = true)))
        assertEquals(IntegrityProblem.DEBUGGER, found(probe(tracer = 4242)))
    }

    @Test fun aResignedCopyIsFound() {
        assertEquals(IntegrityProblem.MODIFIED_APP, found(probe(certs = listOf("00ff"))))
        // F-Droid signs with its own key: no signature check there.
        assertNull(found(probe(certs = listOf("00ff"), checkSignature = false)))
    }
}
