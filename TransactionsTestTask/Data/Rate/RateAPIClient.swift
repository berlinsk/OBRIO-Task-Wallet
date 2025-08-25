//
//  RateAPIClient.swift
//  TransactionsTestTask
//
//  Created by Берлинский Ярослав Владленович on 23.08.2025.
//

import Foundation
import Combine

protocol RateAPIClient {
    func fetchBtcUsd() -> AnyPublisher<Decimal, Error>
}

final class CoinbaseRateAPIClient: RateAPIClient {
    private let url = URL(string: "https://api.coinbase.com/v2/exchange-rates?currency=BTC")!
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }
}

extension CoinbaseRateAPIClient {
    func fetchBtcUsd() -> AnyPublisher<Decimal, Error> {
        session.dataTaskPublisher(for: url)
            .tryMap { (data, response) -> Decimal in
                
                struct Root: Decodable {
                    struct Data: Decodable {
                        let rates: [String:String]
                    }
                    let data: Data
                }

                let root = try JSONDecoder().decode(Root.self, from: data)

                guard let usd = root.data.rates["USD"],
                      let dec = Decimal(string: usd) else {
                    throw URLError(.cannotParseResponse)
                }

                return dec
            }
            .eraseToAnyPublisher()
    }
}
