//
//  StartRateUpdatesUseCase.swift
//  TransactionsTestTask
//
//  Created by Берлинский Ярослав Владленович on 23.08.2025.
//

import Foundation

protocol StartRateUpdatesUseCase {
    func start(every seconds:TimeInterval)
}

final class StartRateUpdatesUseCaseImpl: StartRateUpdatesUseCase {
    private let svc: BitcoinRateService
    
    init(svc: BitcoinRateService) {
        self.svc = svc
    }
}

extension StartRateUpdatesUseCaseImpl {
    func start(every seconds:TimeInterval) {
        svc.startUpdating(every: seconds)
    }
}
