//
//  RateCacheRepository.swift
//  TransactionsTestTask
//
//  Created by Берлинский Ярослав Владленович on 23.08.2025.
//

import CoreData

protocol RateCacheRepository {
    func load() throws -> RateEntity?
    func save(_ rate: RateEntity) throws
}

final class RateCacheRepositoryImpl: RateCacheRepository {
    private let stack: CoreDataStack
    private let key = "BTCUSD" // fixed key(we cache only 1 pair)

    init(stack: CoreDataStack) {
        self.stack = stack
    }
}

extension RateCacheRepositoryImpl {
    func load() throws -> RateEntity? {
        let ctx = stack.viewContext
        let req = CDRateCache.fetchRequest()
        req.predicate = NSPredicate(format: "id == %@", key)
        req.fetchLimit = 1
        if let r = try ctx.fetch(req).first {
            return RateEntity(usdPerBtc: r.valueUsdPerBtc as Decimal, updatedAt: r.updatedAt)
        }
        return nil
    }

    func save(_ rate: RateEntity) throws {
        let ctx = stack.newBackgroundContext()
        try ctx.performAndWait {
            let req = CDRateCache.fetchRequest()
            req.predicate = NSPredicate(format: "id == %@", key)
            let m = try ctx.fetch(req).first ?? CDRateCache(context: ctx)
            m.id = key
            m.valueUsdPerBtc = rate.usdPerBtc as NSDecimalNumber
            m.updatedAt = rate.updatedAt
            try ctx.save()
        }
    }
}
