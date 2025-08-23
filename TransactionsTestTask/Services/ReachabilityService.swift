//
//  ReachabilityService.swift
//  TransactionsTestTask
//
//  Created by Берлинский Ярослав Владленович on 23.08.2025.
//

import Foundation
import Network
import Combine

final class ReachabilityService {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "reachability.monitor")
    private let subject = PassthroughSubject<Bool,Never>() //true=network's available

    var publisher: AnyPublisher<Bool,Never> { subject.eraseToAnyPublisher() }

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.subject.send(path.status == .satisfied)
        }
        monitor.start(queue: queue)
    }

    deinit { monitor.cancel() }
}
