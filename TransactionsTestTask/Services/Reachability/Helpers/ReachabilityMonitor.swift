//
//  ReachabilityMonitor.swift
//  TransactionsTestTask
//
//  Created by Берлинский Ярослав Владленович on 24.08.2025.
//

import Foundation

protocol ReachabilityMonitor: AnyObject {
    var onUpdate: ((Bool) -> Void)? {get set}
    func start(queue: DispatchQueue)
    func cancel()
}
