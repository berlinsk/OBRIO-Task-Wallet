//
//  RateCacheRepository.swift
//  TransactionsTestTask
//
//  Created by Берлинский Ярослав Владленович on 23.08.2025.
//

import CoreData

// domain of coredata
struct RateEntity {
    let usdPerBtc: Decimal
    let updatedAt: Date
}

//repo interface
protocol RateCacheRepository {
    func load() throws -> RateEntity?
    func save(_ rate: RateEntity) throws
}

// coredata impl
final class RateCacheRepositoryImpl: RateCacheRepository {
    private let stack: CoreDataStack
    private let key = "BTCUSD" // fixed key since we cache only 1 pair

    init(stack: CoreDataStack) { self.stack = stack }

    // load rate from coredata, return nil if not found
    func load() throws -> RateEntity? {
        let ctx = stack.viewContext
        let req = CDRateCache.fetchRequest()
        req.predicate = NSPredicate(format: "id == %@", key)
        req.fetchLimit = 1
        if let r = try ctx.fetch(req).first {
            return RateEntity(usdPerBtc: r.valueUsdPerBtc as Decimal, updatedAt: r.updatedAt)
        }
        return nil // no cache saved yet
    }

    func save(_ rate: RateEntity) throws {
        let ctx = stack.newBackgroundContext()
        try ctx.performAndWait { // performAndWait used so background ctx is flushed immidiately
            let req = CDRateCache.fetchRequest()
            req.predicate = NSPredicate(format: "id == %@", key)
            let m = try ctx.fetch(req).first ?? CDRateCache(context: ctx) // if record exists update, else create new
            m.id = key
            m.valueUsdPerBtc = rate.usdPerBtc as NSDecimalNumber
            m.updatedAt = rate.updatedAt
            try ctx.save()
        }
    }
}
