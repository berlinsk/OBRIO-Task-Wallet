//
//  ViewController.swift
//  TransactionsTestTask
//
//

import UIKit
import Combine

final class HomeViewController: UIViewController, UICollectionViewDelegate {
    // vm
    private let viewModel: HomeViewModel
    
    // UI
    private let balanceLabel = UILabel()
    private let topUpButton = UIButton(type: .system)
    private let addButton = UIButton(type: .system)
    private var rateItem: UIBarButtonItem!

    private lazy var collectionView: UICollectionView = {
        UICollectionView(frame: .zero, collectionViewLayout: Self.makeLayout())
    }()

    // data
    private var dataSource: UICollectionViewDiffableDataSource<String, UUID>!

    // snapshot state
    private var isApplyingSnapshot = false

    // combine
    private var bag = Set<AnyCancellable>()
    
    init(viewModel: HomeViewModel = ServicesAssembler.makeHomeViewModel()) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Wallet"
        view.backgroundColor = .systemGroupedBackground
        setupUI()
        setupDataSource()
        bindViewModelOutputs()

        NotificationCenter.default.addObserver(self, selector: #selector(onTxChanged), name: .transactionsChanged, object: nil)

        loadFirstPage()
        viewModel.refreshBalance()
    }

    private static func makeLayout() -> UICollectionViewCompositionalLayout {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                              heightDimension: .estimated(56))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                               heightDimension: .estimated(56))
        let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16)
        section.interGroupSpacing = 8

        let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(28))
        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize,
            elementKind: SectionHeaderView.kind,
            alignment: .top)
        section.boundarySupplementaryItems = [header]

        return UICollectionViewCompositionalLayout(section: section)
    }

    private func setupUI() {
        rateItem = UIBarButtonItem(title: "—", style: .plain, target: nil, action: nil)
        navigationItem.rightBarButtonItem = rateItem

        balanceLabel.font = .monospacedDigitSystemFont(ofSize: 22, weight: .bold)
        topUpButton.setTitle("Top up", for: .normal)
        topUpButton.addTarget(self, action: #selector(onTopUp), for: .touchUpInside)

        let balanceRow = UIStackView(arrangedSubviews: [balanceLabel, topUpButton])
        balanceRow.axis = .horizontal
        balanceRow.alignment = .center
        balanceRow.spacing = 12
        balanceRow.distribution = .equalSpacing
        balanceRow.translatesAutoresizingMaskIntoConstraints = false

        addButton.setTitle("Add transaction", for: .normal)
        addButton.addTarget(self, action: #selector(onAddTransaction), for: .touchUpInside)
        addButton.translatesAutoresizingMaskIntoConstraints = false

        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.register(TransactionItemCell.self, forCellWithReuseIdentifier: TransactionItemCell.reuseID)
        collectionView.register(SectionHeaderView.self, forSupplementaryViewOfKind: SectionHeaderView.kind, withReuseIdentifier: SectionHeaderView.reuseID)

        let logsItem = UIBarButtonItem(title: "Logs", style: .plain, target: self, action: #selector(onShowLogs))
        navigationItem.leftBarButtonItem = logsItem

        view.addSubview(balanceRow)
        view.addSubview(addButton)
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            balanceRow.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            balanceRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            balanceRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            addButton.topAnchor.constraint(equalTo: balanceRow.bottomAnchor, constant: 12),
            addButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),

            collectionView.topAnchor.constraint(equalTo: addButton.bottomAnchor, constant: 8),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupDataSource() {
        dataSource = UICollectionViewDiffableDataSource<String, UUID>(collectionView: collectionView) { [weak self] cv, indexPath, _ in
            guard let self else {
                return UICollectionViewCell()
            }
            let cell = cv.dequeueReusableCell(withReuseIdentifier: TransactionItemCell.reuseID, for: indexPath) as! TransactionItemCell
            let tx = self.viewModel.transaction(at: indexPath)
            cell.configure(with: tx)
            return cell
        }

        dataSource.supplementaryViewProvider = { [weak self] cv, kind, indexPath in
            guard let self,
                  kind == SectionHeaderView.kind,
                  let header = cv.dequeueReusableSupplementaryView(ofKind: kind,
                                                                   withReuseIdentifier: SectionHeaderView.reuseID,
                                                                   for: indexPath) as? SectionHeaderView else {
                return nil
            }
            let secDate = self.viewModel.sectionDate(for: indexPath.section)
            let df = DateFormatter()
            df.dateStyle = .medium
            df.timeStyle = .none
            header.setTitle(df.string(from: secDate))
            return header
        }
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
        
        viewModel.snapshot
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                self?.applySnapshot(snapshot, reload: true)
            }
            .store(in: &bag)
    }

    // prevent double apply
    private func applySnapshot(_ snapshot: NSDiffableDataSourceSnapshot<String, UUID>, reload: Bool) {
        guard !isApplyingSnapshot else {
            return
        }
        isApplyingSnapshot = true

        if #available(iOS 15.0, *), reload { //ios15+ use reloadData ver
            dataSource.applySnapshotUsingReloadData(snapshot) { [weak self] in
                self?.isApplyingSnapshot = false
            }
        } else { // usual apply
            dataSource.apply(snapshot, animatingDifferences: !reload) { [weak self] in
                self?.isApplyingSnapshot = false
            }
        }
    }

    private func loadFirstPage() {
        viewModel.loadFirstPage()
    }
    
    private func loadNextPage() {
        guard !isApplyingSnapshot else {
            return
        }
        viewModel.loadNextPage()
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if isApplyingSnapshot {
            return
        }
        if viewModel.shouldLoadMore(near: indexPath) {
            loadNextPage()
        }
    }

    @objc private func onTopUp() {
        let ac = UIAlertController(title: "Top up", message: "Enter amount in BTC", preferredStyle: .alert)
        ac.addTextField { tf in
            tf.keyboardType = .decimalPad
            tf.placeholder = "0.001"
        }
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        ac.addAction(UIAlertAction(title: "Add", style: .default, handler: { _ in
            guard let t = ac.textFields?.first?.text?.replacingOccurrences(of: ",", with: "."),
                  let dec = Decimal(string: t), dec > 0 else {
                return
            }
            self.viewModel.topUp(amountBTC: dec)
        }))
        present(ac, animated: true)
    }

    @objc private func onAddTransaction() {
        navigationController?.pushViewController(AddTransactionViewController(), animated: true)
    }

    // reload + sync
    @objc private func onTxChanged() {
        loadFirstPage()
        viewModel.refreshBalance()
    }
    
    @objc private func onShowLogs() {
        let events = ServicesAssembler.getAllAnalyticsEventsUseCase().execute()
        if events.isEmpty {
            let ac = UIAlertController(title: "Logs", message: "No events yet", preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "OK", style: .default))
            present(ac, animated: true)
            return
        }
        
        let iso = ISO8601DateFormatter()
        let lines = events.map { "\(iso.string(from: $0.date)) | \($0.name) | \($0.parameters)" }
            .joined(separator: "\n")
        let ac = UIAlertController(title: "Logs", message: lines, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
    }
}
