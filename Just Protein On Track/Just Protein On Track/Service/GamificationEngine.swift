// GamificationEngine.swift
// PriceKitchen
//
// Centralized gamification logic — the secret sauce of engagement.
// XP rules, trophy registry, streak bonuses, daily challenges,
// and level-up event broadcasting.

import SwiftUI
import CoreData
import Combine

// MARK: - XP Recipe (defines how much XP each action earns)

enum XPRecipe {
    /// Adding a new grocery item to the basket.
    static let addIngredient: Int        = 15
    /// Logging a price for an existing item.
    static let logPrice: Int             = 10
    /// Bonus for logging prices on consecutive days.
    static let streakDayBonus: Int       = 5
    /// First action of the day bonus.
    static let dailyFirstAction: Int     = 8
    /// Comparing prices across multiple stores.
    static let storeComparison: Int      = 12
    /// Completing a daily challenge.
    static let dailyChallenge: Int       = 25
    /// Viewing inflation analysis (once per day).
    static let ovenVisit: Int            = 3
}

// MARK: - Trophy Blueprint

struct TrophyBlueprint: Identifiable {
    let id: String           // matches badgeName in Core Data
    let nameKey: String      // localization key for display name
    let descKey: String      // localization key for description
    let emoji: String
    let xpReward: Int
    let condition: (PantryStore) -> Bool
}

// MARK: - Trophy Registry

enum TrophyRegistry {

    static let allBlueprints: [TrophyBlueprint] = [
        TrophyBlueprint(
            id: "firstDish",
            nameKey: "trophy.firstDish",
            descKey: "trophy.firstDish.desc",
            emoji: "🍳",
            xpReward: 25,
            condition: { pantry in
                pantry.countDishes(entity: "GroceryItem") >= 1
            }
        ),
        TrophyBlueprint(
            id: "firstTag",
            nameKey: "trophy.firstTag",
            descKey: "trophy.firstTag.desc",
            emoji: "🏷️",
            xpReward: 25,
            condition: { pantry in
                pantry.countDishes(entity: "PriceTag") >= 1
            }
        ),
        TrophyBlueprint(
            id: "fiveItems",
            nameKey: "trophy.fiveItems",
            descKey: "trophy.fiveItems.desc",
            emoji: "🗄️",
            xpReward: 50,
            condition: { pantry in
                pantry.countDishes(entity: "GroceryItem") >= 5
            }
        ),
        TrophyBlueprint(
            id: "twentyTags",
            nameKey: "trophy.twentyTags",
            descKey: "trophy.twentyTags.desc",
            emoji: "🛍️",
            xpReward: 75,
            condition: { pantry in
                pantry.countDishes(entity: "PriceTag") >= 20
            }
        ),
        TrophyBlueprint(
            id: "fiftyTags",
            nameKey: "trophy.fiftyTags",
            descKey: "trophy.fiftyTags.desc",
            emoji: "🍷",
            xpReward: 100,
            condition: { pantry in
                pantry.countDishes(entity: "PriceTag") >= 50
            }
        ),
        TrophyBlueprint(
            id: "hundredTags",
            nameKey: "trophy.hundredTags",
            descKey: "trophy.hundredTags.desc",
            emoji: "👨‍🍳",
            xpReward: 200,
            condition: { pantry in
                pantry.countDishes(entity: "PriceTag") >= 100
            }
        ),
        TrophyBlueprint(
            id: "threeStores",
            nameKey: "trophy.threeStores",
            descKey: "trophy.threeStores.desc",
            emoji: "🏪",
            xpReward: 50,
            condition: { pantry in
                let tags: [NSManagedObject] = pantry.fetchAll(
                    entity: "PriceTag",
                    sortKey: "recordedAt"
                )
                let stores = Set(tags.compactMap { $0.value(forKey: "marketStall") as? String })
                return stores.count >= 3
            }
        ),
        TrophyBlueprint(
            id: "weekStreak",
            nameKey: "trophy.weekStreak",
            descKey: "trophy.weekStreak.desc",
            emoji: "🔥",
            xpReward: 100,
            condition: { pantry in
                GamificationEngine.computeStreak(pantry: pantry) >= 7
            }
        )
    ]
}

// MARK: - Daily Challenge

struct DailyChallenge: Identifiable {
    let id = UUID()
    let emoji: String
    let description: String
    let targetAction: ChallengeAction
    let targetCount: Int
    var currentCount: Int = 0

    var isCompleted: Bool { currentCount >= targetCount }
    var progress: Double { min(Double(currentCount) / Double(targetCount), 1.0) }
}

enum ChallengeAction: String {
    case logPrices      = "logPrices"
    case addItems       = "addItems"
    case visitOven      = "visitOven"
    case compareStores  = "compareStores"
}

// MARK: - Gamification Engine

final class GamificationEngine: ObservableObject {

    // MARK: – Published Events

    @Published var lastXPGained: Int = 0
    @Published var showXPToast: Bool = false
    @Published var lastTrophyUnlocked: TrophyBlueprint? = nil
    @Published var showTrophyToast: Bool = false
    @Published var dailyChallenge: DailyChallenge? = nil

    // MARK: – Dependencies

    private let pantry: PantryStore

    // MARK: – Daily Tracking

    @AppStorage("lastDailyActionDate") private var lastDailyActionDate: String = ""
    @AppStorage("dailyChallengeDate") private var dailyChallengeDate: String = ""
    @AppStorage("dailyChallengeProgress") private var dailyChallengeProgress: Int = 0
    @AppStorage("ovenVisitDate") private var ovenVisitDate: String = ""

    // MARK: – Init

    init(pantry: PantryStore = .shared) {
        self.pantry = pantry
        refreshDailyChallenge()
    }

    // MARK: – Award XP with Toast

    /// Awards XP to the chef profile and shows a brief toast.
    func serveXP(_ amount: Int, to dashboardVM: KitchenDashboardViewModel) {
        var totalAward = amount

        // Daily first-action bonus
        let todayStr = todayStamp()
        if lastDailyActionDate != todayStr {
            totalAward += XPRecipe.dailyFirstAction
            lastDailyActionDate = todayStr
        }

        // Streak bonus
        let streak = GamificationEngine.computeStreak(pantry: pantry)
        if streak >= 2 {
            totalAward += XPRecipe.streakDayBonus * min(streak, 7)
        }

        dashboardVM.awardXP(totalAward)

        lastXPGained = totalAward
        showXPToast = true

        // Auto-dismiss toast
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.showXPToast = false
        }
    }

    // MARK: – Scan All Trophies

    /// Checks every blueprint and grants any newly-earned trophies.
    func scanTrophyCabinet() {
        for blueprint in TrophyRegistry.allBlueprints {
            // Already earned?
            let existing = pantry.countDishes(
                entity: "TrophyCase",
                predicate: NSPredicate(format: "badgeName == %@", blueprint.id)
            )
            guard existing == 0 else { continue }

            // Condition met?
            guard blueprint.condition(pantry) else { continue }

            // Grant trophy
            let context = pantry.viewContext
            let trophy = NSEntityDescription.insertNewObject(forEntityName: "TrophyCase", into: context)
            trophy.setValue(UUID().uuidString, forKey: "trophyID")
            trophy.setValue(blueprint.id, forKey: "badgeName")
            trophy.setValue(blueprint.emoji, forKey: "badgeEmoji")
            trophy.setValue(L10n.string(blueprint.descKey), forKey: "flavorText")
            trophy.setValue(Date(), forKey: "earnedAt")
            trophy.setValue(Int32(blueprint.xpReward), forKey: "xpReward")
            pantry.stir()

            lastTrophyUnlocked = blueprint
            showTrophyToast = true
            FlavorFeedback.champagneBubbles()

            // Auto-dismiss
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                self?.showTrophyToast = false
            }
        }
    }

    // MARK: – Daily Challenge

    func refreshDailyChallenge() {
        let today = todayStamp()

        if dailyChallengeDate != today {
            // New day — pick a new challenge
            dailyChallengeDate = today
            dailyChallengeProgress = 0
            dailyChallenge = pickRandomChallenge()
        } else {
            // Restore in-progress challenge
            var challenge = pickChallengeForCurrentDay()
            challenge.currentCount = dailyChallengeProgress
            dailyChallenge = challenge
        }
    }

    func advanceDailyChallenge(action: ChallengeAction) {
        guard var challenge = dailyChallenge,
              challenge.targetAction == action,
              !challenge.isCompleted else { return }

        challenge.currentCount += 1
        dailyChallengeProgress = challenge.currentCount
        dailyChallenge = challenge

        if challenge.isCompleted {
            FlavorFeedback.goldenCrust()
        }
    }

    private func pickRandomChallenge() -> DailyChallenge {
        let pool = challengePool()
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        let index = dayOfYear % pool.count
        return pool[index]
    }

    private func pickChallengeForCurrentDay() -> DailyChallenge {
        pickRandomChallenge()
    }

    private func challengePool() -> [DailyChallenge] {
        [
            DailyChallenge(
                emoji: "🏷️",
                description: "Log 3 prices today",
                targetAction: .logPrices,
                targetCount: 3
            ),
            DailyChallenge(
                emoji: "🧺",
                description: "Add 2 new ingredients",
                targetAction: .addItems,
                targetCount: 2
            ),
            DailyChallenge(
                emoji: "🔥",
                description: "Check the Inflation Oven",
                targetAction: .visitOven,
                targetCount: 1
            ),
            DailyChallenge(
                emoji: "🏪",
                description: "Log prices from 2 different stores",
                targetAction: .compareStores,
                targetCount: 2
            ),
            DailyChallenge(
                emoji: "📊",
                description: "Log 5 prices today",
                targetAction: .logPrices,
                targetCount: 5
            ),
            DailyChallenge(
                emoji: "🍳",
                description: "Add 1 new ingredient",
                targetAction: .addItems,
                targetCount: 1
            ),
        ]
    }

    // MARK: – Oven Visit Tracking

    func recordOvenVisit(dashboardVM: KitchenDashboardViewModel) {
        let today = todayStamp()
        guard ovenVisitDate != today else { return }

        ovenVisitDate = today
        dashboardVM.awardXP(XPRecipe.ovenVisit)
        advanceDailyChallenge(action: .visitOven)
    }

    // MARK: – Streak Computation

    static func computeStreak(pantry: PantryStore) -> Int {
        let tags: [NSManagedObject] = pantry.fetchAll(
            entity: "PriceTag",
            sortKey: "recordedAt",
            ascending: false
        )

        guard !tags.isEmpty else { return 0 }

        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let tagDates: Set<String> = Set(tags.compactMap { tag in
            guard let date = tag.value(forKey: "recordedAt") as? Date else { return nil }
            return formatter.string(from: date)
        })

        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())

        while true {
            let dateString = formatter.string(from: checkDate)
            if tagDates.contains(dateString) {
                streak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
            } else {
                break
            }
        }

        return streak
    }

    // MARK: – Helpers

    private func todayStamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}

// MARK: - XP Toast Overlay

/// Floating "+15 XP" toast that appears at the top.
/// Usage: `.overlay(XPToastOverlay(engine: engine))`
struct XPToastOverlay: View {

    @ObservedObject var engine: GamificationEngine
    @Environment(\.accentFlavor) private var flavor

    var body: some View {
        VStack {
            if engine.showXPToast {
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 14))
                        .foregroundColor(SpicePalette.burntCrustFallback)

                    Text(String(format: L10n.string("game.xpGained"), engine.lastXPGained))
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundColor(SpicePalette.burntCrustFallback)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(flavor.primaryTint)
                        .shadow(color: flavor.primaryTint.opacity(0.4), radius: 8, y: 4)
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            Spacer()
        }
        .padding(.top, 60)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: engine.showXPToast)
        .allowsHitTesting(false)
    }
}

// MARK: - Trophy Toast Overlay

/// Floating trophy unlock banner.
/// Usage: `.overlay(TrophyToastOverlay(engine: engine))`
struct TrophyToastOverlay: View {

    @ObservedObject var engine: GamificationEngine
    @Environment(\.accentFlavor) private var flavor

    var body: some View {
        VStack {
            if engine.showTrophyToast, let blueprint = engine.lastTrophyUnlocked {
                HStack(spacing: 12) {
                    Text(blueprint.emoji)
                        .font(.system(size: 28))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.string("game.newTrophy"))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(flavor.primaryTint)

                        Text(L10n.string(blueprint.nameKey))
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundColor(SpicePalette.vanillaCreamFallback)
                    }

                    Spacer()

                    Text("+\(blueprint.xpReward) XP")
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundColor(flavor.primaryTint)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(SpicePalette.smokedPaprikaFallback)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(flavor.primaryTint.opacity(0.4), lineWidth: 1.5)
                        )
                        .shadow(color: Color.black.opacity(0.3), radius: 12, y: 6)
                )
                .padding(.horizontal, 16)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            Spacer()
        }
        .padding(.top, 50)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: engine.showTrophyToast)
        .allowsHitTesting(false)
    }
}

// MARK: - Daily Challenge Card

/// Compact card showing today's challenge with a progress ring.
struct DailyChallengeCard: View {

    let challenge: DailyChallenge
    @Environment(\.accentFlavor) private var flavor

    var body: some View {
        HStack(spacing: 14) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(SpicePalette.peppercornFallback.opacity(0.3), lineWidth: 4)
                    .frame(width: 44, height: 44)

                Circle()
                    .trim(from: 0, to: challenge.progress)
                    .stroke(
                        challenge.isCompleted ? SpicePalette.basilLeafFallback : flavor.primaryTint,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.5), value: challenge.progress)

                Text(challenge.emoji)
                    .font(.system(size: 18))
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("Daily Challenge")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(flavor.primaryTint)

                    if challenge.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(SpicePalette.basilLeafFallback)
                    }
                }

                Text(challenge.description)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(SpicePalette.vanillaCreamFallback)

                Text("\(challenge.currentCount)/\(challenge.targetCount)")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(SpicePalette.flourDustFallback)
            }

            Spacer()

            if !challenge.isCompleted {
                Text("+\(XPRecipe.dailyChallenge) XP")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(flavor.primaryTint.opacity(0.6))
            } else {
                Text("✅")
                    .font(.system(size: 22))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(SpicePalette.smokedPaprikaFallback)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            challenge.isCompleted
                                ? SpicePalette.basilLeafFallback.opacity(0.3)
                                : flavor.primaryTint.opacity(0.15),
                            lineWidth: 1
                        )
                )
        )
    }
}
