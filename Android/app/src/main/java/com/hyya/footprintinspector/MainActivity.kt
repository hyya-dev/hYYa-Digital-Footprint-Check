// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.hyya.footprintinspector

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.hyya.footprintinspector.secure.DeviceIntegrity
import com.hyya.footprintinspector.secure.IntegrityFinding
import com.hyya.footprintinspector.secure.IntegrityProblem
import com.hyya.footprintinspector.secure.IntegrityResult
import com.hyya.footprintinspector.scan.Sample
import com.hyya.footprintinspector.ui.App
import com.hyya.footprintinspector.ui.FootprintTheme
import com.hyya.footprintinspector.ui.Tab

class MainActivity : ComponentActivity() {
    /** Set when DeviceIntegrity finds a problem; checked again each time the app comes back, so it opens as
     *  soon as the cause is gone. Debug builds can show it with `--es previewIntegrity DEBUGGER`. */
    private var integrity by mutableStateOf(IntegrityResult())

    /** The F-Droid root warning is said once per installed version, then the app just runs. */
    private var rootWarningSeen by mutableStateOf(false)

    private fun checkIntegrity() {
        val dev = BuildConfig.DEBUG
        val preview = if (dev) intent.getStringExtra("previewIntegrity") else null
        val previewFinding = preview?.let { name ->
            IntegrityProblem.entries.firstOrNull { it.name == name }?.let { p ->
                IntegrityFinding(p, mapOf(IntegrityProblem.MODIFIED_SYSTEM to "Magisk", IntegrityProblem.HOOKING_TOOL to "frida-agent-64.so")[p])
            }
        }
        // `--ez previewRootWarning true` shows the F-Droid root warning in any debug build.
        val warnOnRoot = BuildConfig.FDROID || (dev && intent.getBooleanExtra("previewRootWarning", false))
        integrity = when {
            previewFinding == null -> DeviceIntegrity.current(this)
            warnOnRoot && previewFinding.problem == IntegrityProblem.MODIFIED_SYSTEM -> IntegrityResult(warning = previewFinding)
            else -> IntegrityResult(block = previewFinding)
        }
        rootWarningSeen = previewFinding == null && getSharedPreferences("app", MODE_PRIVATE).getInt("rootWarningSeen", 0) == BuildConfig.VERSION_CODE
    }

    private fun dismissRootWarning() {
        getSharedPreferences("app", MODE_PRIVATE).edit().putInt("rootWarningSeen", BuildConfig.VERSION_CODE).apply()
        rootWarningSeen = true
    }

    override fun onResume() {
        super.onResume()
        checkIntegrity()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        checkIntegrity()
        // Revealed app names must not linger in the Recents thumbnail. Screenshots still work.
        setRecentsScreenshotEnabled(false)
        // The short name is only for the home screen icon; Recents gets the full name.
        setTaskDescription(android.app.ActivityManager.TaskDescription.Builder().setLabel(getString(R.string.app_full_name)).build())
        enableEdgeToEdge(statusBarStyle = SystemBarStyle.dark(android.graphics.Color.TRANSPARENT),
            navigationBarStyle = SystemBarStyle.dark(android.graphics.Color.TRANSPARENT))
        // Screenshot switches (adb shell am start … --ez sampleData true --es startTab sensitive --ez autoScan true).
        // Debug builds only: this activity is exported (it's the launcher), so in a store build any
        // installed app could otherwise start it with made-up, reassuring results.
        val dev = BuildConfig.DEBUG
        Sample.on = dev && intent.getBooleanExtra("sampleData", false)
        val startTab = (if (dev) intent.getStringExtra("startTab") else null)?.let { name -> Tab.entries.firstOrNull { it.name.equals(name, true) } } ?: Tab.HOME
        val autoScan = dev && intent.getBooleanExtra("autoScan", false)
        if (dev) intent.getStringExtra("sensitiveCategories")?.let { ids ->
            getSharedPreferences("app", MODE_PRIVATE).edit().putStringSet("sensitiveCategories", ids.split(",").toSet()).apply()
        }
        // Shows the re-scan reminder now, to check it without waiting a week.
        if (dev && intent.getBooleanExtra("testReminder", false)) com.hyya.footprintinspector.remind.ScanReminder.post(this)
        val openFinding = if (dev) intent.getStringExtra("openFinding") else null
        val openFix = dev && intent.getBooleanExtra("openFix", false)
        setContent {
            FootprintTheme {
                val block = integrity.block
                val warning = integrity.warning
                when {
                    block != null -> com.hyya.footprintinspector.ui.IntegrityBlock(block)
                    warning != null && !rootWarningSeen -> com.hyya.footprintinspector.ui.RootWarning(warning, ::dismissRootWarning)
                    else -> App(startTab, autoScan, openFinding, openFix)
                }
            }
        }
    }
}
