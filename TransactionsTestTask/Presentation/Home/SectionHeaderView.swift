//
//  SectionHeaderView.swift
//  TransactionsTestTask
//
//  Created by Берлинский Ярослав Владленович on 25.08.2025.
//

import UIKit

final class SectionHeaderView: UICollectionReusableView {
    static let kind = UICollectionView.elementKindSectionHeader
    static let reuseID = "SectionHeaderView"

    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError()
    }
}

extension SectionHeaderView {
    func setTitle(_ text: String) {
        label.text = text
    }
}
