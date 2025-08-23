//
//  GetTransactionsPageUseCase.swift
//  TransactionsTestTask
//
//  Created by Берлинский Ярослав Владленович on 23.08.2025.
//

import Foundation

protocol GetTransactionsPageUseCase {
    func execute(offset:Int, limit:Int) throws -> [TransactionEntity]
}

final class GetTransactionsPageUseCaseImpl: GetTransactionsPageUseCase {
    private let repo: TransactionsRepository
    init(repo: TransactionsRepository) {
        self.repo = repo
    }

    func execute(offset:Int, limit:Int) throws -> [TransactionEntity] {
        try repo.fetchPage(offset: offset, limit: limit)
    }
}
