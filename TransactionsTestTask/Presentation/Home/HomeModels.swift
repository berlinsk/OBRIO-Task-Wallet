//
//  HomeModels.swift
//  TransactionsTestTask
//
//  Created by Берлинский Ярослав Владленович on 24.08.2025.
//

import Foundation

struct Section {
    let key: String //yyyy-mm-dd
    let date: Date
    var items: [TransactionEntity]
}
