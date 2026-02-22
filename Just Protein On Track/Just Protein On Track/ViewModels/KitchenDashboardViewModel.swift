// KitchenDashboardViewModel.swift
// PriceKitchen
//
// ViewModel for the Kitchen (Dashboard) tab.
// Reads ChefProfile, GroceryItems, PriceTags to build the daily flavor report.

import SwiftUI
import CoreData
import Combine

// MARK: - Recent Price Move (UI model)

struct RecentPriceMove: Identifiable {
    let id: String
    let recipeName: String
    let emoji: String
    let marketStall: String
    let previousAmount: Double
    let currentAmount: Double
    let percentChange: Double
    let recordedAt: Date
    let currencyCode: String

    var isRising: Bool { percentChange > 0 }
    var isStable: Bool { abs(percentChange) < 0.5 }

    var formattedChange: String {
        let sign = percentChange >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", percentChange))%"
    }

    var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.string(from: NSNumber(value: currentAmount)) ?? "\(currentAmount)"
    }
}

// MARK: - Chef Tip

struct ChefDailyTip: Identifiable {
    let id = UUID()
    let emoji: String
    let titleKey: String
    let bodyKey: String
}

// MARK: - Kitchen Dashboard ViewModel

final class KitchenDashboardViewModel: ObservableObject {

    // MARK: – Published State

    @Published var chefName: String = "Chef"
    @Published var avatarEmoji: String = "👨‍🍳"
    @Published var totalXP: Int = 0
    @Published var currentLevel: Int = 1
    @Published var levelProgress: Double = 0.0
    @Published var xpToNext: Int = 100
    @Published var rankTitle: String = "Apprentice"
    @Published var dishesTracked: Int = 0
    @Published var pricesLogged: Int = 0
    @Published var dayStreak: Int = 0
    @Published var recentMoves: [RecentPriceMove] = []
    @Published var dailyTip: ChefDailyTip = ChefDailyTip(
        emoji: "💡",
        titleKey: "kitchen.tip.title",
        bodyKey: "kitchen.tip.body"
    )
    @Published var showLevelUpCelebration = false
    @Published var celebratedLevel: Int = 0
    @Published var recipeCount: Int = 0

    // MARK: – Dependencies

    private let pantry: PantryStore
    private var previousLevel: Int = 1

    // MARK: – Init

    init(pantry: PantryStore = .shared) {
        self.pantry = pantry
    }

    // MARK: – Data Loading

    func warmUpKitchen() {
        loadChefProfile()
        loadRecentMoves()
        computeDayStreak()
        rotateDailyTip()
        loadRecipeCount()
    }

    private func loadRecipeCount() {
        let pots: [RecipePot] = pantry.fetchAll(
            entity: "RecipePot",
            sortKey: "dateCreated",
            ascending: true
        )
        recipeCount = pots.count
    }

    // MARK: – Chef Profile

    private func loadChefProfile() {
        let profiles: [ChefProfile] = pantry.fetchAll(
            entity: "ChefProfile",
            sortKey: "memberSince",
            ascending: true
        )
        guard let profile = profiles.first else { return }

        chefName = profile.chefName
        avatarEmoji = profile.avatarEmoji
        totalXP = Int(profile.totalXP)
        dishesTracked = Int(profile.dishesTracked)
        pricesLogged = Int(profile.pricesLogged)

        previousLevel = currentLevel
        currentLevel = KitchenCoordinator.levelForXP(totalXP)
        levelProgress = KitchenCoordinator.levelProgress(currentXP: totalXP)
        xpToNext = KitchenCoordinator.xpToNextLevel(currentXP: totalXP)
        rankTitle = KitchenCoordinator.chefRankTitle(level: currentLevel)

        // Check for level-up celebration
        if currentLevel > previousLevel && previousLevel > 0 {
            celebratedLevel = currentLevel
            showLevelUpCelebration = true
        }
    }

    // MARK: – Recent Price Moves

    private func loadRecentMoves() {
        // Fetch latest 20 price tags
        let tags: [PriceTag] = pantry.fetchAll(
            entity: "PriceTag",
            sortKey: "recordedAt",
            ascending: false
        )

        let limitedTags = Array(tags.prefix(20))

        // Group tags by groceryItemID and find ones with at least 2 entries
        var movesList: [RecentPriceMove] = []

        // Collect unique item IDs from recent tags
        let seenItemIDs = Set(limitedTags.map { $0.groceryItemID })

        for itemID in seenItemIDs {
            guard movesList.count < 8 else { break }

            // Fetch the item
            guard let item: GroceryItem = pantry.fetchOne(
                entity: "GroceryItem",
                key: "itemID",
                value: itemID
            ) else { continue }

            // Fetch all tags for this item sorted by date
            let itemTags: [PriceTag] = pantry.fetchAll(
                entity: "PriceTag",
                sortKey: "recordedAt",
                ascending: false,
                predicate: NSPredicate(format: "groceryItemID == %@", itemID)
            )

            guard itemTags.count >= 2,
                  let latest = itemTags.first,
                  let previous = itemTags.dropFirst().first else { continue }

            let currentAmount = latest.amount
            let previousAmount = previous.amount

            guard previousAmount > 0 else { continue }

            let percentChange = ((currentAmount - previousAmount) / previousAmount) * 100

            let move = RecentPriceMove(
                id: latest.tagID,
                recipeName: item.recipeName,
                emoji: item.emoji,
                marketStall: latest.marketStall,
                previousAmount: previousAmount,
                currentAmount: currentAmount,
                percentChange: percentChange,
                recordedAt: latest.recordedAt,
                currencyCode: item.currencyCode
            )
            movesList.append(move)
        }

        // Sort by absolute change descending (most dramatic first)
        recentMoves = movesList.sorted { abs($0.percentChange) > abs($1.percentChange) }
    }

    // MARK: – Day Streak

    private func computeDayStreak() {
        let tags: [PriceTag] = pantry.fetchAll(
            entity: "PriceTag",
            sortKey: "recordedAt",
            ascending: false
        )

        guard !tags.isEmpty else {
            dayStreak = 0
            return
        }

        let calendar = Calendar.current
        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())

        // Walk backwards day by day
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let tagDates: Set<String> = Set(tags.map { formatter.string(from: $0.recordedAt) })

        while true {
            let dateString = formatter.string(from: checkDate)
            if tagDates.contains(dateString) {
                streak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
            } else {
                break
            }
        }

        dayStreak = streak
    }

    // MARK: – Daily Tip Rotation

    private static let tipPool: [ChefDailyTip] = [
        ChefDailyTip(emoji: "📸", titleKey: "kitchen.tip.title", bodyKey: "kitchen.tip.body"),
        ChefDailyTip(emoji: "🏪", titleKey: "kitchen.tip.title",
                     bodyKey: "Compare the same product across different stores for best savings."),
        ChefDailyTip(emoji: "📅", titleKey: "kitchen.tip.title",
                     bodyKey: "Log prices on the same weekday to spot seasonal patterns."),
        ChefDailyTip(emoji: "🎯", titleKey: "kitchen.tip.title",
                     bodyKey: "Focus on 5-10 staples you buy every week for meaningful data."),
        ChefDailyTip(emoji: "🏆", titleKey: "kitchen.tip.title",
                     bodyKey: "Check the Trophy Case in Settings to see your next achievement."),
    ]

    private func rotateDailyTip() {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        let index = dayOfYear % Self.tipPool.count
        dailyTip = Self.tipPool[index]
    }

    // MARK: – XP Granting

    /// Awards XP and updates profile. Returns true if level-up occurred.
    @discardableResult
    func awardXP(_ amount: Int) -> Bool {
        let profiles: [ChefProfile] = pantry.fetchAll(
            entity: "ChefProfile",
            sortKey: "memberSince",
            ascending: true
        )
        guard let profile = profiles.first else { return false }

        let oldXP = Int(profile.totalXP)
        let oldLevel = KitchenCoordinator.levelForXP(oldXP)
        let newXP = oldXP + amount
        let newLevel = KitchenCoordinator.levelForXP(newXP)

        profile.totalXP = Int32(newXP)
        profile.currentLevel = Int32(newLevel)
        pantry.stir()

        // Update published state
        totalXP = newXP
        currentLevel = newLevel
        levelProgress = KitchenCoordinator.levelProgress(currentXP: newXP)
        xpToNext = KitchenCoordinator.xpToNextLevel(currentXP: newXP)
        rankTitle = KitchenCoordinator.chefRankTitle(level: newLevel)

        let didLevelUp = newLevel > oldLevel
        if didLevelUp {
            celebratedLevel = newLevel
            showLevelUpCelebration = true
            FlavorFeedback.champagneBubbles()
        }

        return didLevelUp
    }

    // MARK: – Increment Counters

    func incrementDishesTracked() {
        let profiles: [ChefProfile] = pantry.fetchAll(
            entity: "ChefProfile",
            sortKey: "memberSince",
            ascending: true
        )
        guard let profile = profiles.first else { return }
        profile.dishesTracked += 1
        pantry.stir()
        dishesTracked = Int(profile.dishesTracked)
    }

    func incrementPricesLogged() {
        let profiles: [ChefProfile] = pantry.fetchAll(
            entity: "ChefProfile",
            sortKey: "memberSince",
            ascending: true
        )
        guard let profile = profiles.first else { return }
        profile.pricesLogged += 1
        pantry.stir()
        pricesLogged = Int(profile.pricesLogged)
    }

    // MARK: – Refresh

    func refreshAfterChange() {
        warmUpKitchen()
    }
}
