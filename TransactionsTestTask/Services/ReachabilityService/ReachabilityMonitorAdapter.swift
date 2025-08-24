//
//  ReachabilityMonitorAdapter.swift
//  TransactionsTestTask
//
//  Created by Берлинский Ярослав Владленович on 24.08.2025.
//

import Foundation
import Network

// to map nwpathMonitor
final class ReachabilityMonitorAdapter: ReachabilityMonitoring {
    private let monitor = NWPathMonitor()
    var onUpdate: ((Bool) -> Void)?

    func start(queue: DispatchQueue) {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.onUpdate?(path.status == .satisfied)
        }
        monitor.start(queue: queue)
    }

    func cancel() {
        monitor.cancel()
    }
}
