// SpiceRackViewModel.swift
// PriceKitchen
//
// ViewModel for the Spice Rack (Settings) tab.
// Chef profile editing, avatar emoji picker, accent flavor,
// kitchen stats, trophy case, CSV export, and danger-zone reset.

import SwiftUI
import CoreData
import Combine

// MARK: - Trophy Ribbon (UI model)

struct TrophyRibbon: Identifiable {
    let id: String
    let badgeName: String
    let badgeEmoji: String
    let flavorText: String
    let earnedAt: Date
    let xpReward: Int

    var localizedName: String {
        L10n.string("trophy.\(badgeName)")
    }

    var formattedDate: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: earnedAt)
    }
}

// MARK: - Kitchen Stat Row (UI model)

struct KitchenStatRow: Identifiable {
    let id = UUID()
    let emoji: String
    let labelKey: String
    let value: String
}

// MARK: - Spice Rack ViewModel

final class SpiceRackViewModel: ObservableObject {

    // MARK: – Published State: Profile

    @Published var chefName: String = "Chef"
    @Published var avatarEmoji: String = "👨‍🍳"
    @Published var memberSince: Date = Date()
    @Published var accentFlavor: AccentFlavor = .saffron

    // MARK: – Published State: Stats

    @Published var statRows: [KitchenStatRow] = []
    @Published var totalXP: Int = 0
    @Published var currentLevel: Int = 1

    // MARK: – Published State: Trophies

    @Published var trophies: [TrophyRibbon] = []

    // MARK: – Published State: Sheets & Alerts

    @Published var showAvatarPicker = false
    @Published var showExportSheet = false
    @Published var showResetConfirm = false
    @Published var showTrophyCase = false
    @Published var exportCSVURL: URL? = nil

    // MARK: – Dependencies

    private let pantry: PantryStore

    // MARK: – Avatar Emoji Catalog

    static let avatarCatalog: [String] = [
        "👨‍🍳", "👩‍🍳", "🧑‍🍳", "🍳", "🔥", "🧁", "🍕", "🍔",
        "🌮", "🍣", "🥗", "🍩", "🦊", "🐻", "🐱", "🐶",
        "🦁", "🐸", "🐧", "🦉", "🤖", "👾", "🎃", "💀",
        "🧙", "🥷", "🦸", "🧛", "🌟", "💎", "🪐", "🌈"
    ]

    // MARK: – Init

    init(pantry: PantryStore = .shared) {
        self.pantry = pantry
    }

    // MARK: – Load Everything

    func openSpiceJars() {
        loadProfile()
        loadStats()
        loadTrophies()
    }

    // MARK: – Profile Loading

    private func loadProfile() {
        guard let profile = firstProfile() else { return }

        chefName = profile.value(forKey: "chefName") as? String ?? "Chef"
        avatarEmoji = profile.value(forKey: "avatarEmoji") as? String ?? "👨‍🍳"
        memberSince = profile.value(forKey: "memberSince") as? Date ?? Date()
        totalXP = Int(profile.value(forKey: "totalXP") as? Int32 ?? 0)
        currentLevel = KitchenCoordinator.levelForXP(totalXP)

        let raw = profile.value(forKey: "accentFlavor") as? String ?? "saffron"
        accentFlavor = AccentFlavor(rawValue: raw) ?? .saffron
    }

    // MARK: – Stats

    private func loadStats() {
        let itemCount = pantry.countDishes(entity: "GroceryItem")
        let priceCount = pantry.countDishes(entity: "PriceTag")
        let trophyCount = pantry.countDishes(entity: "TrophyCase")

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none

        statRows = [
            KitchenStatRow(
                emoji: "🧺",
                labelKey: "spice.stats.items",
                value: "\(itemCount)"
            ),
            KitchenStatRow(
                emoji: "🏷️",
                labelKey: "spice.stats.prices",
                value: "\(priceCount)"
            ),
            KitchenStatRow(
                emoji: "🏆",
                labelKey: "spice.stats.trophies",
                value: "\(trophyCount)"
            ),
            KitchenStatRow(
                emoji: "📅",
                labelKey: "spice.stats.memberSince",
                value: dateFormatter.string(from: memberSince)
            )
        ]
    }

    // MARK: – Trophies

    private func loadTrophies() {
        let objects: [NSManagedObject] = pantry.fetchAll(
            entity: "TrophyCase",
            sortKey: "earnedAt",
            ascending: false
        )

        trophies = objects.map { obj in
            TrophyRibbon(
                id: obj.value(forKey: "trophyID") as? String ?? UUID().uuidString,
                badgeName: obj.value(forKey: "badgeName") as? String ?? "",
                badgeEmoji: obj.value(forKey: "badgeEmoji") as? String ?? "🏆",
                flavorText: obj.value(forKey: "flavorText") as? String ?? "",
                earnedAt: obj.value(forKey: "earnedAt") as? Date ?? Date(),
                xpReward: Int(obj.value(forKey: "xpReward") as? Int32 ?? 0)
            )
        }
    }

    // MARK: – Save Chef Name

    func saveChefName() {
        guard let profile = firstProfile() else { return }
        let trimmed = chefName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            chefName = "Chef"
            return
        }
        profile.setValue(trimmed, forKey: "chefName")
        pantry.stir()
        FlavorFeedback.goldenCrust()
    }

    // MARK: – Save Avatar

    func selectAvatar(_ emoji: String) {
        avatarEmoji = emoji
        guard let profile = firstProfile() else { return }
        profile.setValue(emoji, forKey: "avatarEmoji")
        pantry.stir()
        FlavorFeedback.eggCrack()
        showAvatarPicker = false
    }

    // MARK: – Save Accent Flavor

    func selectAccentFlavor(_ flavor: AccentFlavor, coordinator: KitchenCoordinator) {
        accentFlavor = flavor
        coordinator.updateAccentFlavor(flavor)
        FlavorFeedback.spoonTap()
    }

    // MARK: – CSV Export

    func buildCSVExport() {
        let items: [NSManagedObject] = pantry.fetchAll(
            entity: "GroceryItem",
            sortKey: "recipeName",
            ascending: true
        )

        var csv = "Product,Store,Category,Unit,Currency,Price,Date,Memo\n"

        for item in items {
            let itemID = item.value(forKey: "itemID") as? String ?? ""
            let name = item.value(forKey: "recipeName") as? String ?? ""
            let store = item.value(forKey: "marketStall") as? String ?? ""
            let category = item.value(forKey: "category") as? String ?? ""
            let unit = item.value(forKey: "unitLabel") as? String ?? ""
            let currency = item.value(forKey: "currencyCode") as? String ?? ""

            let tags: [NSManagedObject] = pantry.fetchAll(
                entity: "PriceTag",
                sortKey: "recordedAt",
                ascending: true,
                predicate: NSPredicate(format: "groceryItemID == %@", itemID)
            )

            if tags.isEmpty {
                csv += "\"\(name)\",\"\(store)\",\"\(category)\",\"\(unit)\",\"\(currency)\",,, \n"
            } else {
                let dateFormatter = ISO8601DateFormatter()
                for tag in tags {
                    let amount = tag.value(forKey: "amount") as? Double ?? 0
                    let date = tag.value(forKey: "recordedAt") as? Date ?? Date()
                    let tagStore = tag.value(forKey: "marketStall") as? String ?? store
                    let memo = tag.value(forKey: "memo") as? String ?? ""

                    csv += "\"\(name)\",\"\(tagStore)\",\"\(category)\",\"\(unit)\",\"\(currency)\",\(amount),\(dateFormatter.string(from: date)),\"\(memo)\"\n"
                }
            }
        }

        // Write to temp file
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PriceKitchen_Export_\(dateStamp()).csv")

        do {
            try csv.write(to: tempURL, atomically: true, encoding: .utf8)
            exportCSVURL = tempURL
            showExportSheet = true
            FlavorFeedback.clinkGlasses()
        } catch {
            print("📄 CSV export failed: \(error.localizedDescription)")
            FlavorFeedback.burntSouffle()
        }
    }

    private func dateStamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    // MARK: – Reset All Data

    func resetKitchen() {
        // Delete in order: links first, then items that reference others
        let entities = [
            "RecipeIngredientLink",  // recipe ↔ ingredient links
            "RecipePot",             // recipes
            "PriceTag",              // price history
            "GroceryItem",           // ingredients
            "TrophyCase",
            "MarketVisit",
            "ChefProfile"
        ]
        let context = pantry.viewContext

        for entityName in entities {
            let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
            if let objects = try? context.fetch(request) {
                for obj in objects {
                    context.delete(obj)
                }
            }
        }

        ToBuyStore.shared.clearAll()

        pantry.stir()
        pantry.seedKitchenIfNeeded()

        FlavorFeedback.cleaverChop()
        showResetConfirm = false

        // Reload
        openSpiceJars()
    }

    // MARK: – App Version

    var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    // MARK: – Helpers

    private func firstProfile() -> NSManagedObject? {
        let profiles: [NSManagedObject] = pantry.fetchAll(
            entity: "ChefProfile",
            sortKey: "memberSince",
            ascending: true
        )
        return profiles.first
    }
}
