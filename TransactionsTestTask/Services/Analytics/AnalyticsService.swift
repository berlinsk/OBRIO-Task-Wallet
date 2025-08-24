//
//  AnalyticsService.swift
//  TransactionsTestTask
//
//

import Foundation
import Combine

/// Analytics Service is used for events logging
/// The list of reasonable events is up to you
/// It should be possible not only to track events but to get it from the service
/// The minimal needed filters are: event name and date range
/// The service should be covered by unit tests
protocol AnalyticsService: AnyObject {
    
    var eventsPublisher: AnyPublisher<AnalyticsEvent,Never> { get }
    
    // save event
   func trackEvent(name: String, parameters: [String: String])
   
   func events(name: String?, from: Date?, to: Date?) -> [AnalyticsEvent]
   
   func eventsCount() -> Int
   
   func allEvents() -> [AnalyticsEvent] //(sorted by date)
   
   func clear()
   
   func removeOlderThan(_ date: Date)
   
   func exportJSON(prettyPrinted: Bool) throws -> Data

   func importJSON(_ data: Data) throws
}

final class AnalyticsServiceImpl {
    
    private var events: [AnalyticsEvent] = []
    private let lock = NSLock() //thread safety
    private let subject = PassthroughSubject<AnalyticsEvent,Never>() // combine pipe
    
    var eventsPublisher: AnyPublisher<AnalyticsEvent,Never> {
        subject.eraseToAnyPublisher()
    }
        
    init() {}
}

extension AnalyticsServiceImpl: AnalyticsService {
    
    func trackEvent(name: String, parameters: [String: String]) {
        let event = AnalyticsEvent(
            name: name,
            parameters: parameters,
            date: Date()
        )
        lock.lock()
        defer {
            lock.unlock()
        }
        events.append(event)
        subject.send(event)
    }
    
    func events(name: String?, from: Date?, to: Date?) -> [AnalyticsEvent] {
        lock.lock()
        defer {
            lock.unlock()
        }
        return events
            .filter { e in
                let okName = (name == nil) || e.name == name!
                let okFrom = (from == nil) || e.date >= from!
                let okTo = (to == nil) || e.date <= to!
                return okName && okFrom && okTo
            }
            .sorted { $0.date < $1.date } //asc
    }

    func eventsCount() -> Int {
        lock.lock()
        defer {
            lock.unlock()
        }
        return events.count
    }

    func allEvents() -> [AnalyticsEvent] {
        lock.lock()
        defer {
            lock.unlock()
        }
        return events.sorted { $0.date < $1.date }
    }

    func clear() {
        lock.lock()
        defer {
            lock.unlock()
        }
        events.removeAll(keepingCapacity: false)
    }

    func removeOlderThan(_ date: Date) {
        lock.lock()
        defer {
            lock.unlock()
        }
        events.removeAll(where: { $0.date < date })
    }

    func exportJSON(prettyPrinted: Bool = false) throws -> Data {
        lock.lock()
        defer {
            lock.unlock()
        }
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        if prettyPrinted {
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
        return try enc.encode(events)
    }

    func importJSON(_ data: Data) throws {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let imported = try dec.decode([AnalyticsEvent].self, from: data)
        lock.lock()
        defer {
            lock.unlock()
        }
        events.append(contentsOf: imported)
    }
}
