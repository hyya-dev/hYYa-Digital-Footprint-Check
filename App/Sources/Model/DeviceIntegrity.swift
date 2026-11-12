// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import MachO
#if os(macOS)
import Security
#endif

/// Why a store build won't run on this device. Each one means the app, or the system under it,
/// has been changed or is being watched by a tool, so what it shows can't be trusted.
enum IntegrityProblem: String, CaseIterable {
    /// The system's protections were removed (jailbroken).
    case modifiedSystem
    /// A tool that changes how apps run is loaded into the app (Frida, Substrate and the like).
    case hookingTool
    /// A debugger is attached to the app.
    case debugger
    /// The app itself was changed or re-signed after it left the store.
    case modifiedApp
}

/// A problem and, where the check knows it, the exact thing it found (a jailbreak app, a hooking
/// library), so the block screen can name it.
struct IntegrityFinding: Equatable {
    let problem: IntegrityProblem
    var detail: String? = nil
}

/// Checks for a changed system, hooking tools, an attached debugger and a re-signed copy. Store
/// builds only: Debug builds and Simulators are never checked, so development and UI tests run as
/// before. The checks only read: nothing is written, sent or kept.
enum DeviceIntegrity {
    /// What the checks look at. Real values in the app; made-up ones in tests.
    struct Probe {
        var fileExists: (String) -> Bool
        var loadedImages: () -> [String]
        var isTraced: () -> Bool
        var hasProvisioningProfile: Bool
        var isEncrypted: Bool
        var isTestFlight: Bool
        var signatureIsIntact: () -> Bool
    }

    /// Files that exist only once iOS's protections are removed. Each is a jailbreak tool's own
    /// file, never part of a stock system, so a normal device can't match. General Unix files
    /// (/bin/bash, sshd) are left out on purpose: they prove nothing on their own.
    static let jailbreakFiles = [
        "/Applications/Cydia.app", "/Applications/Sileo.app", "/Applications/Zebra.app",
        "/Library/MobileSubstrate/MobileSubstrate.dylib", "/usr/lib/libsubstrate.dylib",
        "/usr/libexec/cydia", "/etc/apt", "/private/var/lib/apt",
        "/var/jb", "/var/binpack",
    ]

    /// Parts of library file names that only hooking tools load into an app. Matched against the
    /// file name only, never the folders, so a random folder name can't match by chance.
    static let hookingLibraries = [
        "mobilesubstrate", "substrateloader", "substrateinserter", "libsubstrate", "libsubstitute",
        "frida", "libhooker", "tweakinject", "cycript", "ellekit", "sslkillswitch",
    ]

    /// Friendly names for the jailbreak files people would recognise.
    static func name(ofJailbreakFile path: String) -> String {
        switch path {
        case "/Applications/Cydia.app", "/usr/libexec/cydia": "Cydia"
        case "/Applications/Sileo.app": "Sileo"
        case "/Applications/Zebra.app": "Zebra"
        case "/var/jb": "a rootless jailbreak"
        case "/Library/MobileSubstrate/MobileSubstrate.dylib", "/usr/lib/libsubstrate.dylib": "Cydia Substrate"
        default: path
        }
    }

    /// The first problem found, in order of how much it says. Nil means all is well.
    static func problem(_ probe: Probe, iOS: Bool) -> IntegrityFinding? {
        if iOS, let file = jailbreakFiles.first(where: probe.fileExists) {
            return IntegrityFinding(problem: .modifiedSystem, detail: name(ofJailbreakFile: file))
        }
        // Only what is really loaded counts: an injection setting that the system ignored (the
        // Mac's hardened runtime drops DYLD_INSERT_LIBRARIES) isn't a problem.
        let names = probe.loadedImages().map { ($0 as NSString).lastPathComponent }
        if let name = names.first(where: { name in hookingLibraries.contains { name.lowercased().contains($0) } }) {
            return IntegrityFinding(problem: .hookingTool, detail: name)
        }
        if probe.isTraced() { return IntegrityFinding(problem: .debugger) }
        // iOS: two independent signs must agree before calling a copy changed. A store install is
        // encrypted by Apple and carries no provisioning profile; a re-signed copy is decrypted and
        // carries one. One sign alone never blocks.
        if iOS ? (probe.hasProvisioningProfile && !probe.isEncrypted && !probe.isTestFlight) : !probe.signatureIsIntact() {
            return IntegrityFinding(problem: .modifiedApp)
        }
        return nil
    }

    /// Whether this build checks at all: store builds on a real device only.
    static var isEnforced: Bool {
        #if DEBUG || targetEnvironment(simulator)
        false
        #else
        true
        #endif
    }

    /// The problem on this device, or nil. Always nil when the build isn't checked.
    static func current() -> IntegrityFinding? {
        guard isEnforced else { return nil }
        #if os(macOS)
        return problem(.live, iOS: false)
        #else
        return problem(.live, iOS: true)
        #endif
    }
}

extension DeviceIntegrity.Probe {
    static var live: Self {
        Self(
            fileExists: { FileManager.default.fileExists(atPath: $0) },
            loadedImages: {
                (0..<_dyld_image_count()).compactMap { i in _dyld_get_image_name(i).map { String(cString: $0) } }
            },
            isTraced: {
                var info = kinfo_proc(), size = MemoryLayout<kinfo_proc>.stride
                var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
                guard sysctl(&mib, u_int(mib.count), &info, &size, nil, 0) == 0 else { return false }
                return info.kp_proc.p_flag & P_TRACED != 0
            },
            // A store copy carries no provisioning profile: Apple strips it. A re-signed copy has one.
            hasProvisioningProfile: Bundle.main.path(forResource: "embedded", ofType: "mobileprovision") != nil,
            isEncrypted: mainBinaryIsEncrypted(),
            isTestFlight: Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt",
            signatureIsIntact: {
                #if os(macOS)
                var code: SecCode?
                guard SecCodeCopySelf([], &code) == errSecSuccess, let code else { return true }
                return SecCodeCheckValidity(code, [], nil) == errSecSuccess
                #else
                true
                #endif
            }
        )
    }

    /// Whether the app's own binary is encrypted by the App Store (LC_ENCRYPTION_INFO cryptid 1).
    /// Unreadable means "yes": a doubt never blocks.
    static func mainBinaryIsEncrypted() -> Bool {
        guard let header = _dyld_get_image_header(0) else { return true }
        var cursor = UnsafeRawPointer(header).advanced(by: MemoryLayout<mach_header_64>.size)
        for _ in 0..<header.pointee.ncmds {
            let command = cursor.assumingMemoryBound(to: load_command.self).pointee
            if command.cmd == LC_ENCRYPTION_INFO_64 {
                return cursor.assumingMemoryBound(to: encryption_info_command_64.self).pointee.cryptid != 0
            }
            cursor = cursor.advanced(by: Int(command.cmdsize))
        }
        // No encryption command at all: Mac and Simulator binaries. Only iOS uses this check.
        return true
    }
}
