//
//  RateControlUseCases.swift
//  TransactionsTestTask
//
//  Created by Берлинский Ярослав Владленович on 23.08.2025.
//

import Foundation

protocol StartRateUpdatesUseCase {
    func start(every seconds:TimeInterval)
}
protocol RefreshRateNowUseCase {
    func execute()
}

final class StartRateUpdatesUseCaseImpl: StartRateUpdatesUseCase {
    private let svc: BitcoinRateService
    init(svc: BitcoinRateService) {
        self.svc = svc
    }
    func start(every seconds:TimeInterval) { svc.startUpdating(every: seconds) }
}

final class RefreshRateNowUseCaseImpl: RefreshRateNowUseCase {
    private let svc: BitcoinRateService
    init(svc: BitcoinRateService) {
        self.svc = svc
    }
    func execute() { svc.refreshNow() }
}
