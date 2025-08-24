//
//  RefreshRateNowUseCase.swift
//  TransactionsTestTask
//
//  Created by Берлинский Ярослав Владленович on 24.08.2025.
//

import Foundation

protocol RefreshRateNowUseCase {
    func execute()
}

final class RefreshRateNowUseCaseImpl: RefreshRateNowUseCase {
    private let svc: BitcoinRateService
    
    init(svc: BitcoinRateService) {
        self.svc = svc
    }
}

extension RefreshRateNowUseCaseImpl {
    func execute() {
        svc.refreshNow()
    }
}
