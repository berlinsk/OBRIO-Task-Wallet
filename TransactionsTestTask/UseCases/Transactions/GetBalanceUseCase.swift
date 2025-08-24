//
//  GetBalanceUseCase.swift
//  TransactionsTestTask
//
//  Created by Берлинский Ярослав Владленович on 23.08.2025.
//

import Foundation

protocol GetBalanceUseCase {
    func execute() throws -> Decimal
}

final class GetBalanceUseCaseImpl: GetBalanceUseCase {
    private let repo: TransactionsRepository
    
    init(repo: TransactionsRepository) {
        self.repo = repo
    }
}

extension GetBalanceUseCaseImpl {
    func execute() throws -> Decimal {
        let sats = try repo.totalBalanceSats()
        return Money.btc(fromSats: sats)
    }
}
