// PantryStore.swift
// PriceKitchen
//
// Core Data stack built programmatically.
// Models reference each other only via UUID strings — no direct relationships.
// The "Pantry" is our persistent storage: ingredients, receipts, and trophies.

import CoreData
import Foundation
import Combine

// MARK: - Pantry Store (Core Data Stack)

final class PantryStore {

    static let shared = PantryStore()

    /// Called when save fails — set by app to show user-facing alert.
    static var onSaveError: ((Error) -> Void)?

    /// Called when persistent store load fails.
    static var onLoadError: ((Error) -> Void)?

    // MARK: – Container

    let container: NSPersistentContainer

    /// Main context for UI reads.
    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    // MARK: – Init

    private init() {
        let model = PantryStore.buildManagedObjectModel()
        container = NSPersistentContainer(name: "PriceKitchen", managedObjectModel: model)

        let options: [String: Any] = [
            NSMigratePersistentStoresAutomaticallyOption: true,
            NSInferMappingModelAutomaticallyOption: true
        ]

        container.loadPersistentStores { _, error in
            if let error = error {
                #if DEBUG
                fatalError("🔥 Pantry failed to open: \(error.localizedDescription)")
                #else
                PantryStore.onLoadError?(error)
                #endif
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    // MARK: – Save

    /// Saves changes. Reports errors via onSaveError callback for user-facing alerts.
    func stir() {
        let context = viewContext
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            PantryStore.onSaveError?(error)
        }
    }

    /// Background context for heavy writes.
    func freshBowl() -> NSManagedObjectContext {
        let ctx = container.newBackgroundContext()
        ctx.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return ctx
    }
}

// MARK: - Programmatic Model Builder

extension PantryStore {

    /// Builds the entire NSManagedObjectModel in code.
    /// Entities reference each other ONLY via UUID string attributes — never via Core Data relationships.
    static func buildManagedObjectModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        // ── 1. GroceryItem — a product the user tracks ─────────────
        let groceryItem = NSEntityDescription()
        groceryItem.name = "GroceryItem"
        groceryItem.managedObjectClassName = "GroceryItem"
        groceryItem.properties = [
            stringAttr("itemID",        optional: false, defaultValue: ""),
            stringAttr("recipeName",    optional: false, defaultValue: ""),   // product name
            stringAttr("marketStall",   optional: false, defaultValue: ""),   // store name
            stringAttr("category",      optional: false, defaultValue: "other"),
            stringAttr("emoji",         optional: false, defaultValue: "🛒"),
            stringAttr("unitLabel",     optional: false, defaultValue: ""),   // e.g. "1 kg", "500 ml"
            stringAttr("currencyCode",  optional: false, defaultValue: "EUR"),
            dateAttr("dateCreated",     optional: false),
            boolAttr("isArchived",      defaultValue: false),
            stringAttr("notes",         optional: true,  defaultValue: nil)
        ]

        // ── 2. PriceTag — a single price recording for a GroceryItem ──
        let priceTag = NSEntityDescription()
        priceTag.name = "PriceTag"
        priceTag.managedObjectClassName = "PriceTag"
        priceTag.properties = [
            stringAttr("tagID",         optional: false, defaultValue: ""),
            stringAttr("groceryItemID", optional: false, defaultValue: ""),   // FK → GroceryItem.itemID
            doubleAttr("amount",        optional: false, defaultValue: 0.0),
            dateAttr("recordedAt",      optional: false),
            stringAttr("marketStall",   optional: false, defaultValue: ""),   // store at time of purchase
            stringAttr("memo",          optional: true,  defaultValue: nil),
            boolAttr("isFlagged",       defaultValue: false)
        ]

        // ── 3. TrophyCase — gamification achievements ──────────────
        let trophyCase = NSEntityDescription()
        trophyCase.name = "TrophyCase"
        trophyCase.managedObjectClassName = "TrophyCase"
        trophyCase.properties = [
            stringAttr("trophyID",      optional: false, defaultValue: ""),
            stringAttr("badgeName",     optional: false, defaultValue: ""),
            stringAttr("badgeEmoji",    optional: false, defaultValue: "🏆"),
            stringAttr("flavorText",    optional: false, defaultValue: ""),   // description
            dateAttr("earnedAt",        optional: false),
            int32Attr("xpReward",       optional: false, defaultValue: 0)
        ]

        // ── 4. ChefProfile — single-row user profile ──────────────
        let chefProfile = NSEntityDescription()
        chefProfile.name = "ChefProfile"
        chefProfile.managedObjectClassName = "ChefProfile"
        chefProfile.properties = [
            stringAttr("profileID",     optional: false, defaultValue: ""),
            stringAttr("chefName",      optional: false, defaultValue: "Chef"),
            stringAttr("avatarEmoji",   optional: false, defaultValue: "👨‍🍳"),
            int32Attr("totalXP",        optional: false, defaultValue: 0),
            int32Attr("currentLevel",   optional: false, defaultValue: 1),
            int32Attr("dishesTracked",  optional: false, defaultValue: 0),   // lifetime item count
            int32Attr("pricesLogged",   optional: false, defaultValue: 0),   // lifetime price entries
            stringAttr("accentFlavor",  optional: false, defaultValue: "saffron"),
            dateAttr("memberSince",     optional: false),
            dateAttr("lastActiveAt",    optional: true)
        ]

        // ── 5. MarketVisit — a "shopping trip" grouping (optional) ─
        let marketVisit = NSEntityDescription()
        marketVisit.name = "MarketVisit"
        marketVisit.managedObjectClassName = "MarketVisit"
        marketVisit.properties = [
            stringAttr("visitID",       optional: false, defaultValue: ""),
            stringAttr("marketStall",   optional: false, defaultValue: ""),
            dateAttr("visitDate",       optional: false),
            int32Attr("tagsCount",      optional: false, defaultValue: 0),   // how many prices logged
            doubleAttr("totalSpent",    optional: false, defaultValue: 0.0),
            stringAttr("notes",         optional: true,  defaultValue: nil)
        ]

        // ── 6. RecipePot — a recipe (dish) the user tracks ─────────────
        let recipePot = NSEntityDescription()
        recipePot.name = "RecipePot"
        recipePot.managedObjectClassName = "RecipePot"
        recipePot.properties = [
            stringAttr("potID",         optional: false, defaultValue: ""),
            stringAttr("dishName",       optional: false, defaultValue: ""),
            stringAttr("dishEmoji",      optional: false, defaultValue: "🍝"),
            int32Attr("servings",        optional: false, defaultValue: 4),
            dateAttr("dateCreated",      optional: false),
            stringAttr("notes",          optional: true,  defaultValue: nil)
        ]

        // ── 7. RecipeIngredientLink — recipe ↔ product link ───────────
        let recipeIngredientLink = NSEntityDescription()
        recipeIngredientLink.name = "RecipeIngredientLink"
        recipeIngredientLink.managedObjectClassName = "RecipeIngredientLink"
        recipeIngredientLink.properties = [
            stringAttr("linkID",         optional: false, defaultValue: ""),
            stringAttr("potID",           optional: false, defaultValue: ""),   // FK → RecipePot
            stringAttr("groceryItemID",   optional: false, defaultValue: ""),   // FK → GroceryItem
            doubleAttr("quantityNeeded",  optional: false, defaultValue: 1.0),
            stringAttr("quantityUnit",    optional: false, defaultValue: "pcs")
        ]

        model.entities = [groceryItem, priceTag, trophyCase, chefProfile, marketVisit, recipePot, recipeIngredientLink]
        return model
    }
}

// MARK: - Attribute Helpers

private extension PantryStore {

    static func stringAttr(_ name: String, optional: Bool, defaultValue: String?) -> NSAttributeDescription {
        let attr = NSAttributeDescription()
        attr.name = name
        attr.attributeType = .stringAttributeType
        attr.isOptional = optional
        if let dv = defaultValue { attr.defaultValue = dv }
        return attr
    }

    static func doubleAttr(_ name: String, optional: Bool, defaultValue: Double) -> NSAttributeDescription {
        let attr = NSAttributeDescription()
        attr.name = name
        attr.attributeType = .doubleAttributeType
        attr.isOptional = optional
        attr.defaultValue = defaultValue
        return attr
    }

    static func int32Attr(_ name: String, optional: Bool, defaultValue: Int32) -> NSAttributeDescription {
        let attr = NSAttributeDescription()
        attr.name = name
        attr.attributeType = .integer32AttributeType
        attr.isOptional = optional
        attr.defaultValue = defaultValue
        return attr
    }

    static func dateAttr(_ name: String, optional: Bool) -> NSAttributeDescription {
        let attr = NSAttributeDescription()
        attr.name = name
        attr.attributeType = .dateAttributeType
        attr.isOptional = optional
        return attr
    }

    static func boolAttr(_ name: String, defaultValue: Bool) -> NSAttributeDescription {
        let attr = NSAttributeDescription()
        attr.name = name
        attr.attributeType = .booleanAttributeType
        attr.isOptional = false
        attr.defaultValue = defaultValue
        return attr
    }
}

// MARK: - Convenience Fetch Helpers

extension PantryStore {

    /// Fetch all objects of an entity sorted by a key.
    func fetchAll<T: NSManagedObject>(
        entity: String,
        sortKey: String,
        ascending: Bool = true,
        predicate: NSPredicate? = nil
    ) -> [T] {
        let request = NSFetchRequest<T>(entityName: entity)
        request.sortDescriptors = [NSSortDescriptor(key: sortKey, ascending: ascending)]
        request.predicate = predicate
        do {
            return try viewContext.fetch(request)
        } catch {
            print("🍴 Fetch failed for \(entity): \(error.localizedDescription)")
            return []
        }
    }

    /// Fetch a single object by a unique string key.
    func fetchOne<T: NSManagedObject>(entity: String, key: String, value: String) -> T? {
        let request = NSFetchRequest<T>(entityName: entity)
        request.predicate = NSPredicate(format: "%K == %@", key, value)
        request.fetchLimit = 1
        return try? viewContext.fetch(request).first
    }

    /// Count objects in an entity.
    func countDishes(entity: String, predicate: NSPredicate? = nil) -> Int {
        let request = NSFetchRequest<NSManagedObject>(entityName: entity)
        request.predicate = predicate
        return (try? viewContext.count(for: request)) ?? 0
    }

    /// Delete a single managed object and save.
    func tossInTrash(_ object: NSManagedObject) {
        viewContext.delete(object)
        stir()
    }
}

// MARK: - First Launch Seeding

extension PantryStore {

    /// Creates the default ChefProfile if none exists yet.
    func seedKitchenIfNeeded() {
        let count = countDishes(entity: "ChefProfile")
        guard count == 0 else { return }

        let profile = ChefProfile(context: viewContext)
        profile.profileID = UUID().uuidString
        profile.chefName = "Chef"
        profile.avatarEmoji = "👨‍🍳"
        profile.totalXP = 0
        profile.currentLevel = 1
        profile.dishesTracked = 0
        profile.pricesLogged = 0
        profile.accentFlavor = "saffron"
        profile.memberSince = Date()

        stir()
    }
}
