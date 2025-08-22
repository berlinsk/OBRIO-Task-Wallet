//
//  Money.swift
//  TransactionsTestTask
//
//  Created by Берлинский Ярослав Владленович on 22.08.2025.
//

import Foundation

enum Money {
    // count sats in 1 btc
    static let satsPerBTC = Decimal(100_000_000)

    // convert btc to sats
    static func sats(fromBTC btc: Decimal) -> Int64 {
        let v = (btc * satsPerBTC) as NSDecimalNumber //to avoid precision loss when casting to Int 64
        return v.int64Value
    }

    // convert sats to btc
    static func btc(fromSats sats: Int64) -> Decimal {
        Decimal(sats) / satsPerBTC
    }

    // format btc to readsble string
    static func formatBTC(_ btc: Decimal) -> String {
        let f = NumberFormatter() //to keep locale separator (comma/dot) and limit fraction digits
        f.minimumIntegerDigits = 1
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 8 // btc usually shown with up to 8 digits
        f.decimalSeparator = Locale.current.decimalSeparator
        return f.string(from: btc as NSDecimalNumber) ?? "\(btc)"
    }
}
