//
//  AnalyticsSevriceTests.swift
//  TransactionsTestTaskTests
//
//  Created by Берлинский Ярослав Владленович on 24.08.2025.
//

import XCTest
import Combine
@testable import TransactionsTestTask

// MARK: - Tests
final class AnalyticsServiceTests: XCTestCase {

    private var svc: AnalyticsServiceImpl!
    private var bag = Set<AnyCancellable>()

    override func setUp() {
        super.setUp()
        svc = AnalyticsServiceImpl()
    }

    override func tearDown() {
        bag.removeAll()
        svc = nil
        super.tearDown()
    }

    // trackEvent store the item
    func test_trackEvent_appends_and_publishes() {
        let exp = expectation(description: "publisher emits")
        var received: AnalyticsEvent?

        svc.eventsPublisher
            .sink { ev in
                received = ev
                exp.fulfill()
            }
            .store(in: &bag)

        svc.trackEvent(name: "test_event", parameters: ["k":"v"])

        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(svc.eventsCount(), 1)
        XCTAssertEqual(received?.name, "test_event")
        XCTAssertEqual(received?.parameters["k"], "v")

        let all = svc.allEvents()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.name, "test_event")
    }

    //filtering by name and date range
    func test_events_filtering_by_name_and_date() throws {
        let d1 = makeDate(2024,1,1,10,0,0)
        let d2 = makeDate(2024,1,2,12,0,0)
        let d3 = makeDate(2024,1,3,14,0,0)

        let seed: [AnalyticsEvent] = [
            .init(name: "a", parameters: ["p":"1"], date: d1),
            .init(name: "b", parameters: ["p":"2"], date: d2),
            .init(name: "a", parameters: ["p":"3"], date: d3),
        ]
        try svc.importJSON(encode(seed))

        //by name
        let onlyA = svc.events(name: "a", from: nil, to: nil)
        XCTAssertEqual(onlyA.count, 2)
        XCTAssertEqual(onlyA.map(\.parameters["p"]), ["1","3"])

        //by range
        let middle = svc.events(name: nil, from: makeDate(2024,1,2,0,0,0), to: makeDate(2024,1,3,0,0,0))
        XCTAssertEqual(middle.count, 1)
        XCTAssertEqual(middle.first?.name, "b")

        //by name+range
        let aInRange = svc.events(name: "a", from: makeDate(2024,1,2,23,59,59), to: makeDate(2024,1,4,0,0,0))
        XCTAssertEqual(aInRange.count, 1)
        XCTAssertEqual(aInRange.first?.parameters["p"], "3")
    }

    // allEvents sorted by date asc
    func test_allEvents_sortedAscending() throws {
        let d1 = makeDate(2024,1,10,8,0,0)
        let d0 = makeDate(2024,1,1,8,0,0)
        let d2 = makeDate(2024,1,20,8,0,0)
        try svc.importJSON(encode([
            .init(name: "x", parameters: [:], date: d1),
            .init(name: "y", parameters: [:], date: d0),
            .init(name: "z", parameters: [:], date: d2),
        ]))

        let list = svc.allEvents()
        XCTAssertEqual(list.map(\.date), [d0, d1, d2])
    }

    // remove all, removeOlderthan drops only older items
    func test_clear_and_removeOlderThan() throws {
        let d1 = makeDate(2024,1,1,0,0,0)
        let d2 = makeDate(2024,1,10,0,0,0)
        let d3 = makeDate(2024,1,20,0,0,0)
        try svc.importJSON(encode([
            .init(name: "e1", parameters: [:], date: d1),
            .init(name: "e2", parameters: [:], date: d2),
            .init(name: "e3", parameters: [:], date: d3),
        ]))

        svc.removeOlderThan(makeDate(2024,1,15,0,0,0))
        let names = svc.allEvents().map(\.name)
        XCTAssertEqual(names, ["e3"])

        svc.clear()
        XCTAssertEqual(svc.eventsCount(), 0)
        XCTAssertTrue(svc.allEvents().isEmpty)
    }

    // export/import roundtrip(to keep data intact(including dates))
    func test_export_import_roundtrip() throws {
        let events: [AnalyticsEvent] = [
            .init(name: "n1", parameters: ["a":"1"], date: makeDate(2024,5,5,5,5,5)),
            .init(name: "n2", parameters: ["b":"2"], date: makeDate(2024,6,6,6,6,6)),
        ]
        try svc.importJSON(encode(events))

        let dataPretty = try svc.exportJSON(prettyPrinted: true)
        XCTAssertFalse(dataPretty.isEmpty)

        let other = AnalyticsServiceImpl()
        try other.importJSON(dataPretty)

        XCTAssertEqual(other.eventsCount(), events.count)
        XCTAssertEqual(other.allEvents(), events)
    }

    // emission for every event
    func test_eventsPublisher_multipleEmissions() {
        let exp = expectation(description: "two emissions")
        exp.expectedFulfillmentCount = 2
        var got = 0

        svc.eventsPublisher
            .sink { _ in
                got += 1
                exp.fulfill()
            }
            .store(in: &bag)

        svc.trackEvent(name: "a", parameters: [:])
        svc.trackEvent(name: "b", parameters: [:])

        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(got, 2)
        XCTAssertEqual(svc.eventsCount(), 2)
    }

    //quick concurrency smoke
    func test_threadSafety_trackEvent_many() {
        let group = DispatchGroup()
        let total = 200
        for i in 0..<total {
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                self.svc.trackEvent(name: "n\(i)", parameters: ["i":"\(i)"])
                group.leave()
            }
        }
        XCTAssertEqual(group.wait(timeout: .now() + 2.0), .success)
        XCTAssertEqual(svc.eventsCount(), total)
    }

    private func makeDate(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int, _ s: Int) -> Date {
        var comps = DateComponents()
        comps.year = y
        comps.month = m
        comps.day = d
        comps.hour = h
        comps.minute = min
        comps.second = s
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal.date(from: comps)!
    }

    private func encode(_ events: [AnalyticsEvent]) throws -> Data {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        return try enc.encode(events)
    }
}
