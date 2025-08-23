//
//  BitcoinRateService.swift
//  TransactionsTestTask
//
//

import Foundation
import Combine
/// Rate Service should fetch data from https://api.coindesk.com/v1/bpi/currentprice.json (I decided to use CoinBase)
/// Fetching should be scheduled with dynamic update interval
/// Rate should be cached for the offline mode
/// Every successful fetch should be logged with analytics service
/// The service should be covered by unit tests
protocol BitcoinRateService: AnyObject {
    
    var onRateUpdate: ((Double) -> Void)? { get set } // legacy callback support
    var ratePublisher: AnyPublisher<RateEntity, Never> { get } // modern combine publisher
    func startUpdating(every seconds: TimeInterval) //start polling
    func stop() //stop polling
}

final class BitcoinRateServiceImpl {
    
    var onRateUpdate: ((Double) -> Void)?
    
    private let api: RateAPIClient
    private let cache: RateCacheRepository
    private var bag = Set<AnyCancellable>()
    private let subject = CurrentValueSubject<RateEntity?, Never>(nil) // holds current rate
    private var timerCancellable: AnyCancellable?
    
    init(api: RateAPIClient, cache: RateCacheRepository) {
        self.api = api
        self.cache = cache
        if let cached = try? cache.load() { // load cached value from db at startup
            subject.send(cached)
        }
    }
    
    // publisher that emits rates without duplicates(ignores same value)
    var ratePublisher: AnyPublisher<RateEntity, Never> {
        subject.compactMap { $0 }.removeDuplicates { $0.usdPerBtc == $1.usdPerBtc }.eraseToAnyPublisher()
    }
    
    // periodic updates
    func startUpdating(every seconds: TimeInterval) {
        let tick = Timer.publish(every: seconds, on: .main, in: .common) //fires every N sec
            .autoconnect()
            .map { _ in () }
            .prepend(()) // triggers immediate tick

        // on each tick it calls api, map result goes to RateEnitity
        timerCancellable = tick
            .flatMap { [api] _ in api.fetchBtcUsd().catch { _ in Empty<Decimal, Never>() } } //skip if fail
            .sink { [weak self] dec in
                guard let self else { return }
                let entity = RateEntity(usdPerBtc: dec, updatedAt: Date())
                try? self.cache.save(entity) // store to coredata cache
                self.subject.send(entity) // send new value to subscribers
                self.onRateUpdate?(NSDecimalNumber(decimal: dec).doubleValue) // fire legacy cb
            }
    }

    // stop updates, start cleaning timer
    func stop() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }
}

extension BitcoinRateServiceImpl: BitcoinRateService {
    
}
