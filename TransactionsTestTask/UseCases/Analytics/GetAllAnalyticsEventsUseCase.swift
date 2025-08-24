//
//  GetAllAnalyticsEventsUseCase.swift
//  TransactionsTestTask
//
//  Created by Берлинский Ярослав Владленович on 23.08.2025.
//

import Foundation

protocol GetAllAnalyticsEventsUseCase {
    func execute() -> [AnalyticsEvent]
}

final class GetAllAnalyticsEventsUseCaseImpl: GetAllAnalyticsEventsUseCase {
    private let analytics: AnalyticsService
    
    init(analytics: AnalyticsService) {
        self.analytics = analytics
    }
}

extension GetAllAnalyticsEventsUseCaseImpl {
    func execute() -> [AnalyticsEvent] {
        analytics.allEvents()
    }
}
