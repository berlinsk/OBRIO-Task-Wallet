//
//  CDRateCache+CoreDataProperties.swift
//  TransactionsTestTask
//
//  Created by Берлинский Ярослав Владленович on 22.08.2025.
//
//

import Foundation
import CoreData


extension CDRateCache {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDRateCache> {
        return NSFetchRequest<CDRateCache>(entityName: "CDRateCache")
    }

    @NSManaged public var id: String
    @NSManaged public var updatedAt: Date
    @NSManaged public var valueUsdPerBtc: NSDecimalNumber

}

extension CDRateCache : Identifiable {

}
