// InflationOvenViewModel.swift
// PriceKitchen
//
// ViewModel for the Inflation Oven tab.
// Computes personal inflation, price timelines, hottest/coolest movers,
// store-vs-store comparison, and per-item insights.

import SwiftUI
import CoreData
import Combine
// MARK: - Time Seasoning (period filter)

enum TimeSeasoning: String, CaseIterable, Identifiable {
    case week    = "week"
    case month   = "month"
    case quarter = "quarter"
    case year    = "year"

    var id: String { rawValue }

    var labelKey: String {
        switch self {
        case .week:    return "oven.period.week"
        case .month:   return "oven.period.month"
        case .quarter: return "oven.period.quarter"
        case .year:    return "oven.period.year"
        }
    }

    /// Start date for the period, counting backwards from today.
    var startDate: Date {
        let cal = Calendar.current
        let now = Date()
        switch self {
        case .week:    return cal.date(byAdding: .day,   value: -7,   to: now)!
        case .month:   return cal.date(byAdding: .month, value: -1,   to: now)!
        case .quarter: return cal.date(byAdding: .month, value: -3,   to: now)!
        case .year:    return cal.date(byAdding: .year,  value: -1,   to: now)!
        }
    }
}

// MARK: - Price Crumb (single data point for chart)

struct PriceCrumb: Identifiable {
    let id = UUID()
    let date: Date
    let amount: Double

    var shortDate: String {
        let f = DateFormatter()
        f.dateFormat = "dd MMM"
        return f.string(from: date)
    }
}

// MARK: - Inflation Mover (item with % change)

struct InflationMover: Identifiable {
    let id: String
    let recipeName: String
    let emoji: String
    let firstPrice: Double
    let latestPrice: Double
    let percentChange: Double
    let currencyCode: String

    var formattedChange: String {
        let sign = percentChange >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", percentChange))%"
    }

    var formattedLatest: String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = currencyCode
        return f.string(from: NSNumber(value: latestPrice)) ?? "\(latestPrice)"
    }
}

// MARK: - Store Duel (same item, two stores)

struct StoreDuel: Identifiable {
    let id = UUID()
    let recipeName: String
    let emoji: String
    let storeA: String
    let priceA: Double
    let storeB: String
    let priceB: Double
    let currencyCode: String
    let savings: Double          // absolute difference
    let savingsPercent: Double   // percentage cheaper

    var cheaperStore: String {
        priceA <= priceB ? storeA : storeB
    }

    var formattedSavings: String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = currencyCode
        return f.string(from: NSNumber(value: savings)) ?? "\(savings)"
    }
}

// MARK: - Item Insight

struct OvenInsight: Identifiable {
    let id = UUID()
    let text: String
    let emoji: String
    let tintColor: Color
}

// MARK: - Inflation Oven ViewModel

final class InflationOvenViewModel: ObservableObject {

    // MARK: – Published State

    @Published var selectedPeriod: TimeSeasoning = .month
    @Published var personalInflation: Double? = nil       // overall % change
    @Published var hottestMovers: [InflationMover] = []
    @Published var coolestMovers: [InflationMover] = []
    @Published var storeDuels: [StoreDuel] = []
    @Published var insights: [OvenInsight] = []

    // Chart for selected item
    @Published var chartableItems: [InflationMover] = []
    @Published var selectedChartItemID: String? = nil
    @Published var chartCrumbs: [PriceCrumb] = []

    // MARK: – Dependencies

    private let pantry: PantryStore

    // MARK: – Init

    init(pantry: PantryStore = .shared) {
        self.pantry = pantry
    }

    // MARK: – Main Refresh

    func heatUpOven() {
        computeAllMovers()
        computePersonalInflation()
        buildStoreDuels()
        buildInsights()
        buildChartableItems()

        if let firstID = chartableItems.first?.id {
            selectChartItem(firstID)
        }
    }

    // MARK: – Movers Computation

    private func computeAllMovers() {
        let items: [NSManagedObject] = pantry.fetchAll(
            entity: "GroceryItem",
            sortKey: "recipeName",
            ascending: true,
            predicate: NSPredicate(format: "isArchived == NO")
        )

        var allMovers: [InflationMover] = []

        for item in items {
            guard let itemID = item.value(forKey: "itemID") as? String else { continue }

            let tags: [NSManagedObject] = pantry.fetchAll(
                entity: "PriceTag",
                sortKey: "recordedAt",
                ascending: true,
                predicate: NSPredicate(format: "groceryItemID == %@", itemID)
            )

            // Filter tags within the selected period
            let periodTags = tags.filter { tag in
                guard let date = tag.value(forKey: "recordedAt") as? Date else { return false }
                return date >= selectedPeriod.startDate
            }

            // Need at least the very first tag ever + one in period
            guard let firstEver = tags.first,
                  let latestInPeriod = periodTags.last else { continue }

            let firstPrice = firstEver.value(forKey: "amount") as? Double ?? 0
            let latestPrice = latestInPeriod.value(forKey: "amount") as? Double ?? 0
            guard firstPrice > 0 else { continue }

            let pctChange = ((latestPrice - firstPrice) / firstPrice) * 100

            let mover = InflationMover(
                id: itemID,
                recipeName: item.value(forKey: "recipeName") as? String ?? "",
                emoji: item.value(forKey: "emoji") as? String ?? "🛒",
                firstPrice: firstPrice,
                latestPrice: latestPrice,
                percentChange: pctChange,
                currencyCode: item.value(forKey: "currencyCode") as? String ?? "EUR"
            )
            allMovers.append(mover)
        }

        // Sort: hottest = highest positive change
        hottestMovers = allMovers
            .filter { $0.percentChange > 0.5 }
            .sorted { $0.percentChange > $1.percentChange }
            .prefix(5)
            .map { $0 }

        // Coolest = biggest negative change
        coolestMovers = allMovers
            .filter { $0.percentChange < -0.5 }
            .sorted { $0.percentChange < $1.percentChange }
            .prefix(5)
            .map { $0 }
    }

    // MARK: – Personal Inflation

    private func computePersonalInflation() {
        let items: [NSManagedObject] = pantry.fetchAll(
            entity: "GroceryItem",
            sortKey: "recipeName",
            ascending: true,
            predicate: NSPredicate(format: "isArchived == NO")
        )

        var totalFirstBasket: Double = 0
        var totalLatestBasket: Double = 0
        var validCount = 0

        for item in items {
            guard let itemID = item.value(forKey: "itemID") as? String else { continue }

            let tags: [NSManagedObject] = pantry.fetchAll(
                entity: "PriceTag",
                sortKey: "recordedAt",
                ascending: true,
                predicate: NSPredicate(format: "groceryItemID == %@", itemID)
            )

            guard tags.count >= 2,
                  let first = tags.first,
                  let last = tags.last else { continue }

            let fp = first.value(forKey: "amount") as? Double ?? 0
            let lp = last.value(forKey: "amount") as? Double ?? 0
            guard fp > 0 else { continue }

            totalFirstBasket += fp
            totalLatestBasket += lp
            validCount += 1
        }

        if validCount >= 1 && totalFirstBasket > 0 {
            personalInflation = ((totalLatestBasket - totalFirstBasket) / totalFirstBasket) * 100
        } else {
            personalInflation = nil
        }
    }

    // MARK: – Store Duels

    private func buildStoreDuels() {
        let items: [NSManagedObject] = pantry.fetchAll(
            entity: "GroceryItem",
            sortKey: "recipeName",
            ascending: true,
            predicate: NSPredicate(format: "isArchived == NO")
        )

        var duels: [StoreDuel] = []

        for item in items {
            guard let itemID = item.value(forKey: "itemID") as? String else { continue }

            let tags: [NSManagedObject] = pantry.fetchAll(
                entity: "PriceTag",
                sortKey: "recordedAt",
                ascending: false,
                predicate: NSPredicate(format: "groceryItemID == %@", itemID)
            )

            // Group by store, take latest price per store
            var latestByStore: [String: Double] = [:]
            for tag in tags {
                let store = tag.value(forKey: "marketStall") as? String ?? ""
                guard !store.isEmpty else { continue }
                if latestByStore[store] == nil {
                    latestByStore[store] = tag.value(forKey: "amount") as? Double ?? 0
                }
            }

            let stores = Array(latestByStore.keys).sorted()
            guard stores.count >= 2 else { continue }

            // Build duels for first two distinct stores
            let storeA = stores[0]
            let storeB = stores[1]
            let priceA = latestByStore[storeA] ?? 0
            let priceB = latestByStore[storeB] ?? 0
            let maxPrice = max(priceA, priceB)
            guard maxPrice > 0 else { continue }

            let savings = abs(priceA - priceB)
            let savingsPct = (savings / maxPrice) * 100

            let duel = StoreDuel(
                recipeName: item.value(forKey: "recipeName") as? String ?? "",
                emoji: item.value(forKey: "emoji") as? String ?? "🛒",
                storeA: storeA,
                priceA: priceA,
                storeB: storeB,
                priceB: priceB,
                currencyCode: item.value(forKey: "currencyCode") as? String ?? "EUR",
                savings: savings,
                savingsPercent: savingsPct
            )
            duels.append(duel)
        }

        storeDuels = duels.sorted { $0.savingsPercent > $1.savingsPercent }.prefix(6).map { $0 }
    }

    // MARK: – Insights

    private func buildInsights() {
        var list: [OvenInsight] = []

        // Personal inflation insight
        if let pi = personalInflation {
            if pi > 1 {
                list.append(OvenInsight(
                    text: String(format: "Your personal basket is up %.1f%% overall.", pi),
                    emoji: "🌡️",
                    tintColor: SpicePalette.chiliFlakeFallback
                ))
            } else if pi < -1 {
                list.append(OvenInsight(
                    text: String(format: "Your personal basket is down %.1f%% — great deals!", abs(pi)),
                    emoji: "❄️",
                    tintColor: SpicePalette.basilLeafFallback
                ))
            } else {
                list.append(OvenInsight(
                    text: "Your basket is holding steady. Prices barely changed.",
                    emoji: "⚖️",
                    tintColor: SpicePalette.peppercornFallback
                ))
            }
        }

        // Hottest item insight
        if let top = hottestMovers.first {
            list.append(OvenInsight(
                text: String(
                    format: L10n.string("oven.insight.rising"),
                    top.recipeName, top.percentChange
                ),
                emoji: "🔥",
                tintColor: SpicePalette.chiliFlakeFallback
            ))
        }

        // Coolest item insight
        if let cool = coolestMovers.first {
            list.append(OvenInsight(
                text: String(
                    format: L10n.string("oven.insight.falling"),
                    cool.recipeName, abs(cool.percentChange)
                ),
                emoji: "🧊",
                tintColor: SpicePalette.basilLeafFallback
            ))
        }

        // Store duel insight
        if let bestDuel = storeDuels.first {
            list.append(OvenInsight(
                text: "\(bestDuel.recipeName) is \(bestDuel.formattedSavings) cheaper at \(bestDuel.cheaperStore).",
                emoji: "🏪",
                tintColor: SpicePalette.saffronGoldFallback
            ))
        }

        insights = list
    }

    // MARK: – Chart Data

    private func buildChartableItems() {
        let items: [NSManagedObject] = pantry.fetchAll(
            entity: "GroceryItem",
            sortKey: "recipeName",
            ascending: true,
            predicate: NSPredicate(format: "isArchived == NO")
        )

        chartableItems = items.compactMap { item in
            guard let itemID = item.value(forKey: "itemID") as? String else { return nil }

            let count = pantry.countDishes(
                entity: "PriceTag",
                predicate: NSPredicate(format: "groceryItemID == %@", itemID)
            )
            guard count >= 2 else { return nil }

            let tags: [NSManagedObject] = pantry.fetchAll(
                entity: "PriceTag",
                sortKey: "recordedAt",
                ascending: true,
                predicate: NSPredicate(format: "groceryItemID == %@", itemID)
            )

            let first = tags.first?.value(forKey: "amount") as? Double ?? 0
            let last = tags.last?.value(forKey: "amount") as? Double ?? 0
            guard first > 0 else { return nil }
            let pct = ((last - first) / first) * 100

            return InflationMover(
                id: itemID,
                recipeName: item.value(forKey: "recipeName") as? String ?? "",
                emoji: item.value(forKey: "emoji") as? String ?? "🛒",
                firstPrice: first,
                latestPrice: last,
                percentChange: pct,
                currencyCode: item.value(forKey: "currencyCode") as? String ?? "EUR"
            )
        }
    }

    func selectChartItem(_ itemID: String) {
        selectedChartItemID = itemID

        let tags: [NSManagedObject] = pantry.fetchAll(
            entity: "PriceTag",
            sortKey: "recordedAt",
            ascending: true,
            predicate: NSPredicate(format: "groceryItemID == %@", itemID)
        )

        chartCrumbs = tags.compactMap { tag in
            guard let date = tag.value(forKey: "recordedAt") as? Date,
                  let amount = tag.value(forKey: "amount") as? Double else { return nil }
            return PriceCrumb(date: date, amount: amount)
        }
    }

    // MARK: – Period Change Handler

    func onPeriodChanged() {
        FlavorFeedback.pepperGrind()
        heatUpOven()
    }
}
