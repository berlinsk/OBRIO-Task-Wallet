//
//  ViewController.swift
//  TransactionsTestTask
//
//

import UIKit
import Combine

struct Section {
    let key: String   // yyyy-mm-dd
    let date: Date
    var items: [TransactionEntity]
}

final class HomeViewController: UIViewController, UITableViewDelegate {
    // vm
    private let viewModel = ServicesAssembler.makeHomeViewModel()
    
    // UI
    private let balanceLabel = UILabel()
    private let topUpButton = UIButton(type: .system)
    private let addButton = UIButton(type: .system)
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var rateItem: UIBarButtonItem!

    // data
    private var sections: [Section] = []
    private var txs: [TransactionEntity] = []
    private var dataSource: UITableViewDiffableDataSource<String, UUID>!

    // snapshot state
    private var isApplyingSnapshot = false

    // combine
    private var bag = Set<AnyCancellable>()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Wallet"
        view.backgroundColor = .systemBackground
        setupUI()
        setupDataSource()
        bindRate()
        bindViewModelOutputs()

        NotificationCenter.default.addObserver(self, selector: #selector(onTxChanged), name: .transactionsChanged, object: nil) // reload table when new tx added

        loadFirstPage()
        updateBalanceLabel()
        viewModel.refreshBalance() // initial balance push
    }

    private func setupUI() {
        // rate(top bar right)
        rateItem = UIBarButtonItem(title: "—", style: .plain, target: nil, action: nil)
        navigationItem.rightBarButtonItem = rateItem

        // balance + top up
        balanceLabel.font = .monospacedDigitSystemFont(ofSize: 22, weight: .bold)
        topUpButton.setTitle("Top up", for: .normal)
        topUpButton.addTarget(self, action: #selector(onTopUp), for: .touchUpInside)

        let balanceRow = UIStackView(arrangedSubviews: [balanceLabel, topUpButton])
        balanceRow.axis = .horizontal
        balanceRow.alignment = .center
        balanceRow.spacing = 12
        balanceRow.distribution = .equalSpacing
        balanceRow.translatesAutoresizingMaskIntoConstraints = false

        // transaction button
        addButton.setTitle("Add transaction", for: .normal)
        addButton.addTarget(self, action: #selector(onAddTransaction), for: .touchUpInside)
        addButton.translatesAutoresizingMaskIntoConstraints = false

        // table
        tableView.register(TransactionCell.self, forCellReuseIdentifier: TransactionCell.reuseID)
        tableView.delegate = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        // logs button
        let logsItem = UIBarButtonItem(title: "Logs", style: .plain, target: self, action: #selector(onShowLogs))
        navigationItem.leftBarButtonItem = logsItem

        view.addSubview(balanceRow)
        view.addSubview(addButton)
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            balanceRow.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            balanceRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            balanceRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            addButton.topAnchor.constraint(equalTo: balanceRow.bottomAnchor, constant: 12),
            addButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),

            tableView.topAnchor.constraint(equalTo: addButton.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupDataSource() {
        // diffable ds for tx list
        dataSource = UITableViewDiffableDataSource<String, UUID>(tableView: tableView) { [weak self] tableView, indexPath, _ in
            guard let self else { return UITableViewCell() }
            let cell = tableView.dequeueReusableCell(withIdentifier: TransactionCell.reuseID, for: indexPath) as! TransactionCell
            let tx = self.viewModel.transaction(at: indexPath)
            cell.configure(with: tx)
            return cell
        }
        dataSource.defaultRowAnimation = .fade
    }

    private func bindRate() {
        // subscribe btc rate updates
        ServicesAssembler.observeRateUseCase().publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] rate in
                guard let self else { return }
                let nf = NumberFormatter()
                nf.numberStyle = .currency
                nf.currencyCode = "USD"
                self.rateItem.title = "1 BTC = \(nf.string(from: rate.usdPerBtc as NSDecimalNumber) ?? "-")"
            }
            .store(in: &bag)
    }
    
    private func bindViewModelOutputs() {
        viewModel.rateText
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                self?.rateItem.title = text
            }
            .store(in: &bag)

        viewModel.balanceText
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                self?.balanceLabel.text = text
            }
            .store(in: &bag)
        
        // compiled snapshot from vm
        viewModel.snapshot
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                self?.applySnapshot(snapshot, reload: true)
            }
            .store(in: &bag)
    }

    // loading/grouping
    private func loadFirstPage() {
        viewModel.loadFirstPage()
    }

    private func loadNextPage() {
        guard !isApplyingSnapshot else { return } //doesnt load if busy or no more or snapshot aplying
        viewModel.loadNextPage()
    }

    private func regroupAndApplySnapshot(reload: Bool = true) {
        // group tx by day
        let snapshot = viewModel.currentSnapshot()
        applySnapshot(snapshot, reload: reload)
    }
    
    // prevent double apply
    private func applySnapshot(_ snapshot: NSDiffableDataSourceSnapshot<String, UUID>, reload: Bool) {
        guard !isApplyingSnapshot else { return }
        isApplyingSnapshot = true

        if #available(iOS 15.0, *), reload { //ios15+ use reloadData ver
            dataSource.applySnapshotUsingReloadData(snapshot) { [weak self] in
                self?.isApplyingSnapshot = false
            }
        } else { // old ios use usual apply
            dataSource.apply(snapshot, animatingDifferences: !reload) { [weak self] in
                self?.isApplyingSnapshot = false
            }
        }
    }

    private static func dayKey(from date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: date)
    }
    private static func dayDate(fromKey key: String) -> Date? {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df.date(from: key)
    }

    private func updateBalanceLabel() { // recalc balance from repo
        do {
            let btc = try ServicesAssembler.getBalanceUseCase().execute()
            balanceLabel.text = "Balance: \(Money.formatBTC(btc)) BTC"
        } catch {
            balanceLabel.text = "Balance: —"
        }
    }
    
    // table delegate for section headers
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let secDate = viewModel.sectionDate(for: section)
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        let title = df.string(from: secDate)

        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .secondaryLabel

        let container = UIView()
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -16),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        return container
    }

    // table delegate for header height
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 28
    }

    // table delegate for pagination trigger
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if isApplyingSnapshot { return } //doesnt paginate during apply
        if viewModel.shouldLoadMore(near: indexPath) {
            loadNextPage()
        }
    }

    // actions
    @objc private func onTopUp() {
        let ac = UIAlertController(title: "Top up", message: "Enter amount in BTC", preferredStyle: .alert)
        ac.addTextField { tf in
            tf.keyboardType = .decimalPad
            tf.placeholder = "0.001"
        }
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        ac.addAction(UIAlertAction(title: "Add", style: .default, handler: { _ in
            guard let t = ac.textFields?.first?.text?.replacingOccurrences(of: ",", with: "."),
                  let dec = Decimal(string: t), dec > 0 else { return }
            self.viewModel.topUp(amountBTC: dec)
        }))
        present(ac, animated: true)
    }

    @objc private func onAddTransaction() {
        navigationController?.pushViewController(AddTransactionViewController(), animated: true) // navigation second screen
    }

    @objc private func onTxChanged() {
        loadFirstPage() // reload tx after change
        viewModel.refreshBalance() // sync balance with vm
    }
    
    @objc private func onShowLogs() {
        let events = ServicesAssembler.getAllAnalyticsEventsUseCase().execute()
        if events.isEmpty {
            let ac = UIAlertController(title: "Logs", message: "No events yet", preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "OK", style: .default))
            present(ac, animated: true)
            return
        }

        // compact text assembly
        let iso = ISO8601DateFormatter()
        let lines = events.map { ev in
            "\(iso.string(from: ev.date)) | \(ev.name) | \(ev.parameters)"
        }.joined(separator: "\n")

        let ac = UIAlertController(title: "Logs", message: lines, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
    }
}
