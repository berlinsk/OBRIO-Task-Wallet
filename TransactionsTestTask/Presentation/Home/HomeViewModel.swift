//
//  HomeViewModel.swift
//  TransactionsTestTask
//
//  Created by Берлинский Ярослав Владленович on 23.08.2025.
//

import Foundation
import Combine
import UIKit

protocol HomeViewModel {
    // outputs
    var rateText: AnyPublisher<String, Never> { get }
    var balanceText: AnyPublisher<String, Never> { get }
    var snapshot: AnyPublisher<NSDiffableDataSourceSnapshot<String, UUID>, Never> { get }

    // inputs
    func refreshBalance()
    func topUp(amountBTC: Decimal)
    
    // pagination +data access for vc
    func loadFirstPage()
    func loadNextPage()
    func currentSnapshot() -> NSDiffableDataSourceSnapshot<String, UUID>
    func transaction(at indexPath: IndexPath) -> TransactionEntity
    func sectionDate(for section: Int) -> Date
    func shouldLoadMore(near indexPath: IndexPath) -> Bool
}

final class HomeViewModelImpl: HomeViewModel {

    private let observeRate: ObserveRateUseCase
    private let getBalance: GetBalanceUseCase
    private let addIncome: AddIncomeUseCase
    private let trackEvent: TrackEventUseCase
    private let getPage: GetTransactionsPageUseCase
    
    // paging state
    private var txs: [TransactionEntity] = []
    private var sections: [Section] = []
    private var offset = 0
    private let pageSize = 20
    private var isLoading = false
    private var hasMore = true

    // outputs subjects
    private let balanceSubject = CurrentValueSubject<String, Never>("Balance: —")
    private let snapshotSubject = CurrentValueSubject<NSDiffableDataSourceSnapshot<String, UUID>, Never>(.init())

    private var bag = Set<AnyCancellable>()

    init(observeRate: ObserveRateUseCase,
         getBalance: GetBalanceUseCase,
         addIncome: AddIncomeUseCase,
         trackEvent: TrackEventUseCase,
         getPage: GetTransactionsPageUseCase) {
        self.observeRate = observeRate
        self.getBalance = getBalance
        self.addIncome = addIncome
        self.trackEvent = trackEvent
        self.getPage = getPage
    }

    // outputs
    var rateText: AnyPublisher<String, Never> {
        observeRate.publisher
            .map { rate in
                let nf = NumberFormatter()
                nf.numberStyle = .currency
                nf.currencyCode = "USD"
                return "1 BTC = \(nf.string(from: rate.usdPerBtc as NSDecimalNumber) ?? "-")"
            }
            .eraseToAnyPublisher()
    }

    var balanceText: AnyPublisher<String, Never> {
        balanceSubject.eraseToAnyPublisher()
    }
    
    var snapshot: AnyPublisher<NSDiffableDataSourceSnapshot<String, UUID>, Never> {
        snapshotSubject.eraseToAnyPublisher()
    }

    // inputs
    func refreshBalance() {
        do {
            let btc = try getBalance.execute()
            balanceSubject.send("Balance: \(Money.formatBTC(btc)) BTC")
        } catch {
            balanceSubject.send("Balance: —")
        }
    }

    func topUp(amountBTC: Decimal) {
        do {
            try addIncome.execute(
                amountBTC: amountBTC,
                date: Date()
            )
            trackEvent.execute( // top up opeartions log
                "topup_add",
                [
                    "amount_btc": "\(amountBTC)"
                ]
            )
            NotificationCenter.default.post(name: .transactionsChanged, object: nil) // reload
            refreshBalance()
        } catch {
            print("Top up failed:", error)
        }
    }
    
    func loadFirstPage() {
        offset = 0
        hasMore = true
        isLoading = false
        txs.removeAll()
        sections.removeAll()
        snapshotSubject.send(.init())
        loadNextPage()
    }
    
    func loadNextPage() {
        guard !isLoading, hasMore else { return }
        isLoading = true
        do {
            let page = try getPage.execute(offset: offset, limit: pageSize)
            txs.append(contentsOf: page)
            offset += page.count
            hasMore = page.count == pageSize

            regroup() //redrawing
            applySnapshot()
            
            // pagination log
            trackEvent.execute(
                "tx_page_loaded",
                [
                    "offset":"\(offset)",
                    "count":"\(page.count)"
                ]
            )
        } catch {
            print("Fetch page failed:", error)
        }
        isLoading = false
    }
    
    func currentSnapshot() -> NSDiffableDataSourceSnapshot<String, UUID> {
        snapshotSubject.value
    }
    
    func transaction(at indexPath: IndexPath) -> TransactionEntity {
        sections[indexPath.section].items[indexPath.row]
    }

    func sectionDate(for section: Int) -> Date {
        sections[section].date
    }

    func shouldLoadMore(near indexPath: IndexPath) -> Bool {
        guard !sections.isEmpty else { return false }
        let lastSection = max(sections.count - 1, 0)
        if indexPath.section == lastSection {
            let lastRow = sections[lastSection].items.count - 3
            return indexPath.row >= max(lastRow, 0)
        }
        return false
    }
    
    private func regroup() {
        // group tx by day
        let cal = Calendar.current
        let grouped = Dictionary(grouping: txs) { (tx: TransactionEntity) -> String in
            let d = cal.startOfDay(for: tx.createdAt)
            return Self.dayKey(from: d)
        }

        var tmp: [Section] = grouped.map { (key, items) in
            let d = Self.dayDate(fromKey: key)!
            return Section(key: key, date: d, items: items.sorted { ($0.createdAt, $0.id.uuidString) > ($1.createdAt, $1.id.uuidString) })
        }
        tmp.sort { $0.date > $1.date }
        sections = tmp
    }

    private func applySnapshot() {
        // apply diffable snapshot
        var snapshot = NSDiffableDataSourceSnapshot<String, UUID>()
        snapshot.appendSections(sections.map { $0.key })
        for sec in sections {
            snapshot.appendItems(sec.items.map { $0.id }, toSection: sec.key)
        }
        snapshotSubject.send(snapshot)
    }

    private static func dayKey(from date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: date)
    }

    private static func dayDate(fromKey key: String) -> Date? {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df.date(from: key)
    }
}
