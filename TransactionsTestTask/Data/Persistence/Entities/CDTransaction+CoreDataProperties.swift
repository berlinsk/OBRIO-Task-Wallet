//
//  CDTransaction+CoreDataProperties.swift
//  TransactionsTestTask
//
//  Created by Берлинский Ярослав Владленович on 22.08.2025.
//
//

import Foundation
import CoreData


extension CDTransaction {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDTransaction> {
        return NSFetchRequest<CDTransaction>(entityName: "CDTransaction")
    }

    @NSManaged public var id: UUID
    @NSManaged public var createdAt: Date
    @NSManaged public var amountSats: Int64
    @NSManaged public var type: Int16
    @NSManaged public var category: String?

}

extension CDTransaction : Identifiable {

}
