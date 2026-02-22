// ManagedModels.swift
// PriceKitchen
//
// NSManagedObject subclasses for type-safe Core Data access.
// Replaces fragile setValue/value(forKey:) with typed properties.

import CoreData

// MARK: - GroceryItem

@objc(GroceryItem)
public class GroceryItem: NSManagedObject {

    @NSManaged public var itemID: String
    @NSManaged public var recipeName: String
    @NSManaged public var marketStall: String
    @NSManaged public var category: String
    @NSManaged public var emoji: String
    @NSManaged public var unitLabel: String
    @NSManaged public var currencyCode: String
    @NSManaged public var dateCreated: Date
    @NSManaged public var isArchived: Bool
    @NSManaged public var notes: String?
}

// MARK: - PriceTag

@objc(PriceTag)
public class PriceTag: NSManagedObject {

    @NSManaged public var tagID: String
    @NSManaged public var groceryItemID: String
    @NSManaged public var amount: Double
    @NSManaged public var recordedAt: Date
    @NSManaged public var marketStall: String
    @NSManaged public var memo: String?
    @NSManaged public var isFlagged: Bool
}

// MARK: - TrophyCase

@objc(TrophyCase)
public class TrophyCase: NSManagedObject {

    @NSManaged public var trophyID: String
    @NSManaged public var badgeName: String
    @NSManaged public var badgeEmoji: String
    @NSManaged public var flavorText: String
    @NSManaged public var earnedAt: Date
    @NSManaged public var xpReward: Int32
}

// MARK: - ChefProfile

@objc(ChefProfile)
public class ChefProfile: NSManagedObject {

    @NSManaged public var profileID: String
    @NSManaged public var chefName: String
    @NSManaged public var avatarEmoji: String
    @NSManaged public var totalXP: Int32
    @NSManaged public var currentLevel: Int32
    @NSManaged public var dishesTracked: Int32
    @NSManaged public var pricesLogged: Int32
    @NSManaged public var accentFlavor: String
    @NSManaged public var memberSince: Date
    @NSManaged public var lastActiveAt: Date?
}

// MARK: - MarketVisit

@objc(MarketVisit)
public class MarketVisit: NSManagedObject {

    @NSManaged public var visitID: String
    @NSManaged public var marketStall: String
    @NSManaged public var visitDate: Date
    @NSManaged public var tagsCount: Int32
    @NSManaged public var totalSpent: Double
    @NSManaged public var notes: String?
}

// MARK: - RecipePot

@objc(RecipePot)
public class RecipePot: NSManagedObject {

    @NSManaged public var potID: String
    @NSManaged public var dishName: String
    @NSManaged public var dishEmoji: String
    @NSManaged public var servings: Int32
    @NSManaged public var dateCreated: Date
    @NSManaged public var notes: String?
}

// MARK: - RecipeIngredientLink

@objc(RecipeIngredientLink)
public class RecipeIngredientLink: NSManagedObject {

    @NSManaged public var linkID: String
    @NSManaged public var potID: String
    @NSManaged public var groceryItemID: String
    @NSManaged public var quantityNeeded: Double
    @NSManaged public var quantityUnit: String
}
