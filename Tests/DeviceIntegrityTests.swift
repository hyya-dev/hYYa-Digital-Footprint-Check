// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Testing
@testable import FootprintInspector

struct DeviceIntegrityTests {
    /// A normal store install: nothing found.
    func clean() -> DeviceIntegrity.Probe {
        .init(fileExists: { _ in false },
              loadedImages: { ["/usr/lib/libSystem.B.dylib", "/System/Library/Frameworks/SwiftUI.framework/SwiftUI"] },
              isTraced: { false }, hasProvisioningProfile: false, isEncrypted: true, isTestFlight: false,
              signatureIsIntact: { true })
    }

    @Test func aNormalDeviceRuns() {
        #expect(DeviceIntegrity.problem(clean(), iOS: true) == nil)
        #expect(DeviceIntegrity.problem(clean(), iOS: false) == nil)
    }

    @Test func generalUnixFilesAreNotAJailbreak() {
        var p = clean(); p.fileExists = { ["/bin/bash", "/usr/sbin/sshd", "/bin/sh"].contains($0) }
        #expect(DeviceIntegrity.problem(p, iOS: true) == nil)
    }

    @Test func aJailbreakIsFound() {
        var p = clean(); p.fileExists = { $0 == "/var/jb" }
        #expect(DeviceIntegrity.problem(p, iOS: true) == IntegrityFinding(problem: .modifiedSystem, detail: "a rootless jailbreak"))
        // The Mac has /bin/bash and the like as standard: never a jailbreak there.
        p.fileExists = { _ in true }
        #expect(DeviceIntegrity.problem(p, iOS: false) == nil)
    }

    @Test func hookingToolsAreFound() {
        var p = clean(); p.loadedImages = { ["/usr/lib/FridaGadget.dylib"] }
        #expect(DeviceIntegrity.problem(p, iOS: true) == IntegrityFinding(problem: .hookingTool, detail: "FridaGadget.dylib"))
        p = clean(); p.loadedImages = { ["/Library/Application Support/x/libsubstitute.dylib"] }
        #expect(DeviceIntegrity.problem(p, iOS: false)?.problem == .hookingTool)
        // Folder names never count, only the library's own file name.
        p = clean(); p.loadedImages = { ["/private/var/containers/Bundle/Application/frida-x/App.app/App"] }
        #expect(DeviceIntegrity.problem(p, iOS: true) == nil)
    }

    @Test func aDebuggerIsFound() {
        var p = clean(); p.isTraced = { true }
        #expect(DeviceIntegrity.problem(p, iOS: true)?.problem == .debugger)
    }

    @Test func aResignedCopyIsFound() {
        var p = clean(); p.hasProvisioningProfile = true
        // A profile alone is not enough: the copy must also be decrypted.
        #expect(DeviceIntegrity.problem(p, iOS: true) == nil)
        p.isEncrypted = false
        #expect(DeviceIntegrity.problem(p, iOS: true)?.problem == .modifiedApp)
        // TestFlight installs are the owner's own test builds.
        p.isTestFlight = true
        #expect(DeviceIntegrity.problem(p, iOS: true) == nil)
        p = clean(); p.signatureIsIntact = { false }
        #expect(DeviceIntegrity.problem(p, iOS: false)?.problem == .modifiedApp)
    }

    @Test func debugBuildsAreNeverChecked() {
        #expect(!DeviceIntegrity.isEnforced)
        #expect(DeviceIntegrity.current() == nil)
    }
}
