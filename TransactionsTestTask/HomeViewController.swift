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
        dataSource = UITableViewDiffableDataSource<String, UUID>(tableView: tableView) { [weak self] tableView, indexPath, _ in
            guard let self else { return UITableViewCell() }
            let cell = tableView.dequeueReusableCell(withIdentifier: TransactionCell.reuseID, for: indexPath) as! TransactionCell
            let tx = self.sections[indexPath.section].items[indexPath.row]
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
        guard !isLoading, hasMore, !isApplyingSnapshot else { return } //doesnt load if busy or no more or snapshot aplying
        isLoading = true
        do {
            let page = try ServicesAssembler.transactionsRepository().fetchPage(offset: offset, limit: pageSize)
            txs.append(contentsOf: page)
            offset += page.count
            hasMore = page.count == pageSize
            regroupAndApplySnapshot(reload: true) //redrawing
            updateBalanceLabel()
        } catch {
            print("Fetch page failed:", error)
        }
        isLoading = false
    }

    private func regroupAndApplySnapshot(reload: Bool = true) {
        // group tx by day
        let cal = Calendar.current
        let grouped = Dictionary(grouping: txs) { (tx: TransactionEntity) -> String in
            let d = cal.startOfDay(for: tx.createdAt)
            return Self.dayKey(from: d)
        }

        var tmp: [Section] = grouped.map { (key, items) in
            let d = Self.dayDate(fromKey: key)!
            return Section(key: key, date: d, items: items.sorted { ($0.createdAt, $0.id.uuidString) > ($1.createdAt, $1.id.uuidString) })
        }
        tmp.sort { $0.date > $1.date }
        sections = tmp

        // apply diffable snapshot
        var snapshot = NSDiffableDataSourceSnapshot<String, UUID>()
        snapshot.appendSections(sections.map { $0.key })
        for sec in sections {
            snapshot.appendItems(sec.items.map { $0.id }, toSection: sec.key)
        }
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
            let sats = try ServicesAssembler.transactionsRepository().totalBalanceSats()
            let btc = Money.btc(fromSats: sats)
            balanceLabel.text = "Balance: \(Money.formatBTC(btc)) BTC"
        } catch {
            balanceLabel.text = "Balance: —"
        }
    }
    
    // table delegate for section headers
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let sec = sections[section]
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        let title = df.string(from: sec.date)

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
        let lastSection = max(sections.count - 1, 0)
        if sections.indices.contains(lastSection),
           indexPath.section == lastSection {
            let lastRow = sections[lastSection].items.count - 3
            if indexPath.row >= max(lastRow, 0) {
                loadNextPage()
            }
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
        navigationController?.pushViewController(AddTransactionViewController(), animated: true) // navigation second screen
    }

    @objc private func onTxChanged() {
        loadFirstPage() // reload tx after change
    }
}
