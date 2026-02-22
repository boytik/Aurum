// L10n.swift
// PriceKitchen
//
// Loads strings from System/Localize/ files:
// - LocalizableEn.strings (English)
// - LocalizableDe.strings (Deutsch)
// - LocalizableFr.strings (Français)

import Foundation

enum L10n {

    /// Table name for current preferred language (matches System/Localize/ file names).
    private static var tableForLocale: String {
        let preferred = Locale.preferredLanguages.first ?? "en"
        if preferred.hasPrefix("de") { return "LocalizableDe" }
        if preferred.hasPrefix("fr") { return "LocalizableFr" }
        return "LocalizableEn"
    }

    /// Returns localized string from System/Localize/ files, or fallback if not found.
    static func string(_ key: String, fallback: String) -> String {
        let result = Bundle.main.localizedString(forKey: key, value: fallback, table: tableForLocale)
        return result.isEmpty ? fallback : result
    }

    /// Returns localized string with format arguments.
    static func string(_ key: String, fallback: String, _ args: CVarArg...) -> String {
        let format = string(key, fallback: fallback)
        guard !args.isEmpty else { return format }
        return String(format: format, arguments: args)
    }

    /// Returns localized string using built-in fallback dictionary.
    static func string(_ key: String) -> String {
        let fallback = fallbacks[key] ?? key
        return string(key, fallback: fallback)
    }

    private static let fallbacks: [String: String] = [
        "common.save": "Save", "common.cancel": "Cancel", "common.delete": "Delete",
        "common.done": "Done", "common.edit": "Edit", "common.add": "Add", "common.close": "Close",
        "common.next": "Next", "common.back": "Back", "common.skip": "Skip", "common.retry": "Retry",
        "common.search": "Search", "common.share": "Share", "common.confirm": "Confirm",
        "common.error": "Error", "common.yes": "Yes", "common.no": "No", "common.xp": "XP",
        "common.level": "Level %d", "common.noData": "Nothing here yet",
        "basket.title": "Market Basket", "basket.addItem": "New Ingredient", "basket.addPrice": "Log Price",
        "basket.itemName": "Product Name", "basket.storeName": "Store Name", "basket.price": "Price",
        "basket.unit": "Unit (e.g. 1 kg)", "basket.category": "Category", "basket.emoji": "Emoji",
        "basket.currency": "Currency", "basket.notes": "Notes (optional)", "basket.empty": "Your basket is empty.",
        "basket.search.placeholder": "Search ingredients…", "basket.delete.confirm": "Remove this ingredient?",
        "basket.validation.pricePositive": "Price must be greater than zero.",
        "basket.validation.nameRequired": "Please enter a product name.",
        "basket.validation.nameTooLong": "Product name is too long (max 100 characters).",
        "basket.validation.duplicate": "This product already exists in this store.",
        "basket.validation.priceInvalid": "Please enter a valid price.",
        "basket.validation.priceTooHigh": "Price value is too high.",
        "basket.sort.name": "Name", "basket.sort.recent": "Recent", "basket.sort.change": "Price Change",
        "basket.priceCount": "%d entries",
        "lab.title": "Flavor Lab", "lab.empty": "Create your first recipe.", "lab.newRecipe": "New Recipe",
        "lab.addIngredient": "Add Ingredient", "lab.selectProduct": "Select a product", "lab.quantity": "Quantity",
        "lab.dishName": "Dish Name", "lab.dishEmoji": "Dish Emoji", "lab.servings": "Servings", "lab.ingredients": "ingredients",
        "lab.delete.confirm": "Delete this recipe?",
        "lab.validation.nameRequired": "Please enter a dish name.",
        "lab.validation.nameTooLong": "Dish name is too long (max 80 characters).",
        "lab.validation.selectProduct": "Please select a product.",
        "lab.addToBasket": "Add to basket", "lab.addAllToBasket": "Add all to basket",
        "lab.needToBuy": "Need to buy", "lab.atHome": "At home", "lab.addNewIngredient": "Add new ingredient", "lab.fromBasket": "From basket",
        "lab.favorite": "Favorite", "lab.search.placeholder": "Search recipes…",
        "lab.sort.recent": "Recent", "lab.sort.name": "Name", "lab.sort.cost": "Cost", "lab.sort.ingredients": "Ingredients",
        "spice.title": "Spice Rack", "spice.profile": "Chef Profile",
        "spice.name": "Chef Name", "spice.avatar": "Avatar", "spice.avatar.pick": "Pick Your Chef Emoji",
        "spice.accent": "Accent Flavor", "spice.stats": "Kitchen Stats",
        "spice.stats.items": "Total Ingredients", "spice.stats.prices": "Total Price Entries",
        "spice.stats.trophies": "Trophies Earned", "spice.stats.memberSince": "Cooking Since",
        "spice.export": "Share My Data", "spice.export.desc": "Export your price history as CSV",
        "spice.trophies": "Trophy Case", "spice.trophies.empty": "No trophies yet. Keep tracking!",
        "spice.trophies.unlocked": "%d unlocked",
        "spice.danger": "Danger Zone", "spice.resetAll": "Reset Kitchen",
        "spice.resetAll.confirm": "This will erase all data. Are you sure?",
        "spice.version": "Version %@",
        "trophy.firstDish": "First Dish", "trophy.firstDish.desc": "Added your first product.",
        "trophy.firstTag": "Price Tagger", "trophy.firstTag.desc": "Logged your first price.",
        "trophy.fiveItems": "Pantry Builder", "trophy.fiveItems.desc": "Tracking 5 different products.",
        "trophy.twentyTags": "Market Regular", "trophy.twentyTags.desc": "Logged 20 prices.",
        "trophy.fiftyTags": "Data Sommelier", "trophy.fiftyTags.desc": "Logged 50 prices.",
        "trophy.hundredTags": "Grand Chef", "trophy.hundredTags.desc": "Logged 100 prices.",
        "trophy.threeStores": "Store Hopper", "trophy.threeStores.desc": "Compared prices across 3 stores.",
        "trophy.weekStreak": "Weekly Simmer", "trophy.weekStreak.desc": "Logged prices 7 days in a row.",
        "game.levelUp": "Level Up! 🎉", "game.levelUp.body": "You reached Level %d!",
        "game.xpGained": "+%d XP", "game.newTrophy": "Trophy Unlocked!",
        "oven.title": "Inflation Oven", "oven.recent.title": "Latest Price Moves",
        "oven.period.week": "Week", "oven.period.month": "Month", "oven.period.quarter": "Quarter", "oven.period.year": "Year",
        "oven.hottest": "Hottest Risers 🔥", "oven.coolest": "Coolest Drops ❄️",
        "oven.personalRate": "Your Personal Inflation", "oven.personalRate.desc": "Based on items you actually buy",
        "oven.chart.title": "Price Over Time", "oven.noChart": "Add at least 2 prices for an item to see a chart.",
        "oven.compare": "Compare Stores", "oven.compare.desc": "Same product, different shops",
        "oven.insight.rising": "%@ rose %.1f%% since your first entry.",
        "oven.insight.falling": "%@ dropped %.1f%% — nice find!",
        "category.dairy": "Dairy", "category.bread": "Bread & Bakery", "category.meat": "Meat & Fish",
        "category.produce": "Fruits & Veggies", "category.drinks": "Drinks", "category.snacks": "Snacks",
        "category.household": "Household", "category.other": "Other",
        "kitchen.tip.title": "Chef's Tip", "kitchen.tip.body": "Track the same item weekly for the best inflation insights.",
        "kitchen.randomRecipe": "Random recipe for today",
        "splash.line1": "Warming up the stove…", "splash.line2": "Seasoning the data…", "splash.line3": "Preparing your kitchen…",
        "onboard.getStarted": "Get Started",
        "onboard.page1.title": "Your Personal Price Tracker", "onboard.page1.body": "Stop guessing how much things cost. Log prices once and see how your grocery spending changes over time.",
        "onboard.page2.title": "Add Products in Seconds", "onboard.page2.body": "Create your list of regular purchases. Each time you shop, tap and record the price — no spreadsheets needed.",
        "onboard.page3.title": "Recipes & Real Costs", "onboard.page3.body": "Build recipes from your products and see exactly what a dish costs. Compare stores to find the best deals.",
        "onboard.page4.title": "Earn Rewards as You Track", "onboard.page4.body": "Unlock trophies and level up for every price you log. Turn boring receipts into a satisfying habit.",
    ]
}
