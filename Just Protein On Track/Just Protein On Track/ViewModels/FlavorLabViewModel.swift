// FlavorLabViewModel.swift
// PriceKitchen
//
// ViewModel for the Flavor Lab tab (Recipe Builder).
// Manages recipes (RecipePot) and ingredient links. Calculates dish cost from latest prices.

import SwiftUI
import CoreData
import Combine

// MARK: - Recipe Card (UI model)

struct RecipeCard: Identifiable {
    let id: String
    let dishName: String
    let dishEmoji: String
    let servings: Int32
    let dateCreated: Date
    let totalCost: Double?
    let currencyCode: String
    let ingredientCount: Int

    var formattedCost: String {
        guard let cost = totalCost, cost > 0 else { return "—" }
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = currencyCode
        return f.string(from: NSNumber(value: cost)) ?? "\(cost)"
    }
}

// MARK: - Pending Ingredient (for new recipe form)

struct PendingIngredient: Identifiable {
    let id: String
    let groceryItemID: String
    let recipeName: String
    let emoji: String
    let quantityNeeded: Double
    let quantityUnit: String
    var needsToBuy: Bool
}

// MARK: - Recipe Ingredient Row (UI model)

struct RecipeIngredientRow: Identifiable {
    let id: String
    let groceryItemID: String
    let recipeName: String
    let emoji: String
    let quantityNeeded: Double
    let quantityUnit: String
    let unitPrice: Double?
    let currencyCode: String
    let lineCost: Double?

    var formattedLineCost: String {
        guard let cost = lineCost, cost > 0 else { return "—" }
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = currencyCode
        return f.string(from: NSNumber(value: cost)) ?? "\(cost)"
    }
}

// MARK: - Flavor Lab ViewModel

final class FlavorLabViewModel: ObservableObject {

    @Published var recipes: [RecipeCard] = []
    @Published var selectedRecipeID: String?

    // New recipe form
    @Published var showNewRecipeSheet = false
    @Published var newDishName: String = ""
    @Published var newDishEmoji: String = "🍝"
    @Published var newServings: Int32 = 4

    // Add ingredient to recipe
    @Published var showAddIngredientSheet = false
    @Published var addIngredientTargetPotID: String = ""
    @Published var addIngredientSelectedItemID: String = ""
    @Published var addIngredientQuantity: String = "1"
    @Published var addIngredientUnit: String = "pcs"

    /// Pending ingredients for a new recipe (before it's saved).
    @Published var pendingNewRecipeIngredients: [PendingIngredient] = []

    /// Form for adding a NEW ingredient (like in Basket).
    @Published var newIngredientName: String = ""
    @Published var newIngredientEmoji: String = "🛒"
    @Published var newIngredientCategory: GroceryCategory = .other
    @Published var newIngredientUnit: String = "pcs"
    @Published var newIngredientQuantity: String = "1"

    @Published var validationError: String?

    @Published var searchText: String = ""
    @Published var sortOption: LabSortOption = .recent

    private let pantry: PantryStore

    enum LabSortOption: String, CaseIterable {
        case recent
        case name
        case cost
        case ingredients
    }

    var filteredRecipes: [RecipeCard] {
        var list = recipes
        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
            list = list.filter { $0.dishName.lowercased().contains(q) }
        }
        switch sortOption {
        case .recent:
            list.sort { $0.dateCreated > $1.dateCreated }
        case .name:
            list.sort { $0.dishName.localizedCaseInsensitiveCompare($1.dishName) == .orderedAscending }
        case .cost:
            list.sort { ($0.totalCost ?? 0) > ($1.totalCost ?? 0) }
        case .ingredients:
            list.sort { $0.ingredientCount > $1.ingredientCount }
        }
        return list
    }

    init(pantry: PantryStore = .shared) {
        self.pantry = pantry
    }

    // MARK: – Load Recipes

    func brewRecipes() {
        let pots: [RecipePot] = pantry.fetchAll(
            entity: "RecipePot",
            sortKey: "dateCreated",
            ascending: false
        )

        recipes = pots.map { pot in
            let (cost, currency, count) = computeRecipeCost(potID: pot.potID)
            return RecipeCard(
                id: pot.potID,
                dishName: pot.dishName,
                dishEmoji: pot.dishEmoji,
                servings: pot.servings,
                dateCreated: pot.dateCreated,
                totalCost: cost,
                currencyCode: currency,
                ingredientCount: count
            )
        }
    }

    private func computeRecipeCost(potID: String) -> (Double?, String, Int) {
        let links: [RecipeIngredientLink] = pantry.fetchAll(
            entity: "RecipeIngredientLink",
            sortKey: "linkID",
            predicate: NSPredicate(format: "potID == %@", potID)
        )

        var total: Double = 0
        var currencyCode = "EUR"

        for link in links {
            let tags: [PriceTag] = pantry.fetchAll(
                entity: "PriceTag",
                sortKey: "recordedAt",
                ascending: false,
                predicate: NSPredicate(format: "groceryItemID == %@", link.groceryItemID)
            )
            guard let latest = tags.first else { continue }

            if let item: GroceryItem = pantry.fetchOne(
                entity: "GroceryItem",
                key: "itemID",
                value: link.groceryItemID
            ) {
                currencyCode = item.currencyCode
            }

            let lineCost = latest.amount * link.quantityNeeded
            total += lineCost
        }

        return (total > 0 ? total : nil, currencyCode, links.count)
    }

    // MARK: – Create Recipe

    func createRecipe() {
        let trimmed = newDishName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            validationError = L10n.string("lab.validation.nameRequired")
            return
        }
        guard trimmed.count <= 80 else {
            validationError = L10n.string("lab.validation.nameTooLong")
            return
        }

        let potID = UUID().uuidString
        let pot = RecipePot(context: pantry.viewContext)
        pot.potID = potID
        pot.dishName = trimmed
        pot.dishEmoji = newDishEmoji
        pot.servings = max(1, newServings)
        pot.dateCreated = Date()
        pot.notes = nil

        for pending in pendingNewRecipeIngredients {
            let link = RecipeIngredientLink(context: pantry.viewContext)
            link.linkID = UUID().uuidString
            link.potID = potID
            link.groceryItemID = pending.groceryItemID
            link.quantityNeeded = pending.quantityNeeded
            link.quantityUnit = pending.quantityUnit

            if pending.needsToBuy {
                ToBuyStore.shared.add(itemID: pending.groceryItemID)
            }
        }

        pantry.stir()
        FlavorFeedback.goldenCrust()

        resetNewRecipeForm()
        brewRecipes()
    }

    func resetNewRecipeForm() {
        newDishName = ""
        newDishEmoji = "🍝"
        newServings = 4
        pendingNewRecipeIngredients = []
        resetNewIngredientForm()
        showNewRecipeSheet = false
    }

    // MARK: – Add Ingredient to Recipe

    func prepareAddIngredient(potID: String) {
        addIngredientTargetPotID = potID
        addIngredientSelectedItemID = ""
        addIngredientQuantity = "1"
        addIngredientUnit = "pcs"
        showAddIngredientSheet = true
    }

    /// Opens the add-ingredient sheet for the new recipe form (before save).
    func prepareAddIngredientForNewRecipe() {
        addIngredientTargetPotID = "__new__"
        addIngredientSelectedItemID = ""
        addIngredientQuantity = "1"
        addIngredientUnit = "pcs"
        showAddIngredientSheet = true
    }

    func removePendingIngredient(id: String) {
        pendingNewRecipeIngredients.removeAll { $0.id == id }
    }

    func addPendingIngredient(_ pending: PendingIngredient) {
        pendingNewRecipeIngredients.append(pending)
    }

    func togglePendingIngredientNeedsToBuy(id: String) {
        guard let idx = pendingNewRecipeIngredients.firstIndex(where: { $0.id == id }) else { return }
        var ing = pendingNewRecipeIngredients[idx]
        ing = PendingIngredient(
            id: ing.id,
            groceryItemID: ing.groceryItemID,
            recipeName: ing.recipeName,
            emoji: ing.emoji,
            quantityNeeded: ing.quantityNeeded,
            quantityUnit: ing.quantityUnit,
            needsToBuy: !ing.needsToBuy
        )
        pendingNewRecipeIngredients[idx] = ing
    }

    /// Creates a new GroceryItem (or reuses existing) and adds to pending. Like Basket's add.
    func addNewIngredientToRecipe() {
        let trimmedName = newIngredientName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            validationError = L10n.string("basket.validation.nameRequired")
            return
        }
        guard trimmedName.count <= 100 else {
            validationError = L10n.string("basket.validation.nameTooLong")
            return
        }

        let existing: [GroceryItem] = pantry.fetchAll(
            entity: "GroceryItem",
            sortKey: "dateCreated",
            predicate: NSPredicate(format: "isArchived == NO")
        )
        let trimmedStore = ""
        let duplicate = existing.first { item in
            item.recipeName.lowercased() == trimmedName.lowercased() &&
            item.marketStall.lowercased() == trimmedStore.lowercased()
        }

        let itemID: String
        let recipeName: String
        let emoji: String

        if let item = duplicate {
            itemID = item.itemID
            recipeName = item.recipeName
            emoji = item.emoji
        } else {
            itemID = UUID().uuidString
            recipeName = trimmedName
            emoji = newIngredientEmoji

            let entity = GroceryItem(context: pantry.viewContext)
            entity.itemID = itemID
            entity.recipeName = recipeName
            entity.marketStall = trimmedStore
            entity.category = newIngredientCategory.rawValue
            entity.emoji = emoji
            entity.unitLabel = newIngredientUnit
            entity.currencyCode = "EUR"
            entity.dateCreated = Date()
            entity.isArchived = false
            entity.notes = nil
            pantry.stir()
        }

        let qtyStr = newIngredientQuantity.replacingOccurrences(of: ",", with: ".")
        let qty = Double(qtyStr) ?? 1
        let qtyValid = max(0.1, qty)

        let pending = PendingIngredient(
            id: UUID().uuidString,
            groceryItemID: itemID,
            recipeName: recipeName,
            emoji: emoji,
            quantityNeeded: qtyValid,
            quantityUnit: newIngredientUnit.isEmpty ? "pcs" : newIngredientUnit,
            needsToBuy: true
        )
        pendingNewRecipeIngredients.append(pending)

        newIngredientName = ""
        newIngredientEmoji = "🛒"
        newIngredientCategory = .other
        newIngredientUnit = "pcs"
        newIngredientQuantity = "1"
    }

    func resetNewIngredientForm() {
        newIngredientName = ""
        newIngredientEmoji = "🛒"
        newIngredientCategory = .other
        newIngredientUnit = "pcs"
        newIngredientQuantity = "1"
    }

    /// Adds a new GroceryItem (or reuses) and links it to an existing recipe.
    @discardableResult
    func addNewIngredientToExistingRecipe() -> Bool {
        guard !addIngredientTargetPotID.isEmpty, addIngredientTargetPotID != "__new__" else { return false }

        let trimmedName = newIngredientName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            validationError = L10n.string("basket.validation.nameRequired")
            return false
        }
        guard trimmedName.count <= 100 else {
            validationError = L10n.string("basket.validation.nameTooLong")
            return false
        }

        let existing: [GroceryItem] = pantry.fetchAll(
            entity: "GroceryItem",
            sortKey: "dateCreated",
            predicate: NSPredicate(format: "isArchived == NO")
        )
        let trimmedStore = ""
        let duplicate = existing.first { item in
            item.recipeName.lowercased() == trimmedName.lowercased() &&
            item.marketStall.lowercased() == trimmedStore.lowercased()
        }

        let itemID: String
        if let item = duplicate {
            itemID = item.itemID
        } else {
            itemID = UUID().uuidString
            let entity = GroceryItem(context: pantry.viewContext)
            entity.itemID = itemID
            entity.recipeName = trimmedName
            entity.marketStall = trimmedStore
            entity.category = newIngredientCategory.rawValue
            entity.emoji = newIngredientEmoji
            entity.unitLabel = newIngredientUnit
            entity.currencyCode = "EUR"
            entity.dateCreated = Date()
            entity.isArchived = false
            entity.notes = nil
            pantry.stir()
        }

        let qtyStr = newIngredientQuantity.replacingOccurrences(of: ",", with: ".")
        let qty = max(0.1, Double(qtyStr) ?? 1)

        let link = RecipeIngredientLink(context: pantry.viewContext)
        link.linkID = UUID().uuidString
        link.potID = addIngredientTargetPotID
        link.groceryItemID = itemID
        link.quantityNeeded = qty
        link.quantityUnit = newIngredientUnit.isEmpty ? "pcs" : newIngredientUnit

        pantry.stir()
        resetNewIngredientForm()
        showAddIngredientSheet = false
        addIngredientTargetPotID = ""
        brewRecipes()
        return true
    }

    func addIngredientToRecipe() {
        guard !addIngredientSelectedItemID.isEmpty else {
            validationError = L10n.string("lab.validation.selectProduct")
            return
        }

        let qtyStr = addIngredientQuantity.replacingOccurrences(of: ",", with: ".")
        guard let qty = Double(qtyStr), qty > 0 else {
            validationError = L10n.string("basket.validation.pricePositive")
            return
        }

        if addIngredientTargetPotID == "__new__" {
            // Adding to pending list for new recipe
            guard let item: GroceryItem = pantry.fetchOne(
                entity: "GroceryItem",
                key: "itemID",
                value: addIngredientSelectedItemID
            ) else { return }

            let pending = PendingIngredient(
                id: UUID().uuidString,
                groceryItemID: item.itemID,
                recipeName: item.recipeName,
                emoji: item.emoji,
                quantityNeeded: qty,
                quantityUnit: addIngredientUnit.isEmpty ? "pcs" : addIngredientUnit,
                needsToBuy: true
            )
            pendingNewRecipeIngredients.append(pending)
            FlavorFeedback.goldenCrust()

            showAddIngredientSheet = false
            addIngredientTargetPotID = ""
            addIngredientSelectedItemID = ""
            return
        }

        guard !addIngredientTargetPotID.isEmpty else { return }

        let link = RecipeIngredientLink(context: pantry.viewContext)
        link.linkID = UUID().uuidString
        link.potID = addIngredientTargetPotID
        link.groceryItemID = addIngredientSelectedItemID
        link.quantityNeeded = qty
        link.quantityUnit = addIngredientUnit.isEmpty ? "pcs" : addIngredientUnit

        pantry.stir()
        FlavorFeedback.goldenCrust()

        showAddIngredientSheet = false
        addIngredientTargetPotID = ""
        addIngredientSelectedItemID = ""
        brewRecipes()
    }

    // MARK: – Delete Recipe

    func deleteRecipe(potID: String) {
        let links: [RecipeIngredientLink] = pantry.fetchAll(
            entity: "RecipeIngredientLink",
            sortKey: "linkID",
            predicate: NSPredicate(format: "potID == %@", potID)
        )
        for link in links {
            pantry.viewContext.delete(link)
        }

        if let pot: RecipePot = pantry.fetchOne(
            entity: "RecipePot",
            key: "potID",
            value: potID
        ) {
            pantry.viewContext.delete(pot)
        }

        pantry.stir()
        FlavorFeedback.cleaverChop()
        brewRecipes()
    }

    // MARK: – Available Grocery Items (for picker)

    func availableGroceryItems() -> [GroceryShelfItem] {
        let items: [GroceryItem] = pantry.fetchAll(
            entity: "GroceryItem",
            sortKey: "recipeName",
            ascending: true,
            predicate: NSPredicate(format: "isArchived == NO")
        )

        return items.map { item in
            let (latestPrice, priceCount, _) = fetchPriceSummary(for: item.itemID)
            return GroceryShelfItem(
                id: item.itemID,
                recipeName: item.recipeName,
                marketStall: item.marketStall,
                category: item.category,
                emoji: item.emoji,
                unitLabel: item.unitLabel,
                currencyCode: item.currencyCode,
                dateCreated: item.dateCreated,
                isArchived: item.isArchived,
                notes: item.notes,
                latestPrice: latestPrice,
                priceCount: priceCount,
                percentChange: nil
            )
        }
    }

    private func fetchPriceSummary(for itemID: String) -> (Double?, Int, Double?) {
        let tags: [PriceTag] = pantry.fetchAll(
            entity: "PriceTag",
            sortKey: "recordedAt",
            ascending: false,
            predicate: NSPredicate(format: "groceryItemID == %@", itemID)
        )
        let count = tags.count
        guard let latest = tags.first else { return (nil, 0, nil) }
        var pctChange: Double? = nil
        if tags.count >= 2, tags[1].amount > 0 {
            pctChange = ((latest.amount - tags[1].amount) / tags[1].amount) * 100
        }
        return (latest.amount, count, pctChange)
    }

    // MARK: – Recipe Ingredients (for detail)

    func ingredientsForRecipe(potID: String) -> [RecipeIngredientRow] {
        let links: [RecipeIngredientLink] = pantry.fetchAll(
            entity: "RecipeIngredientLink",
            sortKey: "linkID",
            predicate: NSPredicate(format: "potID == %@", potID)
        )

        return links.compactMap { link in
            guard let item: GroceryItem = pantry.fetchOne(
                entity: "GroceryItem",
                key: "itemID",
                value: link.groceryItemID
            ) else { return nil }

            let tags: [PriceTag] = pantry.fetchAll(
                entity: "PriceTag",
                sortKey: "recordedAt",
                ascending: false,
                predicate: NSPredicate(format: "groceryItemID == %@", link.groceryItemID)
            )
            let unitPrice = tags.first?.amount
            let lineCost = unitPrice.map { $0 * link.quantityNeeded }

            return RecipeIngredientRow(
                id: link.linkID,
                groceryItemID: link.groceryItemID,
                recipeName: item.recipeName,
                emoji: item.emoji,
                quantityNeeded: link.quantityNeeded,
                quantityUnit: link.quantityUnit,
                unitPrice: unitPrice,
                currencyCode: item.currencyCode,
                lineCost: lineCost
            )
        }
    }

    static let dishEmojis = ["🍝", "🍲", "🥗", "🍛", "🍜", "🥘", "🍕", "🍔", "🥪", "🍳", "🥣", "🍽️"]
    static let quantityUnits = ["pcs", "kg", "g", "L", "ml", "oz", "lb", "cup", "tbsp", "tsp"]
}
