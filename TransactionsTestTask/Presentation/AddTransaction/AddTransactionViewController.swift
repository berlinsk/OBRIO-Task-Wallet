//
//  AddTransactionViewController.swift
//  TransactionsTestTask
//
//  Created by Берлинский Ярослав Владленович on 23.08.2025.
//

import UIKit

final class AddTransactionViewController: UIViewController {
    private let amountField = UITextField() //input for btc amount
    private let segment = UISegmentedControl(items: Category.allCases.map { $0.rawValue })
    private let addButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Add expense"
        view.backgroundColor = .systemBackground

        amountField.placeholder = "amount in BTC"
        amountField.keyboardType = .decimalPad
        amountField.borderStyle = .roundedRect

        segment.selectedSegmentIndex = 0

        addButton.setTitle("Add", for: .normal)
        addButton.addTarget(self, action: #selector(onAdd), for: .touchUpInside)

        //stack with field + segment + button
        let v = UIStackView(arrangedSubviews: [amountField, segment, addButton])
        v.axis = .vertical
        v.spacing = 16
        v.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(v)

        NSLayoutConstraint.activate([
            v.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            v.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            v.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16)
        ])
    }

    @objc private func onAdd() {
        guard let text = amountField.text?.replacingOccurrences(of: ",", with: "."), //read field, replace , to .
              let dec = Decimal(string: text), dec > 0 else { return }

        let sats = Money.sats(fromBTC: dec) //btc to sats
        let cat = Category.allCases[segment.selectedSegmentIndex] // get chosen category
        do {
            try ServicesAssembler.transactionsRepository().add( //save expense to repo
                amountSats: sats,
                type: .expense,
                category: cat,
                date: Date()
            )
            ServicesAssembler.analyticsService().trackEvent( // expence log
                name: "expense_add",
                parameters: [
                    "amount_btc":"\(dec)",
                    "category":cat.rawValue
                ]
            )
            NotificationCenter.default.post(name: .transactionsChanged, object: nil) //fire notification
            navigationController?.popViewController(animated: true) // back to home
        } catch {
            print("add expense failed:", error)
        }
    }
}
