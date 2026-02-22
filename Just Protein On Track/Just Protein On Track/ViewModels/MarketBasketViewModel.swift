// MarketBasketViewModel.swift
// PriceKitchen
//
// ViewModel for the Market Basket tab.
// Manages GroceryItems and PriceTags: add, edit, delete, search, sort.

import SwiftUI
import CoreData
import Combine

// MARK: - Grocery Shelf Item (UI model)

struct GroceryShelfItem: Identifiable, Equatable {
    let id: String               // itemID
    let recipeName: String
    let marketStall: String
    let category: String
    let emoji: String
    let unitLabel: String
    let currencyCode: String
    let dateCreated: Date
    let isArchived: Bool
    let notes: String?
    var latestPrice: Double?
    var priceCount: Int
    var percentChange: Double?   // vs previous entry

    var formattedLatestPrice: String {
        guard let price = latestPrice else { return "—" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.string(from: NSNumber(value: price)) ?? "\(price)"
    }

    var changeColor: Color {
        guard let pct = percentChange else { return SpicePalette.peppercornFallback }
        if abs(pct) < 0.5 { return SpicePalette.peppercornFallback }
        return pct > 0 ? SpicePalette.chiliFlakeFallback : SpicePalette.basilLeafFallback
    }

    static func == (lhs: GroceryShelfItem, rhs: GroceryShelfItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Sort Seasoning

enum SortSeasoning: String, CaseIterable, Identifiable {
    case name    = "name"
    case recent  = "recent"
    case change  = "change"

    var id: String { rawValue }

    var labelKey: String {
        switch self {
        case .name:   return "basket.sort.name"
        case .recent: return "basket.sort.recent"
        case .change: return "basket.sort.change"
        }
    }
}

// MARK: - Grocery Category

enum GroceryCategory: String, CaseIterable, Identifiable {
    case dairy     = "dairy"
    case bread     = "bread"
    case meat      = "meat"
    case produce   = "produce"
    case drinks    = "drinks"
    case snacks    = "snacks"
    case household = "household"
    case other     = "other"

    var id: String { rawValue }

    var labelKey: String {
        switch self {
        case .dairy:     return "category.dairy"
        case .bread:     return "category.bread"
        case .meat:      return "category.meat"
        case .produce:   return "category.produce"
        case .drinks:    return "category.drinks"
        case .snacks:    return "category.snacks"
        case .household: return "category.household"
        case .other:     return "category.other"
        }
    }

    var defaultEmoji: String {
        switch self {
        case .dairy:     return "🥛"
        case .bread:     return "🍞"
        case .meat:      return "🥩"
        case .produce:   return "🥦"
        case .drinks:    return "🥤"
        case .snacks:    return "🍪"
        case .household: return "🧹"
        case .other:     return "🛒"
        }
    }
}

// MARK: - Market Basket ViewModel

final class MarketBasketViewModel: ObservableObject {

    // MARK: – Published State

    @Published var shelfItems: [GroceryShelfItem] = []
    @Published var searchQuery: String = ""
    @Published var activeSorting: SortSeasoning = .recent
    @Published var selectedCategory: GroceryCategory? = nil

    // Add Item Sheet
    @Published var showAddItemSheet = false
    @Published var validationError: String?  // Shown in alert when validation fails
    @Published var newRecipeName: String = ""
    @Published var newMarketStall: String = ""
    @Published var newCategory: GroceryCategory = .other
    @Published var newEmoji: String = "🛒"
    @Published var newUnitLabel: String = ""
    @Published var newCurrencyCode: String = "EUR"
    @Published var newNotes: String = ""

    // Add Price Sheet
    @Published var showAddPriceSheet = false
    @Published var priceTargetItemID: String = ""
    @Published var priceTargetName: String = ""
    @Published var newPriceAmount: String = ""
    @Published var newPriceMarket: String = ""
    @Published var newPriceMemo: String = ""

    // Deletion
    @Published var showDeleteConfirm = false
    @Published var deleteTargetID: String = ""

    // MARK: – Dependencies

    private let pantry: PantryStore

    // MARK: – Computed

    var filteredShelf: [GroceryShelfItem] {
        var result = shelfItems

        // Category filter
        if let cat = selectedCategory {
            result = result.filter { $0.category == cat.rawValue }
        }

        // Search filter
        if !searchQuery.isEmpty {
            let query = searchQuery.lowercased()
            result = result.filter {
                $0.recipeName.lowercased().contains(query) ||
                $0.marketStall.lowercased().contains(query)
            }
        }

        // Sorting
        switch activeSorting {
        case .name:
            result.sort { $0.recipeName.localizedCaseInsensitiveCompare($1.recipeName) == .orderedAscending }
        case .recent:
            result.sort { $0.dateCreated > $1.dateCreated }
        case .change:
            result.sort { abs($0.percentChange ?? 0) > abs($1.percentChange ?? 0) }
        }

        return result
    }

    // MARK: – Init

    init(pantry: PantryStore = .shared) {
        self.pantry = pantry
    }

    // MARK: – Load Shelf

    func stockShelves() {
        let items: [GroceryItem] = pantry.fetchAll(
            entity: "GroceryItem",
            sortKey: "dateCreated",
            ascending: false,
            predicate: NSPredicate(format: "isArchived == NO")
        )

        shelfItems = items.map { item in
            let (latestPrice, priceCount, percentChange) = fetchPriceSummary(for: item.itemID)

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
                percentChange: percentChange
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
        let latestAmount = latest.amount

        var pctChange: Double? = nil
        if tags.count >= 2, tags[1].amount > 0 {
            pctChange = ((latestAmount - tags[1].amount) / tags[1].amount) * 100
        }

        return (latestAmount, count, pctChange)
    }

    // MARK: – Add Grocery Item

    func addGroceryItem(using dashboardVM: KitchenDashboardViewModel? = nil) {
        let trimmedName = newRecipeName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedStore = newMarketStall.trimmingCharacters(in: .whitespacesAndNewlines)

        // Validation: product name required
        guard !trimmedName.isEmpty else {
            validationError = L10n.string("basket.validation.nameRequired")
            FlavorFeedback.burntSouffle()
            return
        }

        // Validation: max length (100 chars)
        guard trimmedName.count <= 100 else {
            validationError = L10n.string("basket.validation.nameTooLong")
            FlavorFeedback.burntSouffle()
            return
        }

        // Validation: no duplicate (same name + same store)
        let existing: [GroceryItem] = pantry.fetchAll(
            entity: "GroceryItem",
            sortKey: "dateCreated",
            predicate: NSPredicate(format: "isArchived == NO")
        )
        let isDuplicate = existing.contains { item in
            item.recipeName.lowercased() == trimmedName.lowercased() &&
            item.marketStall.lowercased() == trimmedStore.lowercased()
        }
        if isDuplicate {
            validationError = L10n.string("basket.validation.duplicate")
            FlavorFeedback.burntSouffle()
            return
        }

        let context = pantry.viewContext
        let entity = GroceryItem(context: context)
        let itemID = UUID().uuidString

        entity.itemID = itemID
        entity.recipeName = trimmedName
        entity.marketStall = trimmedStore
        entity.category = newCategory.rawValue
        entity.emoji = newEmoji
        entity.unitLabel = newUnitLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        entity.currencyCode = newCurrencyCode
        entity.dateCreated = Date()
        entity.isArchived = false
        entity.notes = newNotes.isEmpty ? nil : String(newNotes.prefix(500))

        pantry.stir()
        FlavorFeedback.goldenCrust()

        // Update profile counters & award XP
        if let vm = dashboardVM {
            vm.incrementDishesTracked()
            vm.awardXP(15)
        } else {
            updateProfileDishesTracked()
            awardXPToProfile(15)
        }

        // Check trophy: first dish
        checkTrophy_firstDish()

        // Check trophy: 5 items
        checkTrophy_fiveItems()

        resetAddItemForm()
        stockShelves()
    }

    func resetAddItemForm() {
        newRecipeName = ""
        newMarketStall = ""
        newCategory = .other
        newEmoji = "🛒"
        newUnitLabel = ""
        newCurrencyCode = "EUR"
        newNotes = ""
        showAddItemSheet = false
    }

    // MARK: – Add Price Tag

    func prepareAddPrice(for item: GroceryShelfItem) {
        priceTargetItemID = item.id
        priceTargetName = item.recipeName
        newPriceMarket = item.marketStall
        newPriceAmount = ""
        newPriceMemo = ""
        showAddPriceSheet = true
    }

    func addPriceTag(using dashboardVM: KitchenDashboardViewModel? = nil) {
        let normalizedInput = newPriceAmount.replacingOccurrences(of: ",", with: ".")
        guard let amount = Double(normalizedInput) else {
            validationError = L10n.string("basket.validation.priceInvalid")
            FlavorFeedback.burntSouffle()
            return
        }
        guard amount > 0 else {
            validationError = L10n.string("basket.validation.pricePositive")
            FlavorFeedback.burntSouffle()
            return
        }
        guard amount <= 999_999.99 else {
            validationError = L10n.string("basket.validation.priceTooHigh")
            FlavorFeedback.burntSouffle()
            return
        }

        let context = pantry.viewContext
        let tag = PriceTag(context: context)

        tag.tagID = UUID().uuidString
        tag.groceryItemID = priceTargetItemID
        tag.amount = amount
        tag.recordedAt = Date()
        tag.marketStall = newPriceMarket.trimmingCharacters(in: .whitespacesAndNewlines)
        tag.memo = newPriceMemo.isEmpty ? nil : String(newPriceMemo.prefix(200))
        tag.isFlagged = false

        pantry.stir()
        FlavorFeedback.goldenCrust()

        // Update profile counters & award XP
        if let vm = dashboardVM {
            vm.incrementPricesLogged()
            vm.awardXP(10)
        } else {
            updateProfilePricesLogged()
            awardXPToProfile(10)
        }

        // Check trophies
        checkTrophy_firstTag()
        checkTrophy_twentyTags()
        checkTrophy_fiftyTags()
        checkTrophy_hundredTags()
        checkTrophy_threeStores()

        resetAddPriceForm()
        stockShelves()
    }

    func resetAddPriceForm() {
        priceTargetItemID = ""
        priceTargetName = ""
        newPriceAmount = ""
        newPriceMarket = ""
        newPriceMemo = ""
        showAddPriceSheet = false
    }

    // MARK: – Delete Item

    func prepareDelete(for item: GroceryShelfItem) {
        deleteTargetID = item.id
        showDeleteConfirm = true
    }

    func confirmDelete() {
        guard !deleteTargetID.isEmpty else { return }

        // Delete all price tags for this item
        let tags: [PriceTag] = pantry.fetchAll(
            entity: "PriceTag",
            sortKey: "recordedAt",
            predicate: NSPredicate(format: "groceryItemID == %@", deleteTargetID)
        )
        for tag in tags {
            pantry.viewContext.delete(tag)
        }

        // Delete the item itself
        if let item: GroceryItem = pantry.fetchOne(
            entity: "GroceryItem",
            key: "itemID",
            value: deleteTargetID
        ) {
            pantry.viewContext.delete(item)
        }

        pantry.stir()
        FlavorFeedback.cleaverChop()

        deleteTargetID = ""
        showDeleteConfirm = false
        stockShelves()
    }

    // MARK: – Emoji Picker Presets

    static let emojiPantry: [String] = [
        "🛒", "🥛", "🧀", "🥚", "🍞", "🥖", "🥐", "🍕",
        "🥩", "🍗", "🐟", "🦐", "🥦", "🍎", "🍌", "🍊",
        "🥤", "☕", "🍺", "🧃", "🍪", "🍫", "🧁", "🍿",
        "🧹", "🧴", "🧻", "💊", "🧊", "🫒", "🍚", "🍝"
    ]

    // MARK: – Currency Presets

    static let currencyBowl: [(code: String, symbol: String)] = [
        ("EUR", "€"), ("USD", "$"), ("GBP", "£"), ("CHF", "Fr"),
        ("UAH", "₴"), ("PLN", "zł"), ("CZK", "Kč"),
        ("JPY", "¥"), ("CNY", "¥"), ("TRY", "₺"), ("INR", "₹")
    ]
}

// MARK: - Trophy Checks

extension MarketBasketViewModel {

    private func checkTrophy_firstDish() {
        let count = pantry.countDishes(entity: "GroceryItem")
        if count >= 1 {
            grantTrophyIfNeeded(
                badgeName: "firstDish",
                badgeEmoji: "🍳",
                flavorText: L10n.string("trophy.firstDish.desc"),
                xp: 25
            )
        }
    }

    private func checkTrophy_fiveItems() {
        let count = pantry.countDishes(entity: "GroceryItem")
        if count >= 5 {
            grantTrophyIfNeeded(
                badgeName: "fiveItems",
                badgeEmoji: "🗄️",
                flavorText: L10n.string("trophy.fiveItems.desc"),
                xp: 50
            )
        }
    }

    private func checkTrophy_firstTag() {
        let count = pantry.countDishes(entity: "PriceTag")
        if count >= 1 {
            grantTrophyIfNeeded(
                badgeName: "firstTag",
                badgeEmoji: "🏷️",
                flavorText: L10n.string("trophy.firstTag.desc"),
                xp: 25
            )
        }
    }

    private func checkTrophy_twentyTags() {
        let count = pantry.countDishes(entity: "PriceTag")
        if count >= 20 {
            grantTrophyIfNeeded(
                badgeName: "twentyTags",
                badgeEmoji: "🛍️",
                flavorText: L10n.string("trophy.twentyTags.desc"),
                xp: 75
            )
        }
    }

    private func checkTrophy_fiftyTags() {
        let count = pantry.countDishes(entity: "PriceTag")
        if count >= 50 {
            grantTrophyIfNeeded(
                badgeName: "fiftyTags",
                badgeEmoji: "🍷",
                flavorText: L10n.string("trophy.fiftyTags.desc"),
                xp: 100
            )
        }
    }

    private func checkTrophy_hundredTags() {
        let count = pantry.countDishes(entity: "PriceTag")
        if count >= 100 {
            grantTrophyIfNeeded(
                badgeName: "hundredTags",
                badgeEmoji: "👨‍🍳",
                flavorText: L10n.string("trophy.hundredTags.desc"),
                xp: 200
            )
        }
    }

    private func checkTrophy_threeStores() {
        let tags: [PriceTag] = pantry.fetchAll(
            entity: "PriceTag",
            sortKey: "recordedAt"
        )
        let uniqueStores = Set(tags.map { $0.marketStall })
        if uniqueStores.count >= 3 {
            grantTrophyIfNeeded(
                badgeName: "threeStores",
                badgeEmoji: "🏪",
                flavorText: L10n.string("trophy.threeStores.desc"),
                xp: 50
            )
        }
    }

    private func updateProfileDishesTracked() {
        guard let profile: ChefProfile = pantry.fetchOne(
            entity: "ChefProfile",
            key: "profileID",
            value: fetchFirstProfileID() ?? ""
        ) else { return }
        profile.dishesTracked += 1
        pantry.stir()
    }

    private func updateProfilePricesLogged() {
        guard let profile: ChefProfile = pantry.fetchOne(
            entity: "ChefProfile",
            key: "profileID",
            value: fetchFirstProfileID() ?? ""
        ) else { return }
        profile.pricesLogged += 1
        pantry.stir()
    }

    private func awardXPToProfile(_ amount: Int) {
        guard let profile: ChefProfile = pantry.fetchOne(
            entity: "ChefProfile",
            key: "profileID",
            value: fetchFirstProfileID() ?? ""
        ) else { return }
        let oldXP = Int(profile.totalXP)
        let newXP = oldXP + amount
        let newLevel = KitchenCoordinator.levelForXP(newXP)
        profile.totalXP = Int32(newXP)
        profile.currentLevel = Int32(newLevel)
        pantry.stir()
    }

    private func fetchFirstProfileID() -> String? {
        let profiles: [ChefProfile] = pantry.fetchAll(
            entity: "ChefProfile",
            sortKey: "memberSince",
            ascending: true
        )
        return profiles.first?.profileID
    }

    private func grantTrophyIfNeeded(badgeName: String, badgeEmoji: String, flavorText: String, xp: Int) {
        // Check if already earned
        let existing = pantry.countDishes(
            entity: "TrophyCase",
            predicate: NSPredicate(format: "badgeName == %@", badgeName)
        )
        guard existing == 0 else { return }

        // Create trophy
        let context = pantry.viewContext
        let trophy = TrophyCase(context: context)
        trophy.trophyID = UUID().uuidString
        trophy.badgeName = badgeName
        trophy.badgeEmoji = badgeEmoji
        trophy.flavorText = flavorText
        trophy.earnedAt = Date()
        trophy.xpReward = Int32(xp)
        pantry.stir()

        FlavorFeedback.champagneBubbles()
    }
}
