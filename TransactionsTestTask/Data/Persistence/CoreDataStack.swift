//
//  CoreDataStack.swift
//  TransactionsTestTask
//
//  Created by Берлинский Ярослав Владленович on 22.08.2025.
//

import CoreData

final class CoreDataStack {
    static let modelName = "TransactionsTestTask"

    let container: NSPersistentContainer
    
    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: Self.modelName)
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { _, error in
            precondition(error == nil, "core data load error: \(error!)")
        }
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}

extension CoreDataStack {
    func newBackgroundContext() -> NSManagedObjectContext {
        container.newBackgroundContext()
    }
}
