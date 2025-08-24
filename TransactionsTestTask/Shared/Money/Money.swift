//
//  Money.swift
//  TransactionsTestTask
//
//  Created by Берлинский Ярослав Владленович on 22.08.2025.
//

import Foundation

enum Money {
    // satoshi in 1 btc
    static let satsPerBTC = Decimal(100000000)
}

extension Money {
    static func sats(fromBTC btc: Decimal) -> Int64 {
        let v = (btc * satsPerBTC) as NSDecimalNumber
        return v.int64Value
    }

    static func btc(fromSats sats: Int64) -> Decimal {
        Decimal(sats) / satsPerBTC
    }

    static func formatBTC(_ btc: Decimal) -> String {
        let f = NumberFormatter()
        f.minimumIntegerDigits = 1
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 8
        f.decimalSeparator = Locale.current.decimalSeparator
        return f.string(from: btc as NSDecimalNumber) ?? "\(btc)"
    }
}
