//
//  ReachabilityService.swift
//  TransactionsTestTask
//
//  Created by Берлинский Ярослав Владленович on 23.08.2025.
//

import Foundation
import Combine

final class ReachabilityService {
    private let monitor: ReachabilityMonitor
    private let queue = DispatchQueue(label: "reachability.monitor")
    private let subject = CurrentValueSubject<Bool, Never>(false) //true=network's available

    var publisher: AnyPublisher<Bool, Never> {
        subject.removeDuplicates().eraseToAnyPublisher()
    }

    init(monitor: ReachabilityMonitor = ReachabilityMonitorImpl()) {
        self.monitor = monitor
        self.monitor.onUpdate = { [weak self] available in
            self?.subject.send(available)
        }
        self.monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
