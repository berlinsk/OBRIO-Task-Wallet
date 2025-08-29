//
//  HomeViewModelImplTests.swift
//  TransactionsTestTaskTests
//
//  Created by Берлинский Ярослав Владленович on 29.08.2025.
//

import XCTest
import Combine
@testable import TransactionsTestTask

// MARK: Mocks

private final class GetBalanceUseCaseMock: GetBalanceUseCase {
    enum Mode {
        case success(Decimal)
        case failure(Error)
    }
    var mode: Mode = .success(0)
    func execute() throws -> Decimal {
        switch mode {
        case .success(let v):
            return v
        case .failure(let e):
            throw e
        }
    }
}

private final class AddIncomeUseCaseMock: AddIncomeUseCase {
    struct Call {
        let amountBTC: Decimal
        let date: Date
    }
    private(set) var calls: [Call] = []
    var error: Error?
    func execute(amountBTC: Decimal, date: Date) throws {
        if let error {
            throw error
        }
        calls.append(.init(amountBTC: amountBTC, date: date))
    }
}

private final class GetTransactionsForPageUseCaseMock: GetTransactionsForPageUseCase {
    var pages: [[TransactionEntity]] = []
    private var idx = 0
    func execute(offset: Int, limit: Int) throws -> [TransactionEntity] {
        defer {
            idx += 1
        }
        return idx < pages.count ? pages[idx] : []
    }
}

private final class DummyAddExpenseUseCase: AddExpenseUseCase {
    func execute(amountBTC: Decimal, category: TransactionCategory, date: Date) throws {}
}

private final class UseCaseFactoryMock: UseCaseFactory {
    var observeRate: ObserveRateUseCase
    var getBalance: GetBalanceUseCase
    var addIncome: AddIncomeUseCase
    var addExpense: AddExpenseUseCase
    var getTransactionsPage: GetTransactionsForPageUseCase
    var trackEvent: TrackEventUseCase

    //keeep the ref to trigger emissions
    let rateService: BitcoinRateServiceImpl
    let analytics: AnalyticsServiceMock

    init(cachedRate: Decimal? = Decimal(string: "77777.77"),
         apiInitial: Decimal = 65000) {
        // using mocks from btcRateService
        let api = RateAPIClientMock(mode: .success(apiInitial))
        let cache = RateCacheRepositoryMock()
        if let cachedRate {
            cache.loaded = RateEntity(usdPerBtc: cachedRate, updatedAt: Date())
        }
        let analytics = AnalyticsServiceMock()
        let rateSvc = BitcoinRateServiceImpl(api: api, cache: cache, analytics: analytics)

        self.observeRate = ObserveRateUseCaseImpl(rateService: rateSvc)
        self.getBalance = GetBalanceUseCaseMock()
        self.addIncome = AddIncomeUseCaseMock()
        self.addExpense = DummyAddExpenseUseCase()
        self.getTransactionsPage = GetTransactionsForPageUseCaseMock()
        self.trackEvent = TrackEventUseCaseImpl(analytics: analytics)

        //refs for managing from tests
        self.rateService = rateSvc
        self.analytics = analytics
    }
}

// MARK: Helpers

private func makeDate(_ y:Int,_ m:Int,_ d:Int,_ h:Int,_ min:Int,_ s:Int) -> Date {
    var c = DateComponents()
    c.year = y
    c.month = m
    c.day = d
    c.hour = h
    c.minute = min
    c.second = s
    var cal = Calendar(identifier: .iso8601)
    cal.timeZone = TimeZone(secondsFromGMT: 0)!
    return cal.date(from: c)!
}

private func tx(_ id: UUID = UUID(), sats: Int64, type: TransactionType, category: TransactionCategory?, date: Date) -> TransactionEntity {
    .init(id: id, createdAt: date, amountSats: sats, type: type, category: category)
}

// MARK: Tests

final class HomeViewModelImplTests: XCTestCase {
    private var bag = Set<AnyCancellable>()

    // rateText is mapped from rate +removeDuplicates
    func test_rateText_mapsAndDeduplicates_usingExistingRateMocks() {
        let factory = UseCaseFactoryMock(cachedRate: 70000, apiInitial: 70000)
        let vm = HomeViewModelImpl(factory: factory)

        var values: [String] = []
    
        vm.rateText
            .sink { s in
                values.append(s)
                if values.count <= 2 {
                    XCTAssertEqual(values.first, "1 BTC = 70 000,00 US$")
                    XCTAssertTrue(values.last?.contains("1 BTC =") == true)
                }
            }
            .store(in: &bag)
    }

    
    //testing refreshBalance
    func test_refreshBalance_success_and_failure() {
        let factory = UseCaseFactoryMock()
        let balance = factory.getBalance as! GetBalanceUseCaseMock
        let vm = HomeViewModelImpl(factory: factory)

        // success(sends formatted value)
        balance.mode = .success(Decimal(string: "1.2345")!)
        let exp1 = expectation(description: "balance success")
        
        vm.balanceText.dropFirst().prefix(1).sink { t in
            XCTAssertTrue(t.hasPrefix("Balance:"))
            XCTAssertTrue(t.contains("BTC"))
            exp1.fulfill()
        }.store(in: &bag)
        
        vm.refreshBalance()
        wait(for: [exp1], timeout: 1.0)

        // failure(sendfs '—')
        struct E: Error {}
        balance.mode = .failure(E())
        let exp2 = expectation(description: "balance failure fallback")
        
        vm.balanceText.dropFirst().prefix(1).sink { t in
            XCTAssertEqual(t, "Balance: —")
            exp2.fulfill()
        }.store(in: &bag)
        
        vm.refreshBalance()
        wait(for: [exp2], timeout: 1.0)
    }

    //check topUp addIncome+notif+analytics+balance
    func test_topUp_callsAddIncome_tracksEvent_postsNotification_and_refreshesBalance() {
        let factory = UseCaseFactoryMock()
        let addIncome = factory.addIncome as! AddIncomeUseCaseMock
        let balance = factory.getBalance as! GetBalanceUseCaseMock
        balance.mode = .success(Decimal(0))//before income

        let vm = HomeViewModelImpl(factory: factory)

        // observe notification
        let notif = expectation(description: "transactionsChanged posted")
        let token = NotificationCenter.default.addObserver(forName: .transactionsChanged, object: nil, queue: nil) { _ in
            notif.fulfill()
        }

        //observe refreshing the balance after topUp
        balance.mode = .success(Decimal(string: "0.5")!)
        let expBalance = expectation(description: "balance refreshed")
        vm.balanceText.dropFirst().prefix(1).sink { _ in
            expBalance.fulfill()
        }.store(in: &bag)

        vm.topUp(amountBTC: Decimal(string: "0.5")!)

        wait(for: [notif, expBalance], timeout: 1.0)
        NotificationCenter.default.removeObserver(token)

        XCTAssertEqual(addIncome.calls.count, 1)
        XCTAssertEqual(addIncome.calls.first?.amountBTC, Decimal(string: "0.5"))

        XCTAssertEqual(factory.analytics.eventsCount(), 1)
        XCTAssertEqual(factory.analytics.tracked.first?.name, "topup_add")
        XCTAssertEqual(factory.analytics.tracked.first?.params["amount_btc"], "0.5")
    }

    // test loadFirstPage snapshot sections/items
    func test_loadFirstPage_buildsSections_andSnapshot() {
        let factory = UseCaseFactoryMock()
        let pager = factory.getTransactionsPage as! GetTransactionsForPageUseCaseMock

        let d1 = makeDate(2025, 8, 28, 10, 0, 0)
        let d2 = makeDate(2025, 8, 27, 9, 30, 0)
        pager.pages = [[
            tx(sats: 1000, type: .expense, category: .groceries, date: d1),
            tx(sats: 2000, type: .income, category: nil, date: d1.addingTimeInterval(60)),
            tx(sats: 3000, type: .expense, category: .taxi, date: d2)
        ]]

        let vm = HomeViewModelImpl(factory: factory)
        vm.loadFirstPage()
        var snap: NSDiffableDataSourceSnapshot<String, UUID>?
        vm.snapshot.sink { s in
            snap = s
            
            guard let snapshot = snap else {
                return XCTFail("no snapshot")
            }
            
            XCTAssertEqual(snapshot.numberOfItems, 3)
            XCTAssertEqual(snapshot.sectionIdentifiers.count, 2)
        }.store(in: &bag)
    }

    // check shouldLoadMore threshold
    func test_shouldLoadMore_threshold() {
        let factory = UseCaseFactoryMock()
        let pager = factory.getTransactionsPage as! GetTransactionsForPageUseCaseMock

        let base = makeDate(2025, 8, 29, 12, 0, 0)
        let items = (0..<20).map { i in
            tx(sats: Int64(1000 + i), type: .expense, category: .other, date: base.addingTimeInterval(TimeInterval(i)))
        }
        pager.pages = [items]

        let vm = HomeViewModelImpl(factory: factory)
        vm.loadFirstPage()

        XCTAssertFalse(vm.shouldLoadMore(near: IndexPath(row: 10, section: 0)))
        XCTAssertTrue(vm.shouldLoadMore(near: IndexPath(row: 17, section: 0)))
    }

    //test pagination merge 2 pages=25 items
    func test_pagination_twoPages_mergedCount25() {
        let factory = UseCaseFactoryMock()
        let pager = factory.getTransactionsPage as! GetTransactionsForPageUseCaseMock

        let base = makeDate(2025, 8, 29, 12, 0, 0)
        let p1 = (0..<20).map { i in
            tx(sats: Int64(1000 + i), type: .expense, category: .other, date: base.addingTimeInterval(TimeInterval(i)))
        }
        let p2 = (0..<5).map { i in
            tx(sats: Int64(3000 + i), type: .income, category: nil, date: base.addingTimeInterval(TimeInterval(100 + i)))
        }
        pager.pages = [p1, p2]

        let vm = HomeViewModelImpl(factory: factory)
        vm.loadFirstPage()
        vm.loadNextPage()

        XCTAssertEqual(vm.currentSnapshot().numberOfItems, 25)
    }
}
