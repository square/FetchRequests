//
//  ViewController.swift
//  iOS Example
//
//  Created by Adam Lickel on 7/2/19.
//  Copyright © 2019 Speramus Inc. All rights reserved.
//

import UIKit

import FetchRequests

class ViewController: UITableViewController {
    private(set) lazy var controller: FetchedResultsController<Model> = {
        let controller: FetchedResultsController<Model> = FetchedResultsController(
            fetchDefinition: Model.fetchDefinition(),
            sortDescriptors: [NSSortDescriptor(keyPath: \Model.updatedAt, ascending: false)]
        )
        controller.setDelegate(self)
        return controller
    }()

    private class Cell: UITableViewCell {
        override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
        }

        class var reuseIdentifier: String {
            return NSStringFromClass(self)
        }
    }
}

// MARK: - View Lifecycle

extension ViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("iOS Example", comment: "iOS Example")

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .trash,
            target: self,
            action: #selector(clearContents)
        )

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(addItem)
        )

        tableView.register(Cell.self, forCellReuseIdentifier: Cell.reuseIdentifier)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        controller.performFetch()
    }
}

// MARK: - UITableViewDataSource

extension ViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return controller.sections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return controller.sections[section].numberOfObjects
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: Cell.reuseIdentifier) else {
            fatalError("Cell reuse failed")
        }
        let model = controller.object(at: indexPath)
        cell.textLabel?.text = model.id
        cell.detailTextLabel?.text = model.createdAt.description
        return cell
    }
}

// MARK: - UITableViewDelegate

extension ViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let model = controller.object(at: indexPath)
        try? model.save()
    }

    override func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        let delete = UIContextualAction(
            style: .destructive,
            title: NSLocalizedString("Delete", comment: "Delete")
        ) { [weak self] action, view, completion in
            guard let self = self else {
                return
            }
            let model = self.controller.object(at: indexPath)
            try? model.delete()
        }

        return UISwipeActionsConfiguration(actions: [delete])
    }
}

// MARK: - Events

private extension ViewController {
    @objc
    func clearContents(_ sender: Any) {
        Model.reset()
    }

    @objc
    func addItem(_ sender: Any) {
        try? Model().save()
    }
}

// MARK: - CWFetchedResultsControllerDelegate

extension ViewController: FetchedResultsControllerDelegate {
    func controllerWillChangeContent(_ controller: FetchedResultsController<Model>) {
        tableView.beginUpdates()
    }

    func controllerDidChangeContent(_ controller: FetchedResultsController<Model>) {
        tableView.endUpdates()
    }

    func controller(
        _ controller: FetchedResultsController<Model>,
        didChange object: Model,
        for change: FetchedResultsChange<IndexPath>
    ) {
        switch change {
        case let .insert(newIndexPath):
            tableView.insertRows(at: [newIndexPath], with: .automatic)

        case let .update(indexPath):
            tableView.reloadRows(at: [indexPath], with: .none)

        case let .delete(indexPath):
            tableView.deleteRows(at: [indexPath], with: .automatic)

        case let .move(indexPath, newIndexPath):
            tableView.moveRow(at: indexPath, to: newIndexPath)
        }
    }

    func controller(
        _ controller: FetchedResultsController<Model>,
        didChange section: FetchedResultsSection<Model>,
        for change: FetchedResultsChange<Int>
    ) {
        switch change {
        case let .insert(index):
            tableView.insertSections([index], with: .automatic)

        case let .update(index):
            tableView.reloadSections([index], with: .automatic)

        case let .delete(index):
            tableView.deleteSections([index], with: .automatic)

        case let .move(index, newIndex):
            tableView.moveSection(index, toSection: newIndex)
        }
    }
}
