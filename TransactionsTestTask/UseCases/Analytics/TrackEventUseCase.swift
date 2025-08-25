//
//  TrackEventUseCase.swift
//  TransactionsTestTask
//
//  Created by Берлинский Ярослав Владленович on 23.08.2025.
//

import Foundation

protocol TrackEventUseCase {
    func execute(_ name:String, _ params:[String:String])
}

final class TrackEventUseCaseImpl: TrackEventUseCase {
    private let analytics: AnalyticsService
    
    init(analytics: AnalyticsService) {
        self.analytics = analytics
    }
}

extension TrackEventUseCaseImpl {
    func execute(_ name:String, _ params:[String:String]) {
        analytics.trackEvent(name: name, parameters: params)
    }
}
