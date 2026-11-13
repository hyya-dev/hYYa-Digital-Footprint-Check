// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.hyya.footprintinspector.secure

import android.content.Context
import android.content.pm.PackageManager
import android.os.Debug
import android.provider.Settings
import com.hyya.footprintinspector.BuildConfig
import java.io.File
import java.security.MessageDigest

/** Why a store build won't run on this device. Each means the app, or the system under it, was
 *  changed or is being watched by a tool, so what it shows can't be trusted. */
enum class IntegrityProblem { MODIFIED_SYSTEM, HOOKING_TOOL, DEBUGGER, MODIFIED_APP }

/** A problem and, where the check knows it, the exact thing it found, so the block screen can name it. */
data class IntegrityFinding(val problem: IntegrityProblem, val detail: String? = null)

/** What the app does about it: [block] stops the app; [warning] is shown once and the app carries on. */
data class IntegrityResult(val block: IntegrityFinding? = null, val warning: IntegrityFinding? = null)

/**
 * Checks for root, hooking tools, an attached debugger and a re-signed copy. Store builds only: debug
 * and "verify" builds never check, and neither do Google's pre-launch test phones. USB debugging on
 * its own is not a problem here: it stays a finding the app explains. The checks only read: nothing
 * is written, sent or kept.
 */
object DeviceIntegrity {
    /** What the checks look at. Real values in the app; made-up ones in tests. */
    class Probe(
        val fileExists: (String) -> Boolean,
        val classExists: (String) -> Boolean,
        val mappedLibraries: () -> List<String>,
        val threadNames: () -> List<String>,
        val debuggerAttached: () -> Boolean,
        val tracerPid: () -> Int,
        val signingCerts: () -> List<String>,
        val checkSignature: Boolean,
    )

    /** su and its helpers: present only once a device is rooted. */
    val ROOT_FILES = listOf(
        "/system/bin/su", "/system/xbin/su", "/sbin/su", "/su/bin/su", "/system/sd/xbin/su",
        "/data/local/su", "/data/local/bin/su", "/data/local/xbin/su", "/system/bin/failsafe/su",
        "/system/app/Superuser.apk", "/system/xbin/daemonsu", "/sbin/.magisk", "/cache/.disable_magisk",
    )

    /** The hooking frameworks' own classes. */
    val HOOK_CLASSES = listOf("de.robv.android.xposed.XposedBridge", "com.saurik.substrate.MS")

    /** Parts of library FILE names that only hooking tools load. Matched against the file name only, never the
     *  folders: Android puts apps in folders with random names, which could contain any letters by chance. */
    val HOOK_LIBRARIES = listOf("frida-agent", "frida-gadget", "libfrida", "libsubstrate", "xposedbridge", "liblspd", "libedxp")

    /** Thread names Frida gives its own threads. */
    fun isHookThread(name: String) = name == "gum-js-loop" || name.startsWith("frida")

    /** SHA-256 of the certificates genuine copies are signed with: Google Play's app-signing key, and our
     *  upload key, which signs the APK on the GitHub Releases. Public certificates, not secrets. */
    val GENUINE_CERTS = setOf(
        "10b7f5342c1aabd68e063ea677228ac6c0fa9e6db33355c6578d2bdab397603d",
        "b02c93bd33825a0c9609a51130cc662ef427b7051e019bbaac5d4e74fa99dce7",
    )

    /** Root, if found. */
    fun rooted(p: Probe): IntegrityFinding? =
        ROOT_FILES.firstOrNull(p.fileExists)?.let { file ->
            IntegrityFinding(IntegrityProblem.MODIFIED_SYSTEM, if ("magisk" in file) "Magisk" else file)
        }

    /** The first problem found, in order of how much it says; null means all is well. */
    fun problem(p: Probe): IntegrityFinding? = rooted(p) ?: tampering(p)

    /**
     * The F-Droid edition only warns about root (owner, 2026-11-13): F-Droid's users root their phones far more
     * often, and a rooted phone on its own doesn't change this app. A hooking tool or a debugger inside the app
     * still blocks there, because that is the app itself being changed; on a rooted phone they are still looked for.
     */
    fun result(p: Probe, warnOnRoot: Boolean): IntegrityResult =
        if (!warnOnRoot) IntegrityResult(block = problem(p))
        else IntegrityResult(block = tampering(p), warning = rooted(p))

    /** A hooking tool, a debugger, or a re-signed copy. */
    private fun tampering(p: Probe): IntegrityFinding? {
        HOOK_CLASSES.firstOrNull(p.classExists)?.let { cls ->
            return IntegrityFinding(IntegrityProblem.HOOKING_TOOL, if ("xposed" in cls) "Xposed or LSPosed" else "Substrate")
        }
        val files = p.mappedLibraries().mapNotNull { line -> line.substringAfterLast('/', "").takeIf { it.isNotEmpty() } }
        files.firstOrNull { f -> HOOK_LIBRARIES.any { it in f.lowercase() } }?.let { return IntegrityFinding(IntegrityProblem.HOOKING_TOOL, it) }
        if (p.threadNames().any(::isHookThread)) return IntegrityFinding(IntegrityProblem.HOOKING_TOOL, "Frida")
        if (p.debuggerAttached() || p.tracerPid() != 0) return IntegrityFinding(IntegrityProblem.DEBUGGER)
        if (p.checkSignature && p.signingCerts().none { it in GENUINE_CERTS }) return IntegrityFinding(IntegrityProblem.MODIFIED_APP)
        return null
    }

    /** Google's pre-launch report phones (Firebase Test Lab), by Google's documented setting. */
    fun isTestLab(c: Context): Boolean =
        Settings.System.getString(c.contentResolver, "firebase.test.lab") == "true"

    /** What to do on this device. Always nothing where the build doesn't check, or if a check can't read. */
    fun current(c: Context): IntegrityResult {
        if (!BuildConfig.DEVICE_CHECK || isTestLab(c)) return IntegrityResult()
        return runCatching { result(live(c), warnOnRoot = BuildConfig.FDROID) }.getOrDefault(IntegrityResult())
    }

    private fun live(c: Context) = Probe(
        fileExists = { File(it).exists() },
        classExists = { name ->
            runCatching { Class.forName(name, false, ClassLoader.getSystemClassLoader()); true }.getOrDefault(false)
        },
        mappedLibraries = { runCatching { File("/proc/self/maps").readLines() }.getOrDefault(emptyList()) },
        threadNames = {
            File("/proc/self/task").listFiles().orEmpty().mapNotNull { runCatching { File(it, "comm").readText().trim() }.getOrNull() }
        },
        debuggerAttached = { Debug.isDebuggerConnected() || Debug.waitingForDebugger() },
        tracerPid = {
            runCatching {
                File("/proc/self/status").readLines().first { it.startsWith("TracerPid:") }.substringAfter(':').trim().toInt()
            }.getOrDefault(0)
        },
        signingCerts = {
            val info = c.packageManager.getPackageInfo(c.packageName, PackageManager.GET_SIGNING_CERTIFICATES).signingInfo
            val certs = if (info == null) emptyArray() else if (info.hasMultipleSigners()) info.apkContentsSigners else info.signingCertificateHistory
            certs.map { sig -> MessageDigest.getInstance("SHA-256").digest(sig.toByteArray()).joinToString("") { "%02x".format(it) } }
        },
        // F-Droid signs its own builds with its own key, from the same public source.
        checkSignature = !BuildConfig.FDROID,
    )
}
