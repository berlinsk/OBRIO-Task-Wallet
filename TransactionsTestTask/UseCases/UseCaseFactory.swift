//
//  UseCaseFactory.swift
//  TransactionsTestTask
//
//  Created by Берлинский Ярослав Владленович on 25.08.2025.
//

import Foundation

protocol UseCaseFactory {
    var observeRate: ObserveRateUseCase { get }
    var getBalance: GetBalanceUseCase { get }
    var addIncome: AddIncomeUseCase { get }
    var addExpense: AddExpenseUseCase { get }
    var getTransactionsPage: GetTransactionsForPageUseCase { get }
    var trackEvent: TrackEventUseCase { get }
}

struct UseCaseFactoryImpl: UseCaseFactory {
    var observeRate: ObserveRateUseCase {
        ServicesAssembler.observeRateUseCase()
    }
    var getBalance: GetBalanceUseCase {
        ServicesAssembler.getBalanceUseCase()
    }
    var addIncome: AddIncomeUseCase {
        ServicesAssembler.addIncomeUseCase()
    }
    var addExpense: AddExpenseUseCase {
        ServicesAssembler.addExpenseUseCase()
    }
    var getTransactionsPage: GetTransactionsForPageUseCase {
        ServicesAssembler.getTransactionsPageUseCase()
    }
    var trackEvent: TrackEventUseCase {
        ServicesAssembler.trackEventUseCase()
    }
}
