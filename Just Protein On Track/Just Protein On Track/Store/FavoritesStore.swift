// FavoritesStore.swift
// PriceKitchen
//
// Stores favorite recipe IDs. Persisted in UserDefaults.

import Combine
import Foundation

final class FavoritesStore: ObservableObject {

    static let shared = FavoritesStore()

    private let key = "priceKitchen.favoriteRecipeIDs"

    @Published private(set) var recipeIDs: Set<String> = []

    private init() {
        load()
    }

    private func load() {
        if let array = UserDefaults.standard.stringArray(forKey: key) {
            recipeIDs = Set(array)
        }
    }

    private func save() {
        UserDefaults.standard.set(Array(recipeIDs), forKey: key)
    }

    func toggle(recipeID: String) {
        if recipeIDs.contains(recipeID) {
            recipeIDs.remove(recipeID)
        } else {
            recipeIDs.insert(recipeID)
        }
        save()
    }

    func isFavorite(recipeID: String) -> Bool {
        recipeIDs.contains(recipeID)
    }
}
