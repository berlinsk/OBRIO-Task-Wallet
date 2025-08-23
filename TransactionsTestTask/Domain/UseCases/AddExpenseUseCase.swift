//
//  AddExpenseUseCase.swift
//  TransactionsTestTask
//
//  Created by Берлинский Ярослав Владленович on 23.08.2025.
//

import Foundation

protocol AddExpenseUseCase {
    func execute(amountBTC:Decimal, category:Category, date:Date) throws
}

final class AddExpenseUseCaseImpl: AddExpenseUseCase {
    private let repo: TransactionsRepository
    init(repo: TransactionsRepository) {
        self.repo = repo
    }

    func execute(amountBTC:Decimal, category:Category, date:Date) throws {
        let sats = Money.sats(fromBTC: amountBTC)
        try repo.add(amountSats: sats, type: .expense, category: category, date: date)
    }
}
