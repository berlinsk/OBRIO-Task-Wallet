//
//  AddTransactionViewController.swift
//  TransactionsTestTask
//
//  Created by Берлинский Ярослав Владленович on 23.08.2025.
//

import UIKit
import Combine

final class AddTransactionViewController: UIViewController {
    private let amountField = UITextField()
    private let segment = UISegmentedControl(items: TransactionCategory.allCases.map { $0.rawValue })
    private let addButton = UIButton(type: .system)
    
    private let viewModel: AddTransactionViewModel
    
    private var bag = Set<AnyCancellable>()
    
    init(viewModel: AddTransactionViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError()
    }

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

        //field+segment+button
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
        
        // nav back after success after addition
        viewModel.didAdd
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.navigationController?.popViewController(animated: true)
            }
            .store(in: &bag)
        
        viewModel.errorText
            .sink { print($0) }
            .store(in: &bag)
    }

    @objc private func onAdd() {
        guard let text = amountField.text?.replacingOccurrences(of: ",", with: "."),
              let dec = Decimal(string: text), dec > 0 else {
            return
        }

        let cat = TransactionCategory.allCases[segment.selectedSegmentIndex]
        viewModel.addExpense(amountBTC: dec, category: cat)
    }
}
