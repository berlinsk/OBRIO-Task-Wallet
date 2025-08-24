//
//  UseCaseFactory.swift
//  TransactionsTestTask
//
//  Created by Берлинский Ярослав Владленович on 25.08.2025.
//

import Foundation

struct UseCaseFactory {
    func observeRate() -> ObserveRateUseCase {
        ServicesAssembler.observeRateUseCase()
    }
    func getBalance() -> GetBalanceUseCase {
        ServicesAssembler.getBalanceUseCase()
    }
    func addIncome() -> AddIncomeUseCase {
        ServicesAssembler.addIncomeUseCase()
    }
    func addExpense() -> AddExpenseUseCase {
        ServicesAssembler.addExpenseUseCase()
    }
    func getTransactionsPage() -> GetTransactionsForPageUseCase {
        ServicesAssembler.getTransactionsPageUseCase()
    }
    func trackEvent() -> TrackEventUseCase {
        ServicesAssembler.trackEventUseCase()
    }
}
