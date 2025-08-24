//
//  BitcoinRateServiceTests.swift
//  TransactionsTestTaskTests
//
//  Created by Берлинский Ярослав Владленович on 24.08.2025.
//

import XCTest
import Combine
@testable import TransactionsTestTask

// MARK: Mocks

// api client
private final class RateAPIClientMock: RateAPIClient {
    enum Mode {
        case success(Decimal)
        case failure(Error)
    }
    
    var mode: Mode
    
    init(mode: Mode) {
        self.mode = mode
    }
    
    func fetchBtcUsd() -> AnyPublisher<Decimal, Error> {
        switch mode {
        case .success(let d):
            return Just(d).setFailureType(to: Error.self).eraseToAnyPublisher()
        case .failure(let e):
            return Fail(error: e).eraseToAnyPublisher()
        }
    }
}

//for saving/loading rates
private final class RateCacheRepositoryMock: RateCacheRepository {
    var saved: RateEntity?
    var loaded: RateEntity?
    
    func load() throws -> RateEntity? {
        loaded
    }
    
    func save(_ rate: RateEntity) throws {
        saved = rate
    }
}

//mock analytics service with event capturing
private final class AnalyticsServiceMock: AnalyticsService {
    struct Item {
        let name:String
        let params:[String:String]
    }
    
    private let subject = PassthroughSubject<AnalyticsEvent,Never>()
    
    var eventsPublisher: AnyPublisher<AnalyticsEvent, Never> {
        subject.eraseToAnyPublisher()
    }
    
    private(set) var tracked: [Item] = []
    
    func trackEvent(name: String, parameters: [String : String]) {
        tracked.append(.init(name: name, params: parameters))
        subject.send(.init(name: name, parameters: parameters, date: Date()))
    }
    
    func events(name: String?, from: Date?, to: Date?) -> [AnalyticsEvent] {
        []
    }
    
    func eventsCount() -> Int {
        tracked.count
    }
    
    func allEvents() -> [AnalyticsEvent] {
        []
    }
    
    func clear() {
        tracked.removeAll()
    }
    
    func removeOlderThan(_ date: Date) {}
    
    func exportJSON(prettyPrinted: Bool) throws -> Data {
        Data()
    }
    
    func importJSON(_ data: Data) throws {}
}

// MARK: - Tests
final class BitcoinRateServiceTests: XCTestCase {
    private var bag = Set<AnyCancellable>()
    
    func test_init_emitsCachedValue_ifExists() throws {
        let cached = RateEntity(usdPerBtc: Decimal(string: "77777.77")!, updatedAt: Date()) //given cached value present
        let api = RateAPIClientMock(mode: .success(Decimal(1)))
        let cache = RateCacheRepositoryMock()
        cache.loaded = cached
        let analytics = AnalyticsServiceMock()
        let sut = BitcoinRateServiceImpl(api: api, cache: cache, analytics: analytics)

        let exp = expectation(description: "emits cached on init")
        var received: RateEntity?
        sut.ratePublisher
            .sink { v in
                received = v
                exp.fulfill()
            }
            .store(in: &bag)

        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(received?.usdPerBtc, cached.usdPerBtc)
    }

    func test_refreshNow_emits_saves_and_tracks() {
        //given success api with fixed rate
        let api = RateAPIClientMock(mode: .success(Decimal(string: "65000.42")!))
        let cache = RateCacheRepositoryMock()
        let analytics = AnalyticsServiceMock()
        let sut = BitcoinRateServiceImpl(api: api, cache: cache, analytics: analytics)

        let exp = expectation(description: "publisher emits")
        var received: RateEntity?

        sut.ratePublisher
            .sink { v in
                received = v
                exp.fulfill()
            }
            .store(in: &bag)

        sut.refreshNow()

        //check emission, cache save, analytics track
        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(received?.usdPerBtc, Decimal(string: "65000.42"))
        XCTAssertEqual(cache.saved?.usdPerBtc, Decimal(string: "65000.42"))
        XCTAssertEqual(analytics.tracked.first?.name, "bitcoin_rate_update")
        XCTAssertEqual(analytics.tracked.first?.params["rate"], "65000.42")
    }

    func test_startUpdating_hasImmediateTick_viaPrepend() {
        //given mock api with simple rate
        let api = RateAPIClientMock(mode: .success(Decimal(12345)))
        let cache = RateCacheRepositoryMock()
        let analytics = AnalyticsServiceMock()
        let sut = BitcoinRateServiceImpl(api: api, cache: cache, analytics: analytics)

        let exp = expectation(description: "immediate emission")
        var count = 0
        sut.ratePublisher.sink { _ in
            count += 1
            exp.fulfill()
        }.store(in: &bag)

        sut.startUpdating(every: 10) //big interval

        //first tick should fire instantly
        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(count, 1)
        XCTAssertEqual(cache.saved?.usdPerBtc, Decimal(12345))
        XCTAssertEqual(analytics.eventsCount(), 1)
        sut.stop()
    }
    
    func test_stop_preventsFurtherEmissions() {
        let api = RateAPIClientMock(mode: .success(Decimal(999)))
        let cache = RateCacheRepositoryMock()
        let analytics = AnalyticsServiceMock()
        let sut = BitcoinRateServiceImpl(api: api, cache: cache, analytics: analytics)

        let firstExp = expectation(description: "first immediate emission")
        sut.ratePublisher
            .prefix(1)
            .sink { _ in firstExp.fulfill() }
            .store(in: &bag)

        //deny emissions
        let noMoreExp = expectation(description: "no further emissions after stop")
        noMoreExp.isInverted = true
        sut.ratePublisher
            .dropFirst(1)
            .sink { _ in noMoreExp.fulfill() }
            .store(in: &bag)

        sut.startUpdating(every: 0.05)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            sut.stop()
        }

        wait(for: [firstExp], timeout: 1.0)

        wait(for: [noMoreExp], timeout: 0.2) //nothing arrived after stop
    }

    //given failing api client
    func test_refreshNow_ignoresFailures_noEmission_noTracking() {
        enum E: Error {
            case oops
        }
        
        let api = RateAPIClientMock(mode: .failure(E.oops))
        let cache = RateCacheRepositoryMock()
        let analytics = AnalyticsServiceMock()
        let sut = BitcoinRateServiceImpl(api: api, cache: cache, analytics: analytics)

        let exp = expectation(description: "no emission")
        exp.isInverted = true
        sut.ratePublisher.sink { _ in
            exp.fulfill()
        }.store(in: &bag)

        sut.refreshNow()

        //no cache no events
        wait(for: [exp], timeout: 0.5)
        XCTAssertNil(cache.saved)
        XCTAssertTrue(analytics.tracked.isEmpty)
    }

    //given api always returns same rate
    func test_ratePublisher_deduplicatesSameRate() {
        // given same value each call
        let api = RateAPIClientMock(mode: .success(Decimal(111)))
        let cache = RateCacheRepositoryMock()
        let analytics = AnalyticsServiceMock()
        let sut = BitcoinRateServiceImpl(api: api, cache: cache, analytics: analytics)

        var emissions = 0
        let exp = expectation(description: "only one emission for same rate twice")
        exp.expectedFulfillmentCount = 1

        sut.ratePublisher.sink { _ in
            emissions += 1
            exp.fulfill()
        }.store(in: &bag)

        //called twice with same value
        sut.refreshNow()
        sut.refreshNow()

        // publisher dedups but analytics tracks twice
        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(emissions, 1, "removeDuplicates(by usdPerBtc) should suppress second identical emission")
        XCTAssertEqual(analytics.eventsCount(), 2)
    }

    //given legacy callback is set
    func test_legacyCallback_isCalled() {
        let api = RateAPIClientMock(mode: .success(Decimal(222)))
        let cache = RateCacheRepositoryMock()
        let analytics = AnalyticsServiceMock()
        let sut = BitcoinRateServiceImpl(api: api, cache: cache, analytics: analytics)

        let exp = expectation(description: "legacy callback")
        sut.onRateUpdate = { value in
            XCTAssertEqual(value, 222.0, accuracy: 0.0001)
            exp.fulfill()
        }

        sut.refreshNow()
        wait(for: [exp], timeout: 1.0)
    }
}
