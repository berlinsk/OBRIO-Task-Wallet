//
//  RateAPIClient.swift
//  TransactionsTestTask
//
//  Created by Берлинский Ярослав Владленович on 23.08.2025.
//

import Foundation
import Combine

// api client interface
protocol RateAPIClient {
    func fetchBtcUsd() -> AnyPublisher<Decimal, Error> // return btc/usd price as decimal
}

// impl for coindesk public api
final class CoinbaseRateAPIClient: RateAPIClient {
    private let url = URL(string: "https://api.coinbase.com/v2/exchange-rates?currency=BTC")! // get json with current btc price
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // fetch price and map it to decimal type
    func fetchBtcUsd() -> AnyPublisher<Decimal, Error> {
        session.dataTaskPublisher(for: url)
            .tryMap { (data, response) -> Decimal in
                struct Root: Decodable { // local structs for decoding only the fields we need
                    struct Data: Decodable {
                        let rates: [String:String] // map currency tostring value
                    }
                    let data: Data
                }

                let root = try JSONDecoder().decode(Root.self, from: data)

                // take USD value from dictionary
                guard let usd = root.data.rates["USD"],
                      let dec = Decimal(string: usd) else {
                    throw URLError(.cannotParseResponse) // if key missing or parse failed
                }

                return dec
            }
            .eraseToAnyPublisher() //hide impl details
    }
}
