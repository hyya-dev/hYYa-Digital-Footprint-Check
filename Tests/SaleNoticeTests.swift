// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Testing
import Foundation
@testable import FootprintInspector

struct SaleNoticeTests {
    private let sale = SaleNotice.current
    private let day: TimeInterval = 24 * 3600

    @Test func datesMatchTheSaleFile() {
        let f = ISO8601DateFormatter()
        #expect(sale.start == f.date(from: "2026-11-24T00:00:00Z"))
        #expect(sale.end == f.date(from: "2026-12-31T23:59:59Z"))
    }

    @Test func onlyDuringTheSale() {
        #expect(!SaleNotice.isDue(seen: nil, now: sale.start.addingTimeInterval(-1)))
        #expect(SaleNotice.isDue(seen: nil, now: sale.start.addingTimeInterval(day)))
        #expect(!SaleNotice.isDue(seen: nil, now: sale.end.addingTimeInterval(1)))
    }

    @Test func onceOnly() {
        #expect(!SaleNotice.isDue(seen: sale.id, now: sale.start.addingTimeInterval(day)))
    }

    @Test func neverNamesThisAppOrAPrice() {
        #expect(!sale.apps.contains { $0.name.localizedCaseInsensitiveContains("Footprint") })
        #expect(!(sale.title + sale.body).contains("$"))
        #expect(sale.apps.count == 4)
    }
}
