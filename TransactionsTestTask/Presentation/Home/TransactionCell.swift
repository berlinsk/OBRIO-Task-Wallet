//
//  TransactionCell.swift
//  TransactionsTestTask
//
//  Created by Берлинский Ярослав Владленович on 23.08.2025.
//

import UIKit

final class TransactionItemCell: UICollectionViewCell {
    static let reuseID = "TransactionItemCell"

    private let timeLabel = UILabel()
    private let categoryLabel = UILabel()
    private let amountLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        timeLabel.font = .systemFont(ofSize: 13)
        timeLabel.textColor = .secondaryLabel

        categoryLabel.font = .systemFont(ofSize: 15)

        amountLabel.font = .monospacedDigitSystemFont(ofSize: 15, weight: .semibold)
        amountLabel.textAlignment = .right

        let left = UIStackView(arrangedSubviews: [categoryLabel, timeLabel])
        left.axis = .vertical
        left.spacing = 2

        let h = UIStackView(arrangedSubviews: [left, amountLabel])
        h.alignment = .center
        h.spacing = 12
        h.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(h)
        contentView.backgroundColor = .secondarySystemGroupedBackground
        contentView.layer.cornerRadius = 10
        contentView.layer.masksToBounds = true

        NSLayoutConstraint.activate([
            h.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            h.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            h.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            h.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError()
    }
}

extension TransactionItemCell {
    func configure(with tx: TransactionEntity) {
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        timeLabel.text = df.string(from: tx.createdAt)

        if tx.type == .income {
            categoryLabel.text = "Top up"
            amountLabel.textColor = .systemGreen
            amountLabel.text = "+\(Money.formatBTC(Money.btc(fromSats: tx.amountSats))) BTC"
        } else {
            categoryLabel.text = tx.category?.rawValue
            amountLabel.textColor = .systemRed
            amountLabel.text = "-\(Money.formatBTC(Money.btc(fromSats: tx.amountSats))) BTC"
        }
    }
}
