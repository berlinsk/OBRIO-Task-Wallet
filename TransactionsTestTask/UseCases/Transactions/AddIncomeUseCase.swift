//
//  AddIncomeUseCase.swift
//  TransactionsTestTask
//
//  Created by Берлинский Ярослав Владленович on 23.08.2025.
//

import Foundation

protocol AddIncomeUseCase {
    func execute(amountBTC:Decimal, date:Date) throws
}

final class AddIncomeUseCaseImpl: AddIncomeUseCase {
    private let repo: TransactionsRepository
    
    init(repo: TransactionsRepository) {
        self.repo = repo
    }
}

extension AddIncomeUseCaseImpl {
    func execute(amountBTC:Decimal, date:Date) throws {
        let sats = Money.sats(fromBTC: amountBTC)
        try repo.add(amountSats: sats, type: .income, category: nil, date: date)
    }
}
