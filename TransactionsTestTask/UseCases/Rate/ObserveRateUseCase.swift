//
//  ObserveRateUseCase.swift
//  TransactionsTestTask
//
//  Created by Берлинский Ярослав Владленович on 23.08.2025.
//

import Foundation
import Combine

protocol ObserveRateUseCase {
    var publisher: AnyPublisher<RateEntity,Never> { get }
}

final class ObserveRateUseCaseImpl: ObserveRateUseCase {
    private let rateService: BitcoinRateService
    
    init(rateService: BitcoinRateService) {
        self.rateService = rateService
    }
    
    var publisher: AnyPublisher<RateEntity,Never> {
        rateService.ratePublisher
    }
}

extension ObserveRateUseCaseImpl {}
