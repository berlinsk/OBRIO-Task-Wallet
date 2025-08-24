//
//  TransactionEntity.swift
//  TransactionsTestTask
//
//  Created by Берлинский Ярослав Владленович on 24.08.2025.
//

import CoreData

struct TransactionEntity {
    let id: UUID
    let createdAt: Date
    let amountSats: Int64
    let type: TransactionType
    let category: TransactionCategory?
}
