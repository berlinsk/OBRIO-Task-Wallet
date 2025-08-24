//
//  ServicesAssembler.swift
//  TransactionsTestTask
//
//

import Combine
import Foundation
/// Services Assembler is used for Dependency Injection
/// There is an example of a _bad_ services relationship built on `onRateUpdate` callback
/// This kind of relationship must be refactored with a more convenient and reliable approach
///
/// It's ok to move the logging to model/viewModel/interactor/etc when you have 1-2 modules in your app
/// Imagine having rate updates in 20-50 diffent modules
/// Make this logic not depending on any module
enum ServicesAssembler {
    
    final class Observer {
        let name: String
        var bag = Set<AnyCancellable>() //keep subscriptions alive per observer
        init(name: String) { self.name = name }
    }
    
    //local storage of di layer subscriptions(to avoid debinding)
    private static var _bag = Set<AnyCancellable>()

    // MARK: - CoreData
    // single CoreData stack shared across the app
    static let coreData: PerformOnce<CoreDataStack> = {
        let stack = CoreDataStack()
        return { stack }
    }()
    
    // MARK: - VM factories
    static func makeHomeViewModel() -> HomeViewModel {
        HomeViewModelImpl(
            observeRate: observeRateUseCase(),
            getBalance: getBalanceUseCase(),
            addIncome: addIncomeUseCase(),
            trackEvent: trackEventUseCase(),
            getPage: getTransactionsPageUseCase()
        )
    }
    
    static func makeAddTransactionViewModel() -> AddTransactionViewModel {
        AddTransactionViewModelImpl(
            addExpense: addExpenseUseCase(),
            trackEvent: trackEventUseCase()
        )
    }

    // MARK: - Rate infrastructure
    // repository that caches last BTC/USD rate in coredata
    static let rateCache: PerformOnce<RateCacheRepository> = {
        let repo = RateCacheRepositoryImpl(stack: coreData())
        return { repo }
    }()

    // http client for fetching btc/usd from public api(CoinBase)
    static let rateAPI: PerformOnce<RateAPIClient> = {
        let api = CoinbaseRateAPIClient()
        return { api }
    }()
    
    static let reachability: PerformOnce<ReachabilityService> = {
        let r = ReachabilityService()
        return { r }
    }()

    // MARK: - BitcoinRateService
    // service for fetching rate on a timer, publishing updates via Combine, caching last value to CoreData
    static let bitcoinRateService: PerformOnce<BitcoinRateService> = {
        let service = BitcoinRateServiceImpl(
            api: rateAPI(),
            cache: rateCache(),
            analytics: analyticsService() //pass analytics to the service
        )

        service.onRateUpdate = { _ in } // callback
        
        // instant refresh of the course when network apperaed
        reachability().publisher
            .removeDuplicates()
            .filter { $0 } //only when the network's available
            .sink { _ in service.refreshNow() }
            .store(in: &_bag)

        return { service }
    }()
    
    // MARK: - Transactions
    static let transactionsRepository: PerformOnce<TransactionsRepository> = {
        let repo = TransactionsRepositoryImpl(stack: coreData())
        return { repo } // return singleton repo
    }()
    
    // MARK: - AnalyticsService
    
    static let analyticsService: PerformOnce<AnalyticsService> = {
        let service = AnalyticsServiceImpl()
        
        return { service }
    }()
    
    // MARK: - Observers for simulation(20–50 modules)
    // creates N independent subscribers to the ratePublisher and logs each update(simulates 20–50 modules listening to rate updates)
    static func startRateObservers(count: Int = 30) {
        if _observers.isEmpty { //initialize only once
            let analytics = analyticsService()
            for i in 1...count {
                let obs = Observer(name: "Module-\(i)")
                bitcoinRateService().ratePublisher
                    .sink { [weak obs] rate in
                        guard let obs else { return }
                        print("[\(obs.name)] BTC rate updated: \(rate.usdPerBtc) at \(rate.updatedAt)") // demo log to console +analytics event per observer
                        analytics.trackEvent(
                            name: "btc_rate_module_update",
                            parameters: [
                                "module": obs.name,
                                "rate": "\(rate.usdPerBtc)"
                            ]
                        )
                    }
                    .store(in: &obs.bag)
                _observers.append(obs) // retain observer (and its bag)
            }
        }
    }
    
    // UseCaese according to DI logic
    // MARK: Transactions useCases
    static let addIncomeUseCase: PerformOnce<AddIncomeUseCase> = {
        let uc = AddIncomeUseCaseImpl(repo: transactionsRepository())
        return { uc }
    }()

    static let addExpenseUseCase: PerformOnce<AddExpenseUseCase> = {
        let uc = AddExpenseUseCaseImpl(repo: transactionsRepository())
        return { uc }
    }()

    static let getTransactionsPageUseCase: PerformOnce<GetTransactionsPageUseCase> = {
        let uc = GetTransactionsPageUseCaseImpl(repo: transactionsRepository())
        return { uc }
    }()

    static let getBalanceUseCase: PerformOnce<GetBalanceUseCase> = {
        let uc = GetBalanceUseCaseImpl(repo: transactionsRepository())
        return { uc }
    }()

    // MARK: Rate useCases
    static let observeRateUseCase: PerformOnce<ObserveRateUseCase> = {
        let uc = ObserveRateUseCaseImpl(rateService: bitcoinRateService())
        return { uc }
    }()

    static let startRateUpdatesUseCase: PerformOnce<StartRateUpdatesUseCase> = {
        let uc = StartRateUpdatesUseCaseImpl(svc: bitcoinRateService())
        return { uc }
    }()

    static let refreshRateNowUseCase: PerformOnce<RefreshRateNowUseCase> = {
        let uc = RefreshRateNowUseCaseImpl(svc: bitcoinRateService())
        return { uc }
    }()

    // MARK: Analytics useCases
    static let trackEventUseCase: PerformOnce<TrackEventUseCase> = {
        let uc = TrackEventUseCaseImpl(analytics: analyticsService())
        return { uc }
    }()
    
    static let getAllAnalyticsEventsUseCase: PerformOnce<GetAllAnalyticsEventsUseCase> = {
        let uc = GetAllAnalyticsEventsUseCaseImpl(analytics: analyticsService())
        return { uc }
    }()
    
    private static var _observers: [Observer] = [] // retained holders for observers(they aren't deallocated)
}
