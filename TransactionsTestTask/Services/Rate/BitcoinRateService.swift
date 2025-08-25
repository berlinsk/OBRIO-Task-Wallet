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
    
    var onRateUpdate: ((Double) -> Void)? { get set }
    var ratePublisher: AnyPublisher<RateEntity, Never> { get }
    func startUpdating(every seconds: TimeInterval)
    func stop()
    func refreshNow() //instantly
}

final class BitcoinRateServiceImpl {
    
    var onRateUpdate: ((Double) -> Void)?
    
    private let api: RateAPIClient
    private let cache: RateCacheRepository
    private let analytics: AnalyticsService
    
    private var bag = Set<AnyCancellable>()
    private let subject = CurrentValueSubject<RateEntity?, Never>(nil) // current rate
    private var timerCancellable: AnyCancellable?
    
    init(api: RateAPIClient, cache: RateCacheRepository, analytics:AnalyticsService) {
        self.api = api
        self.cache = cache
        self.analytics=analytics
        if let cached = try? cache.load() {
            subject.send(cached)
        }
    }
    
    var ratePublisher: AnyPublisher<RateEntity, Never> {
        subject.compactMap { $0 }.removeDuplicates {
            $0.usdPerBtc == $1.usdPerBtc
        }.eraseToAnyPublisher()
    }
}

extension BitcoinRateServiceImpl: BitcoinRateService {

    func refreshNow() {
        fetchOnce()
    }
    
    func startUpdating(every seconds: TimeInterval) {
        let tick = Timer.publish(every: seconds, on: .main, in: .common)
            .autoconnect()
            .map { _ in () }
            .prepend(()) // immediate tick

        // calling api on each tick
        timerCancellable = tick
            .flatMap { [api] _ in api.fetchBtcUsd()
                .catch { _ in
                    Empty<Decimal, Never>()
                }
            }
            .sink { [weak self] dec in
                guard let self else {
                    return
                }
                let entity = RateEntity(usdPerBtc: dec, updatedAt: Date())
                try? self.cache.save(entity)
                self.subject.send(entity)
                
                // log
                self.analytics.trackEvent(
                    name: "bitcoin_rate_update",
                    parameters: [
                        "rate":"\(dec)",
                        "ts":"\(entity.updatedAt.timeIntervalSince1970)"
                    ]
                )
                
                self.onRateUpdate?(NSDecimalNumber(decimal: dec).doubleValue)
            }
    }

    func stop() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }
}

private extension BitcoinRateServiceImpl {
    func fetchOnce() {
        api.fetchBtcUsd()
            .catch { _ in
                Empty<Decimal, Never>()
            }
            .sink { [weak self] dec in
                guard let self else {
                    return
                }
                let entity = RateEntity(usdPerBtc: dec, updatedAt: Date())
                try? self.cache.save(entity)
                self.subject.send(entity)
                self.analytics.trackEvent(
                    name: "bitcoin_rate_update",
                    parameters: [
                        "rate":"\(dec)",
                        "ts":"\(entity.updatedAt.timeIntervalSince1970)"
                    ]
                )
                self.onRateUpdate?(NSDecimalNumber(decimal: dec).doubleValue)
            }
            .store(in: &bag)
    }
}
