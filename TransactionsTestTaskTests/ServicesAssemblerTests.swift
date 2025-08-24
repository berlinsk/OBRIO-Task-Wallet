//
//  ServicesAssemblerTests.swift
//  TransactionsTestTaskTests
//
//  Created by Берлинский Ярослав Владленович on 24.08.2025.
//

import XCTest
import Combine
@testable import TransactionsTestTask

// CoinBase stub via urlprotocol
private final class MockURLProtocol: URLProtocol {
    static var stubJSON: String = #"{"data":{"rates":{"USD":"65000.00"}}}"#
    static var status: Int = 200

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host?.contains("api.coinbase.com") == true
    }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let client = client else { return }
        let url = request.url ?? URL(string: "https://api.coinbase.com")!
        let resp = HTTPURLResponse(
            url: url,
            statusCode: Self.status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type":"application/json"]
        )!
        client.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
        client.urlProtocol(self, didLoad: Data(Self.stubJSON.utf8))
        client.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}

    static func setRate(_ dec: Decimal) {
        Self.stubJSON = #"{"data":{"rates":{"USD":"\#(dec)"}}}"# //putting the number as a string without formattin(as the API would return)
    }
}

// MARK: - Tests
final class ServicesAssemblerTests: XCTestCase {
    private var bag = Set<AnyCancellable>()
    private var tick = 0

    private func uniqueRate() -> Decimal {
        tick += 1
        return Decimal(65000 + tick) + Decimal(string: "0.01")! //different values ​​in order to removeDuplicates not working
    }

    override func setUp() {
        super.setUp()
        URLProtocol.registerClass(MockURLProtocol.self)
        MockURLProtocol.status = 200
        MockURLProtocol.setRate(Decimal(64999)) //old value(so there is no replay of the new course)
        ServicesAssembler.analyticsService().clear()
    }

    override func tearDown() {
        bag.removeAll()
        URLProtocol.unregisterClass(MockURLProtocol.self)
        super.tearDown()
    }

    func test_makeHomeViewModel_returnsImplementation() {
        let vm = ServicesAssembler.makeHomeViewModel()
        XCTAssertTrue(vm is HomeViewModelImpl)
    }

    func test_makeAddTransactionViewModel_returnsImplementation() {
        let vm = ServicesAssembler.makeAddTransactionViewModel()
        XCTAssertTrue(vm is AddTransactionViewModelImpl)
    }

    func test_services_areSingletons() {
        let r1 = ServicesAssembler.transactionsRepository()
        let r2 = ServicesAssembler.transactionsRepository()
        XCTAssertTrue((r1 as AnyObject) === (r2 as AnyObject))

        let a1 = ServicesAssembler.analyticsService()
        let a2 = ServicesAssembler.analyticsService()
        XCTAssertTrue(a1 === a2)

        let s1 = ServicesAssembler.bitcoinRateService()
        let s2 = ServicesAssembler.bitcoinRateService()
        XCTAssertTrue(s1 === s2)
    }

    //count events only for a specific course
    func test_startRateObservers_logsForEachModule() {
        let analytics = ServicesAssembler.analyticsService()
        analytics.clear()

        let modules = 7
        ServicesAssembler.startRateObservers(count: modules)

        // issuing the rate R and waitingg(after, we count only events with rate=R)
        let R = uniqueRate()
        MockURLProtocol.setRate(R)
        ServicesAssembler.refreshRateNowUseCase().execute()
        spinRunLoop(0.35)

        let got = countModuleLogs(forRate: R, since: nil)
        XCTAssertGreaterThanOrEqual(got, modules, "AT LEAST \(modules) logs should come for one emission")
    }

    // repeated start should not increase the number of subscribers, the number of logs for R2 should match the number of logs for R1
    func test_startRateObservers_isIdempotent() {
        let analytics = ServicesAssembler.analyticsService()
        analytics.clear()

        let modules = 5
        ServicesAssembler.startRateObservers(count: modules)

        // 1st emission(we only count events with this value)
        let R1 = uniqueRate()
        MockURLProtocol.setRate(R1)
        ServicesAssembler.refreshRateNowUseCase().execute()
        spinRunLoop(0.35)
        let c1 = countModuleLogs(forRate: R1, since: nil)

        // restarting process should not add new subscribers
        ServicesAssembler.startRateObservers(count: modules)

        // 2nd emission(again we count only events with new value)
        let R2 = uniqueRate()
        MockURLProtocol.setRate(R2)
        ServicesAssembler.refreshRateNowUseCase().execute()
        spinRunLoop(0.35)
        let c2 = countModuleLogs(forRate: R2, since: nil)

        XCTAssertEqual(c2, c1, "restarting process should not add subscribers")
    }

    // MARK: - Helpers
    // get num of btc_rate_module_update with the specified rate
    private func countModuleLogs(forRate rate: Decimal, since from: Date?) -> Int {
        let all = ServicesAssembler.analyticsService()
            .events(name: "btc_rate_module_update", from: from, to: nil)

        return all.filter { ev in
            guard let s = ev.parameters["rate"], let dec = Decimal(string: s) else { return false }
            return dec == rate
        }.count
    }

    private func spinRunLoop(_ seconds: TimeInterval) {
        let until = Date().addingTimeInterval(seconds)
        while Date() < until {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
        }
    }
}
