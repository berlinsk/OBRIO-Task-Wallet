//
//  AnalyticsEvent.swift
//  TransactionsTestTask
//
//

import Foundation

struct AnalyticsEvent: Codable, Equatable {
    
    let name: String
    let parameters: [String: String]
    let date: Date
}
