// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// The findings the person chose to keep as they are. Only signal ids such as "boot-time", never
/// a value. One small file on this device, excluded from backups and removed by Clear history.
enum KeptFindings {
    static var fileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appending(path: "kept-findings.json")
    }

    static func load() -> Set<String> {
        guard let data = try? Data(contentsOf: fileURL), let ids = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return Set(ids)
    }

    static func save(_ ids: Set<String>) {
        guard !ids.isEmpty else { forget(); return }
        guard let data = try? JSONEncoder().encode(ids.sorted()) else { return }
        var url = fileURL
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard (try? data.write(to: url, options: [.atomic, .completeFileProtection])) != nil else { return }
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
    }

    static func forget() { try? FileManager.default.removeItem(at: fileURL) }
}
