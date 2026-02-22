// ToBuyStore.swift
// PriceKitchen
//
// Simple store for "to buy" item IDs — ingredients user wants to remember to purchase.
// Persisted in UserDefaults.

import Combine
import Foundation

final class ToBuyStore: ObservableObject {

    static let shared = ToBuyStore()

    private let key = "priceKitchen.toBuyItemIDs"

    @Published private(set) var itemIDs: Set<String> = []

    private init() {
        load()
    }

    private func load() {
        if let array = UserDefaults.standard.stringArray(forKey: key) {
            itemIDs = Set(array)
        }
    }

    private func save() {
        UserDefaults.standard.set(Array(itemIDs), forKey: key)
    }

    func add(itemID: String) {
        itemIDs.insert(itemID)
        save()
    }

    func remove(itemID: String) {
        itemIDs.remove(itemID)
        save()
    }

    func contains(itemID: String) -> Bool {
        itemIDs.contains(itemID)
    }

    func toggle(itemID: String) {
        if itemIDs.contains(itemID) {
            itemIDs.remove(itemID)
        } else {
            itemIDs.insert(itemID)
        }
        save()
    }

    /// Clears all "to buy" items. Called when user resets the kitchen.
    func clearAll() {
        itemIDs = []
        save()
    }
}
