//
//  TransactionsRepository.swift
//  TransactionsTestTask
//
//  Created by Берлинский Ярослав Владленович on 22.08.2025.
//

import CoreData

protocol TransactionsRepository {
    func add(amountSats: Int64, type: TransactionType, category: TransactionCategory?, date: Date) throws
    func fetchPage(offset: Int, limit: Int) throws -> [TransactionEntity] // list with pagination
    func count() throws -> Int
    func totalBalanceSats() throws -> Int64 // income/expense
}

final class TransactionsRepositoryImpl: TransactionsRepository {
    private let stack: CoreDataStack
    
    init(stack: CoreDataStack) {
        self.stack = stack
    }
}

extension TransactionsRepositoryImpl {
    func add(amountSats: Int64, type: TransactionType, category: TransactionCategory?, date: Date) throws {
        let ctx = stack.newBackgroundContext()
        try ctx.performAndWait {
            let m = CDTransaction(context: ctx)
            m.id = .init()
            m.createdAt = date
            m.amountSats = amountSats
            m.type = type.rawValue
            m.category = category?.rawValue
            try ctx.save()
        }
    }

    func fetchPage(offset: Int, limit: Int) throws -> [TransactionEntity] {
        let ctx = stack.viewContext
        let req = CDTransaction.fetchRequest()
        req.sortDescriptors = [
            NSSortDescriptor(key: "createdAt", ascending: false),
            NSSortDescriptor(key: "id", ascending: false) // secondary sorter(if we have 2+ transactions at one point in tim)e
        ]
        req.fetchOffset = offset
        req.fetchLimit = limit
        req.fetchBatchSize = 20 // for pagination
        let rows = try ctx.fetch(req)
        return rows.map {
            TransactionEntity(
                id: $0.id,
                createdAt: $0.createdAt,
                amountSats: $0.amountSats,
                type: TransactionType(rawValue: $0.type) ?? .expense,
                category: $0.category.flatMap(TransactionCategory.init(rawValue:))
            )
        }
    }

    func count() throws -> Int {
        let ctx = stack.viewContext
        let req = CDTransaction.fetchRequest()
        return try ctx.count(for: req)
    }

    func totalBalanceSats() throws -> Int64 {
        let incomes = try sumAmountSats(predicate: NSPredicate(format: "type == %d", TransactionType.income.rawValue))
        let expenses = try sumAmountSats(predicate: NSPredicate(format: "type == %d", TransactionType.expense.rawValue))
        return incomes - expenses
    }
}

private extension TransactionsRepositoryImpl {
    // sum amounts with filter
    func sumAmountSats(predicate: NSPredicate?) throws -> Int64 {
        let ctx = stack.viewContext
        let req = NSFetchRequest<NSDictionary>(entityName: "CDTransaction")
        req.predicate = predicate
        req.resultType = .dictionaryResultType

        let expr = NSExpressionDescription()
        expr.name = "sum"
        expr.expression = NSExpression(forFunction: "sum:", arguments: [NSExpression(forKeyPath: "amountSats")])
        expr.expressionResultType = .integer64AttributeType
        req.propertiesToFetch = [expr]

        let result = try ctx.fetch(req).first
        return (result?["sum"] as? Int64) ?? 0
    }
}
