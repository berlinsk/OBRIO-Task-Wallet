//
//  ReachabilityServiceTests.swift
//  TransactionsTestTaskTests
//
//  Created by Берлинский Ярослав Владленович on 24.08.2025.
//

import XCTest
import Combine
@testable import TransactionsTestTask

// MARK: - Mock
final class ReachabilityMonitorMock: ReachabilityMonitor {
    var onUpdate: ((Bool) -> Void)?
    private(set) var started = false
    private(set) var cancelled = false

    func start(queue: DispatchQueue) {
        started = true
    }
    
    func cancel() {
        cancelled = true
    }

    func send(_ value: Bool) {
        onUpdate?(value)
    }
}

// MARK: Test
final class ReachabilityServiceTests: XCTestCase {

    private var bag = Set<AnyCancellable>()
    private var mock: ReachabilityMonitorMock!
    private var svc: ReachabilityService!

    override func setUp() {
        super.setUp()
        mock = ReachabilityMonitorMock()
        svc = ReachabilityService(monitor: mock)
    }

    override func tearDown() {
        bag.removeAll()
        svc = nil
        mock = nil
        super.tearDown()
    }

    // get 2 controlled values(initial false+true)
    func test_publisher_receivesMockedValues() {
        let exp = expectation(description: "receives 2 updates")
        exp.expectedFulfillmentCount = 2

        var received: [Bool] = []

        //catch initial false too(because without dropFirst)
        svc.publisher
            .sink { v in
                received.append(v)
                exp.fulfill()
            }
            .store(in: &bag)

        mock.send(true)
        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(received, [false, true])
    }

    //2 subscribers receive the same 1st new val
    func test_multipleSubscribers_getSameValue() {
        let e1 = expectation(description: "sub1 1 new value")
        let e2 = expectation(description: "sub2 2 new value")

        var v1: Bool?
        var v2: Bool?

        // take 1 value skiping initial false
        svc.publisher
            .dropFirst()
            .prefix(1)
            .sink { v in
                v1 = v
                e1.fulfill()
            }
            .store(in: &bag)

        svc.publisher
            .dropFirst()
            .prefix(1)
            .sink { v in
                v2 = v
                e2.fulfill()
            }
            .store(in: &bag)

        mock.send(true)

        wait(for: [e1, e2], timeout: 1.0)
        XCTAssertEqual(v1, true)
        XCTAssertEqual(v2, true)
    }

    //2 identical vals ​​in a row dont pass
    func test_removeDuplicates() {
        let exp = expectation(description: "initial false+first true only")
        exp.expectedFulfillmentCount = 2 //false val + truev al

        var values: [Bool] = []

        // check that 2ndvalue true dont arrive
        svc.publisher
            .sink { v in
                values.append(v)
                if values.count <= 2 {
                    exp.fulfill()
                }
            }
            .store(in: &bag)

        mock.send(true)
        mock.send(true)

        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(values, [false, true])
    }

    func test_deinit_cancelsMonitor() {
        let localMock = ReachabilityMonitorMock()
        weak var weakSvc: ReachabilityService?
        autoreleasepool {
            let s = ReachabilityService(monitor: localMock)
            weakSvc = s
        }
        XCTAssertNil(weakSvc)
        XCTAssertTrue(localMock.cancelled, "monitor should be cancelled on deinit")
    }

    func test_monitor_started() {
        XCTAssertTrue(mock.started, "monitor should start on init")
    }
}
