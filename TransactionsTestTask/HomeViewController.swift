//
//  ViewController.swift
//  TransactionsTestTask
//
//

import UIKit
import Combine

private struct Section {
    let key: String   // yyyy-mm-dd
    let date: Date
    var items: [TransactionEntity]
}

final class HomeViewController: UIViewController, UITableViewDelegate {
    // UI
    private let balanceLabel = UILabel()
    private let topUpButton = UIButton(type: .system)
    private let addButton = UIButton(type: .system)
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let rateLabel = UILabel()

    // data
    private var sections: [Section] = []
    private var txs: [TransactionEntity] = []
    private var dataSource: UITableViewDiffableDataSource<String, UUID>!

    // paging
    private var offset = 0
    private let pageSize = 20
    private var isLoading = false
    private var hasMore = true

    // combine
    private var bag = Set<AnyCancellable>()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Wallet"
        view.backgroundColor = .systemBackground
        setupUI()
        setupDataSource()
        bindRate()

        NotificationCenter.default.addObserver(self, selector: #selector(onTxChanged), name: .transactionsChanged, object: nil) // reload table when new tx added

        loadFirstPage()
        updateBalanceLabel()
    }

    private func setupUI() {
        // rate(top bar right)
        rateLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        rateLabel.text = "—"
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: rateLabel)

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
        dataSource = UITableViewDiffableDataSource<String, UUID>(tableView: tableView) {
            tableView, indexPath, itemID -> UITableViewCell? in
            let cell = tableView.dequeueReusableCell(withIdentifier: TransactionCell.reuseID, for: indexPath) as! TransactionCell
            let secKey = self.sections[indexPath.section].key
            let tx = self.sections.first(where: { $0.key == secKey })!.items[indexPath.row]
            cell.configure(with: tx)
            return cell
        }
        dataSource.defaultRowAnimation = .fade
    }

    private func bindRate() {
        // subscribe btc rate updates
        ServicesAssembler.bitcoinRateService().ratePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] rate in
                guard let self else { return }
                let nf = NumberFormatter()
                nf.numberStyle = .currency
                nf.currencyCode = "USD"
                self.rateLabel.text = "1 BTC = \(nf.string(from: rate.usdPerBtc as NSDecimalNumber) ?? "-")"
            }
            .store(in: &bag)
    }

    // loading/grouping
    private func loadFirstPage() {
        offset = 0
        hasMore = true
        txs.removeAll()
        loadNextPage()
    }

    private func loadNextPage() {
        guard !isLoading, hasMore else { return }
        isLoading = true
        do {
            let page = try ServicesAssembler.transactionsRepository().fetchPage(offset: offset, limit: pageSize)
            txs.append(contentsOf: page)
            offset += page.count
            hasMore = page.count == pageSize
            regroupAndApplySnapshot()
            updateBalanceLabel()
        } catch {
            print("Fetch page failed:", error)
        }
        isLoading = false
    }

    private func regroupAndApplySnapshot() {
        // group tx by day
        let cal = Calendar.current
        let grouped = Dictionary(grouping: txs) { (tx: TransactionEntity) -> String in
            let d = cal.startOfDay(for: tx.createdAt)
            let key = Self.dayKey(from: d)
            return key
        }

        var tmp: [Section] = grouped.map { (key, items) in
            let d = Self.dayDate(fromKey: key)!
            return Section(key: key, date: d, items: items.sorted { $0.createdAt > $1.createdAt })
        }
        tmp.sort { $0.date > $1.date }
        sections = tmp

        // apply diffable snapshot
        var snapshot = NSDiffableDataSourceSnapshot<String, UUID>()
        for sec in sections {
            snapshot.appendSections([sec.key])
            snapshot.appendItems(sec.items.map { $0.id }, toSection: sec.key)
        }
        dataSource.apply(snapshot, animatingDifferences: true)
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
            let sats = try ServicesAssembler.transactionsRepository().totalBalanceSats()
            let btc = Money.btc(fromSats: sats)
            balanceLabel.text = "Balance: \(Money.formatBTC(btc)) BTC"
        } catch {
            balanceLabel.text = "Balance: —"
        }
    }

    // table delegate for pagination trigger
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let lastSection = sections.count - 1
        if indexPath.section == lastSection {
            let lastRow = sections[lastSection].items.count - 3
            if indexPath.row >= max(lastRow, 0) {
                loadNextPage()
            }
        }
    }

    // table delegate for section headers
    private func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let sec = sections[section]
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        return df.string(from: sec.date)
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
            let sats = Money.sats(fromBTC: dec)
            do {
                try ServicesAssembler.transactionsRepository().add(
                    amountSats: sats,
                    type: .income,
                    category: nil,
                    date: Date()
                )
                NotificationCenter.default.post(name: .transactionsChanged, object: nil) // reload
            } catch {
                print("Top up failed:", error)
            }
        }))
        present(ac, animated: true)
    }

    @objc private func onAddTransaction() {
        print("vc2") // stub for second screen(i haven't had it yet)
    }

    @objc private func onTxChanged() {
        loadFirstPage() // reload tx after change
    }
}
