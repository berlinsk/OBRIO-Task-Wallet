**Bitcoin Wallet**(test task)

Simple iOS app to track balance and daily expenses in BTC. Two screens: Home(balance, rate, list of transactions) and Add Expense. No 3rd-party libs.

**Tech stack**
- Swift 5.9, iOS 15+
- UIKit(no Storybard/XIBs), UICollectionView Compositional Layout, Diffable Data Source
- Combine for reactive flows
- CoreData for storage/caching
- URLSession for networking
- Network.framework(NWPathMonitor) for reachability
- XCTest for unit tests

**What was required**(_done_)
1. Two screens:
- Home(BTC balance with Top up action(alert input), Add transaction button to Screen 2, BTC/USD rate at top-right, list of all tx(income/expense) grouped by day, newest first, pagination by 20)
- Add transaction(amount input, category picker, after adding returns to Home and list refreshes)
2. all data in CoreData.
3. BTC rate fetched and periodically updated, value cached for offline
4. No third-party libraries, only UIKit/CoreData/Combine
5. UI is programmatic
6. Unit tests for services(see below)
7. "Rethinking ServicesAssembler" - i implemented a scalable logging scenario where rate updates are observed by many independent "modules"(20–50) and each update is logged in analytics(so logging is not tied to a single screen)

**Above the minimum**(extra):
1. Multiple-module logging simulation in which ServicesAssembler.startRateObservers creates N observers that subscribe to rate stream, each logs its own event. Idempotent start, covered by tests
2. ReachabilityService with NWPathMonitor and a clean adapter protocol(rate is refreshed instantly when connectivity returns)
3. Rate service details:
- immediate tick via prepend(())
- dedup on publisher(identical rate values do not spam UI)
- legacy callback onRateUpdate kept for backward compat
- cache save on each success
3. AnalyticsService's filters(by name and time range), thread-safe(NSLock), json export/import(used in tests)
4. Diffable Data Source +Compositional layout, small usability bits
5. Money helpers(BTC to satoshi) with formatting.

**Architecture**
I use MVVM + Use Cases + Repository(with Clean-Architecture style layering):
- Presentation((UIKit + VM), view controllers are thin, state comes from view models via Combine)
- Application layer((UseCases hide data sources and orchestration from UI)
- Domain with pure entities(TransactionEntity, RateEntity, etc.) with no UIKit/CoreData/Combine
- Data(CoreData queries + repositories for mapping to domain models), network client(CoinbaseRateAPIClient) is separete
- Infrastructure/Services: Analytics, Reachability, Rate service

Note: in order with provided template I use a Service Locator(ServicesAssembler) as a composition root(singletons via PerformOnce). In real app I would replace it with constructor DI(or a light container) to remove the global state. This is a conscious trade-off for test scope.

**Approaches + patterns** used
- Repositories over coredata(background saves, viewContext for reads, fetch batching, mapping to domain)
- Observer with Combine for streaming for rate, reachability and analytics events
- Singleton via lazy factory(PerformOnce<T>), so every service is created once and reused. No global mutable singletons are exposed directly
- Factory(UseCaseFactory)
- Caching+offline(BTC/USD rate cached in CoreData, on app start the last value is emitted immediately)
- Reachability-driven refresh(when network becomes available, rate fetch is triggered again instantly)

**Testing**
- AnalyticsServiceTests(filtering by name and date, ordering, export/import roundtrip, concurrency smoke)
- BitcoinRateServiceTests(cached value on init, immediate tick via prepend, stop prevents further emissions, failure path produces no items, publisher dedup, legacy callback)
- ReachabilityServiceTests(start and cancel behaviour, duplicate filtering, multi-subscriber scenario)
- ServicesAssemblerTests(singletons, module logging count, idempotency of observers, network stub with URLProtocol)

**How to run**
1. Clone the repo:
   ```bash
   git clone https://github.com/berlinsk/OBRIO-Task-Wallet.git
2. Open TransactionsTestTask.xcodeproj in the project folder
3. Select a simulator/your device
4. Press Run
