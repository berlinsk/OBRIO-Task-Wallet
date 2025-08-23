//
//  AddTransactionViewModel.swift
//  TransactionsTestTask
//
//  Created by Берлинский Ярослав Владленович on 24.08.2025.
//

import Foundation
import Combine

protocol AddTransactionViewModel {
    // output
    var didAdd: AnyPublisher<Void, Never> { get }
    var errorText: AnyPublisher<String, Never> { get }

    // input
    func addExpense(amountBTC: Decimal, category: Category)
}

final class AddTransactionViewModelImpl: AddTransactionViewModel {
    private let addExpenseUC: AddExpenseUseCase
    private let trackEvent: TrackEventUseCase

    private let didAddSubject = PassthroughSubject<Void, Never>()
    private let errorSubject = PassthroughSubject<String, Never>()

    init(addExpense: AddExpenseUseCase,
         trackEvent: TrackEventUseCase) {
        self.addExpenseUC = addExpense
        self.trackEvent = trackEvent
    }

    // output
    var didAdd: AnyPublisher<Void, Never> { didAddSubject.eraseToAnyPublisher() }
    var errorText: AnyPublisher<String, Never> { errorSubject.eraseToAnyPublisher() }

    // input
    func addExpense(amountBTC: Decimal, category: Category) {
        do {
            try addExpenseUC.execute( //save expense to repo
                amountBTC: amountBTC,
                category: category,
                date: Date()
            )
            trackEvent.execute( // expence log
                "expense_add",
                [
                    "amount_btc":"\(amountBTC)",
                    "category":category.rawValue
                ]
            )
            NotificationCenter.default.post(name: .transactionsChanged, object: nil) //fire notification
            didAddSubject.send(())
        } catch {
            errorSubject.send("add expense failed: \(error)")
        }
    }
}
