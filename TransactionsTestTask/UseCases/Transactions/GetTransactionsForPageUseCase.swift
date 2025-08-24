//
//  GetTransactionsForPageUseCase.swift
//  TransactionsTestTask
//
//  Created by Берлинский Ярослав Владленович on 23.08.2025.
//

import Foundation

protocol GetTransactionsForPageUseCase {
    func execute(offset:Int, limit:Int) throws -> [TransactionEntity]
}

final class GetTransactionsPageUseCaseImpl: GetTransactionsForPageUseCase {
    private let repo: TransactionsRepository
    
    init(repo: TransactionsRepository) {
        self.repo = repo
    }
}

extension GetTransactionsPageUseCaseImpl {
    func execute(offset:Int, limit:Int) throws -> [TransactionEntity] {
        try repo.fetchPage(offset: offset, limit: limit)
    }
}
