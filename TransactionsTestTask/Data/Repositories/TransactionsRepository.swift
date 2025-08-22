//
//  TransactionsRepository.swift
//  TransactionsTestTask
//
//  Created by Берлинский Ярослав Владленович on 22.08.2025.
//

import CoreData

enum TransactionType: Int16 { case income = 0, expense = 1 } // transaction type: income or expense
enum Category: String, CaseIterable { case groceries, taxi, electronics, restaurant, other } // categories for expenses

// domain of coredata
struct TransactionEntity {
    let id: UUID
    let createdAt: Date
    let amountSats: Int64
    let type: TransactionType
    let category: Category?
}

// repo interface
protocol TransactionsRepository {
    func add(amountSats: Int64, type: TransactionType, category: Category?, date: Date) throws // add transaction
    func fetchPage(offset: Int, limit: Int) throws -> [TransactionEntity] // fetch list with pagination
    func count() throws -> Int // count all records
    func totalBalanceSats() throws -> Int64 // calc total balance (income/expense)
}

//coredata implementation
final class TransactionsRepositoryImpl: TransactionsRepository {
    private let stack: CoreDataStack
    init(stack: CoreDataStack) { self.stack = stack }

    // add new transaction to coredata
    func add(amountSats: Int64, type: TransactionType, category: Category?, date: Date) throws {
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

    // fetch a page of tx sorted by date desc
    func fetchPage(offset: Int, limit: Int) throws -> [TransactionEntity] {
        let ctx = stack.viewContext
        let req = CDTransaction.fetchRequest()
        req.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
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
                category: $0.category.flatMap(Category.init(rawValue:))
            )
        }
    }

    // total number of tx
    func count() throws -> Int {
        let ctx = stack.viewContext
        let req = CDTransaction.fetchRequest()
        return try ctx.count(for: req)
    }

    // calc total balance in sats(incomes-expenses)
    func totalBalanceSats() throws -> Int64 {
        let incomes = try sumAmountSats(predicate: NSPredicate(format: "type == %d", TransactionType.income.rawValue))
        let expenses = try sumAmountSats(predicate: NSPredicate(format: "type == %d", TransactionType.expense.rawValue))
        return incomes - expenses
    }

    // helper for summing amounts with filter
    private func sumAmountSats(predicate: NSPredicate?) throws -> Int64 {
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
        return (result?["sum"] as? Int64) ?? 0 //return 0 if no rows
    }
}
