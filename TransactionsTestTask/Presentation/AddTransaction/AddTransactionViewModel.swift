//
//  AddTransactionViewModel.swift
//  TransactionsTestTask
//
//  Created by Берлинский Ярослав Владленович on 24.08.2025.
//

import Foundation
import Combine

protocol AddTransactionViewModel {
    var didAdd: AnyPublisher<Void, Never> { get }
    var errorText: AnyPublisher<String, Never> { get }

    func addExpense(amountBTC: Decimal, category: TransactionCategory)
}

final class AddTransactionViewModelImpl: AddTransactionViewModel {
    private let addExpenseUC: AddExpenseUseCase
    private let trackEvent: TrackEventUseCase

    private let didAddSubject = PassthroughSubject<Void, Never>()
    private let errorSubject = PassthroughSubject<String, Never>()

    init(addExpense: AddExpenseUseCase, trackEvent: TrackEventUseCase) {
        self.addExpenseUC = addExpense
        self.trackEvent = trackEvent
    }

    // output
    var didAdd: AnyPublisher<Void, Never> {
        didAddSubject.eraseToAnyPublisher()
    }
    var errorText: AnyPublisher<String, Never> {
        errorSubject.eraseToAnyPublisher()
    }
}

extension AddTransactionViewModelImpl {
    // input
    func addExpense(amountBTC: Decimal, category: TransactionCategory) {
        do {
            try addExpenseUC.execute(
                amountBTC: amountBTC,
                category: category,
                date: Date()
            )
            trackEvent.execute( //expence log
                "expense_add",
                [
                    "amount_btc":"\(amountBTC)",
                    "category":category.rawValue
                ]
            )
            NotificationCenter.default.post(name: .transactionsChanged, object: nil)
            didAddSubject.send(())
        } catch {
            errorSubject.send("add expense failed: \(error)")
        }
    }
}
