// FlavorLabView.swift
// PriceKitchen
//
// The "Lab" tab — Recipe Builder (Recipe Cauldron).
// Create recipes from Market Basket ingredients, see dish cost.

import SwiftUI

// MARK: - Flavor Lab View

struct FlavorLabView: View {

    @EnvironmentObject private var coordinator: KitchenCoordinator
    @Environment(\.accentFlavor) private var flavor
    @StateObject private var lab = FlavorLabViewModel()

    @State private var expandedRecipeID: String?
    @State private var showDeleteConfirm = false
    @State private var deleteTargetID: String = ""
    @StateObject private var favorites = FavoritesStore.shared

    var body: some View {
        NavigationView {
            ZStack {
                SpicePalette.burntCrustFallback
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 16) {
                        headerBar
                        if !lab.recipes.isEmpty {
                            searchBar
                            sortStrip
                        }
                        recipeList
                        Spacer(minLength: 30)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                lab.brewRecipes()
                if let recipeID = coordinator.labRecipeToExpand {
                    expandedRecipeID = recipeID
                    coordinator.labRecipeToExpand = nil
                }
            }
            .onChange(of: coordinator.activeTab) { _ in
                if coordinator.activeTab == .lab, let recipeID = coordinator.labRecipeToExpand {
                    lab.brewRecipes()
                    expandedRecipeID = recipeID
                    coordinator.labRecipeToExpand = nil
                }
            }
            .sheet(isPresented: $lab.showNewRecipeSheet) {
                NewRecipeSheet(lab: lab, flavor: flavor)
            }
            .sheet(isPresented: $lab.showAddIngredientSheet) {
                AddRecipeIngredientSheet(lab: lab, flavor: flavor)
            }
            .alert(L10n.string("common.error"), isPresented: Binding(
                get: { lab.validationError != nil },
                set: { if !$0 { lab.validationError = nil } }
            )) {
                Button(L10n.string("common.done")) {
                    lab.validationError = nil
                }
            } message: {
                if let msg = lab.validationError {
                    Text(msg)
                }
            }
            .alert(L10n.string("common.delete"), isPresented: $showDeleteConfirm) {
                Button(L10n.string("common.cancel"), role: .cancel) { }
                Button(L10n.string("common.delete"), role: .destructive) {
                    lab.deleteRecipe(potID: deleteTargetID)
                    deleteTargetID = ""
                }
            } message: {
                Text(L10n.string("lab.delete.confirm"))
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: – Header

    private var headerBar: some View {
        HStack {
            Text(L10n.string("lab.title"))
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(SpicePalette.vanillaCreamFallback)

            Spacer()

            Button {
                lab.showNewRecipeSheet = true
                FlavorFeedback.ovenDoorShut()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(flavor.primaryTint)
                    .symbolRenderingMode(.hierarchical)
            }
            .flavorTap(.ovenDoorShut)
        }
        .padding(.top, 12)
    }

    // MARK: – Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(SpicePalette.peppercornFallback)
                .font(.system(size: 15))

            TextField(L10n.string("lab.search.placeholder"), text: $lab.searchText)
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(SpicePalette.vanillaCreamFallback)
                .autocorrectionDisabled()

            if !lab.searchText.isEmpty {
                Button {
                    lab.searchText = ""
                    FlavorFeedback.spoonTap()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(SpicePalette.peppercornFallback)
                        .font(.system(size: 15))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(SpicePalette.smokedPaprikaFallback)
        )
        .padding(.vertical, 4)
    }

    // MARK: – Sort Strip

    private var sortStrip: some View {
        HStack(spacing: 6) {
            Text("⇅")
                .font(.system(size: 13))
                .foregroundColor(SpicePalette.flourDustFallback)

            ForEach(FlavorLabViewModel.LabSortOption.allCases, id: \.self) { opt in
                Button {
                    lab.sortOption = opt
                    FlavorFeedback.spoonTap()
                } label: {
                    Text(sortLabel(for: opt))
                        .font(.system(size: 13, weight: lab.sortOption == opt ? .bold : .medium, design: .rounded))
                        .foregroundColor(lab.sortOption == opt ? flavor.primaryTint : SpicePalette.flourDustFallback)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(lab.sortOption == opt ? flavor.primaryTint.opacity(0.15) : Color.clear)
                        )
                }
            }

            Spacer()

            Text("\(lab.filteredRecipes.count)")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(SpicePalette.peppercornFallback)
        }
        .padding(.vertical, 4)
    }

    private func sortLabel(for opt: FlavorLabViewModel.LabSortOption) -> String {
        switch opt {
        case .recent: return L10n.string("lab.sort.recent")
        case .name: return L10n.string("lab.sort.name")
        case .cost: return L10n.string("lab.sort.cost")
        case .ingredients: return L10n.string("lab.sort.ingredients")
        }
    }

    // MARK: – Recipe List

    private var recipeList: some View {
        Group {
            if lab.filteredRecipes.isEmpty {
                if lab.recipes.isEmpty {
                    emptyLabView
                } else {
                    Text(L10n.string("common.noData"))
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(SpicePalette.flourDustFallback)
                        .padding(.top, 40)
                }
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(lab.filteredRecipes) { recipe in
                        RecipePotCard(
                            recipe: recipe,
                            flavor: flavor,
                            isExpanded: expandedRecipeID == recipe.id,
                            isFavorite: favorites.isFavorite(recipeID: recipe.id),
                            ingredients: lab.ingredientsForRecipe(potID: recipe.id),
                            toBuyStore: ToBuyStore.shared,
                            onTap: {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    expandedRecipeID = expandedRecipeID == recipe.id ? nil : recipe.id
                                }
                            },
                            onAddIngredient: {
                                lab.prepareAddIngredient(potID: recipe.id)
                            },
                            onToggleToBuy: { itemID in
                                ToBuyStore.shared.toggle(itemID: itemID)
                                FlavorFeedback.spoonTap()
                            },
                            onAddAllToBasket: {
                                for ing in lab.ingredientsForRecipe(potID: recipe.id) {
                                    ToBuyStore.shared.add(itemID: ing.groceryItemID)
                                }
                                coordinator.switchTab(to: .basket)
                                FlavorFeedback.goldenCrust()
                            },
                            onToggleFavorite: {
                                favorites.toggle(recipeID: recipe.id)
                                FlavorFeedback.spoonTap()
                            },
                            onDelete: {
                                deleteTargetID = recipe.id
                                showDeleteConfirm = true
                            }
                        )
                    }
                }
            }
        }
    }

    // MARK: – Empty State

    private var emptyLabView: some View {
        VStack(spacing: 20) {
            Text("🧪")
                .font(.system(size: 56))
                .opacity(0.7)

            Text(L10n.string("lab.empty"))
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(SpicePalette.flourDustFallback)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                lab.showNewRecipeSheet = true
                FlavorFeedback.ovenDoorShut()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text(L10n.string("lab.newRecipe"))
                }
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(SpicePalette.burntCrustFallback)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(flavor.primaryTint, in: Capsule())
            }
            .flavorTap(.ovenDoorShut)

            Spacer().frame(height: 40)
        }
        .padding(.top, 40)
    }
}

// MARK: - Recipe Pot Card

struct RecipePotCard: View {

    let recipe: RecipeCard
    let flavor: AccentFlavor
    let isExpanded: Bool
    let isFavorite: Bool
    let ingredients: [RecipeIngredientRow]
    @ObservedObject var toBuyStore: ToBuyStore
    let onTap: () -> Void
    let onAddIngredient: () -> Void
    let onToggleToBuy: (String) -> Void
    let onAddAllToBasket: () -> Void
    let onToggleFavorite: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    Text(recipe.dishEmoji)
                        .font(.system(size: 36))
                        .frame(width: 50, height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(SpicePalette.midnightCocoaFallback)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(recipe.dishName)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(SpicePalette.vanillaCreamFallback)
                            .lineLimit(1)

                        Text("\(recipe.ingredientCount) \(L10n.string("lab.ingredients")) · \(recipe.formattedCost)")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(SpicePalette.flourDustFallback)
                    }

                    Spacer()

                    Button {
                        onToggleFavorite()
                    } label: {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 18))
                            .foregroundColor(isFavorite ? flavor.primaryTint : SpicePalette.peppercornFallback)
                    }
                    .buttonStyle(.plain)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(SpicePalette.peppercornFallback)
                }
                .padding(14)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(ingredients) { ing in
                        HStack(spacing: 8) {
                            Button {
                                onToggleToBuy(ing.groceryItemID)
                            } label: {
                                Image(systemName: toBuyStore.contains(itemID: ing.groceryItemID) ? "cart.badge.plus" : "checkmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(toBuyStore.contains(itemID: ing.groceryItemID) ? flavor.primaryTint : SpicePalette.basilLeafFallback)
                            }
                            .buttonStyle(.plain)

                            Text(ing.emoji)
                                .font(.system(size: 20))
                            Text(ing.recipeName)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(SpicePalette.vanillaCreamFallback)
                                .lineLimit(1)
                            Spacer()
                            Text("\(formatQty(ing.quantityNeeded)) \(ing.quantityUnit)")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(SpicePalette.flourDustFallback)
                            Text(ing.formattedLineCost)
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundColor(flavor.primaryTint)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(SpicePalette.midnightCocoaFallback)
                        )
                    }

                    HStack(spacing: 12) {
                        Button(action: onAddIngredient) {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle")
                                Text(L10n.string("lab.addIngredient"))
                            }
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(flavor.primaryTint)
                        }
                        .flavorTap(.spoonTap)

                        if !ingredients.isEmpty {
                            Button(action: onAddAllToBasket) {
                                HStack(spacing: 6) {
                                    Image(systemName: "cart.badge.plus")
                                    Text(L10n.string("lab.addAllToBasket"))
                                }
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(flavor.primaryTint)
                            }
                            .flavorTap(.spoonTap)
                        }

                        Spacer()

                        Button(role: .destructive, action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: 14))
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(SpicePalette.smokedPaprikaFallback)
        )
    }

    private func formatQty(_ q: Double) -> String {
        if q == floor(q) { return "\(Int(q))" }
        return String(format: "%.1f", q)
    }
}

// MARK: - New Recipe Sheet

struct NewRecipeSheet: View {

    @ObservedObject var lab: FlavorLabViewModel
    let flavor: AccentFlavor
    @Environment(\.dismiss) private var dismiss

    @State private var showAddIngredientSection = false
    @State private var addMode: AddIngredientMode = .new
    @State private var inlineSelectedItemID = ""
    @State private var inlineQuantity = "1"
    @State private var inlineUnit = "pcs"

    enum AddIngredientMode { case new, fromBasket }

    var body: some View {
        NavigationView {
            ZStack {
                SpicePalette.burntCrustFallback
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Emoji picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.string("lab.dishEmoji"))
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(SpicePalette.flourDustFallback)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(FlavorLabViewModel.dishEmojis, id: \.self) { emoji in
                                        Button {
                                            lab.newDishEmoji = emoji
                                            FlavorFeedback.spoonTap()
                                        } label: {
                                            Text(emoji)
                                                .font(.system(size: 28))
                                                .frame(width: 44, height: 44)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                        .fill(lab.newDishEmoji == emoji
                                                              ? flavor.primaryTint.opacity(0.25)
                                                              : SpicePalette.smokedPaprikaFallback)
                                                )
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                        .strokeBorder(lab.newDishEmoji == emoji
                                                                      ? flavor.primaryTint
                                                                      : Color.clear, lineWidth: 2)
                                                )
                                        }
                                    }
                                }
                            }
                        }

                        KitchenTextField(
                            labelKey: "lab.dishName",
                            text: $lab.newDishName,
                            icon: "fork.knife"
                        )

                        // Servings
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.string("lab.servings"))
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(SpicePalette.flourDustFallback)

                            Stepper(value: $lab.newServings, in: 1...20) {
                                Text("\(lab.newServings)")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(SpicePalette.vanillaCreamFallback)
                            }
                            .tint(flavor.primaryTint)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(SpicePalette.smokedPaprikaFallback)
                        )

                        // Ingredients
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(L10n.string("lab.ingredients"))
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(SpicePalette.flourDustFallback)
                                Spacer()
                                Button {
                                    showAddIngredientSection.toggle()
                                    if !showAddIngredientSection {
                                        inlineSelectedItemID = ""
                                        lab.resetNewIngredientForm()
                                    }
                                    FlavorFeedback.spoonTap()
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: showAddIngredientSection ? "minus.circle.fill" : "plus.circle.fill")
                                        Text(L10n.string("lab.addIngredient"))
                                    }
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundColor(flavor.primaryTint)
                                }
                                .flavorTap(.spoonTap)
                            }

                            if showAddIngredientSection {
                                addIngredientSection
                            }

                            ForEach(lab.pendingNewRecipeIngredients) { ing in
                                HStack(spacing: 10) {
                                    Button {
                                        lab.togglePendingIngredientNeedsToBuy(id: ing.id)
                                    } label: {
                                        Image(systemName: ing.needsToBuy ? "cart.badge.plus" : "checkmark.circle.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(ing.needsToBuy ? flavor.primaryTint : SpicePalette.basilLeafFallback)
                                    }
                                    .buttonStyle(.plain)

                                    Text(ing.emoji).font(.system(size: 20))
                                    Text(ing.recipeName)
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundColor(SpicePalette.vanillaCreamFallback)
                                        .lineLimit(1)
                                    Spacer()
                                    Text("\(formatPendingQty(ing.quantityNeeded)) \(ing.quantityUnit)")
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundColor(SpicePalette.flourDustFallback)
                                    Button {
                                        lab.removePendingIngredient(id: ing.id)
                                        FlavorFeedback.cleaverChop()
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 18))
                                            .foregroundColor(SpicePalette.peppercornFallback)
                                    }
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(SpicePalette.midnightCocoaFallback)
                                )
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(SpicePalette.smokedPaprikaFallback)
                        )
                    }
                    .padding(16)
                }
            }
            .navigationTitle(L10n.string("lab.newRecipe"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("common.cancel")) {
                        lab.resetNewRecipeForm()
                        dismiss()
                    }
                    .foregroundColor(SpicePalette.flourDustFallback)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string("common.save")) {
                        lab.createRecipe()
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(flavor.primaryTint)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func formatPendingQty(_ q: Double) -> String {
        if q == floor(q) { return "\(Int(q))" }
        return String(format: "%.1f", q)
    }

    private var addIngredientSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("", selection: $addMode) {
                Text(L10n.string("lab.addNewIngredient")).tag(AddIngredientMode.new)
                Text(L10n.string("lab.fromBasket")).tag(AddIngredientMode.fromBasket)
            }
            .pickerStyle(.segmented)
            .tint(flavor.primaryTint)

            if addMode == .new {
                addNewIngredientForm
            } else {
                selectFromBasketForm
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(SpicePalette.midnightCocoaFallback)
        )
    }

    private var addNewIngredientForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            KitchenTextField(labelKey: "basket.itemName", text: $lab.newIngredientName, icon: "tag")

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.string("basket.emoji"))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(SpicePalette.flourDustFallback)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(MarketBasketViewModel.emojiPantry, id: \.self) { emoji in
                            Button {
                                lab.newIngredientEmoji = emoji
                                FlavorFeedback.spoonTap()
                            } label: {
                                Text(emoji)
                                    .font(.system(size: 24))
                                    .frame(width: 40, height: 40)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(lab.newIngredientEmoji == emoji
                                                  ? flavor.primaryTint.opacity(0.25)
                                                  : SpicePalette.smokedPaprikaFallback)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .strokeBorder(lab.newIngredientEmoji == emoji
                                                          ? flavor.primaryTint
                                                          : Color.clear, lineWidth: 2)
                                    )
                            }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.string("basket.category"))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(SpicePalette.flourDustFallback)

                LazyVGrid(columns: [
                    GridItem(.flexible()), GridItem(.flexible()),
                    GridItem(.flexible()), GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(GroceryCategory.allCases) { cat in
                        Button {
                            lab.newIngredientCategory = cat
                            lab.newIngredientEmoji = cat.defaultEmoji
                            FlavorFeedback.pepperGrind()
                        } label: {
                            VStack(spacing: 4) {
                                Text(cat.defaultEmoji)
                                    .font(.system(size: 18))
                                Text(L10n.string(cat.labelKey))
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            .foregroundColor(lab.newIngredientCategory == cat
                                             ? SpicePalette.burntCrustFallback
                                             : SpicePalette.flourDustFallback)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(lab.newIngredientCategory == cat
                                          ? flavor.primaryTint
                                          : SpicePalette.smokedPaprikaFallback)
                            )
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.string("lab.quantity"))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(SpicePalette.flourDustFallback)

                HStack(spacing: 12) {
                    TextField("1", text: $lab.newIngredientQuantity)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(flavor.primaryTint)
                        .keyboardType(.decimalPad)
                        .frame(width: 70)
                        .multilineTextAlignment(.center)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(SpicePalette.smokedPaprikaFallback)
                        )

                    Picker("", selection: $lab.newIngredientUnit) {
                        ForEach(FlavorLabViewModel.quantityUnits, id: \.self) { unit in
                            Text(unit).tag(unit)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(flavor.primaryTint)
                    .frame(maxWidth: .infinity)
                }
            }

            Button {
                lab.addNewIngredientToRecipe()
                FlavorFeedback.goldenCrust()
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text(L10n.string("common.add"))
                }
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(SpicePalette.burntCrustFallback)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(flavor.primaryTint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(lab.newIngredientName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private var selectFromBasketForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(lab.availableGroceryItems()) { item in
                        Button {
                            inlineSelectedItemID = item.id
                            FlavorFeedback.spoonTap()
                        } label: {
                            HStack(spacing: 6) {
                                Text(item.emoji).font(.system(size: 18))
                                Text(item.recipeName)
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundColor(SpicePalette.vanillaCreamFallback)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(inlineSelectedItemID == item.id
                                          ? flavor.primaryTint.opacity(0.25)
                                          : SpicePalette.smokedPaprikaFallback)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(inlineSelectedItemID == item.id
                                                  ? flavor.primaryTint
                                                  : Color.clear, lineWidth: 2)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if !inlineSelectedItemID.isEmpty {
                HStack(spacing: 12) {
                    TextField("1", text: $inlineQuantity)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(flavor.primaryTint)
                        .keyboardType(.decimalPad)
                        .frame(width: 60)
                        .multilineTextAlignment(.center)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(SpicePalette.smokedPaprikaFallback)
                        )

                    Picker("", selection: $inlineUnit) {
                        ForEach(FlavorLabViewModel.quantityUnits, id: \.self) { unit in
                            Text(unit).tag(unit)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(flavor.primaryTint)

                    Button {
                        addPendingIngredientInline()
                    } label: {
                        Text(L10n.string("common.add"))
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(SpicePalette.burntCrustFallback)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(flavor.primaryTint, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func addPendingIngredientInline() {
        let qtyStr = inlineQuantity.replacingOccurrences(of: ",", with: ".")
        guard let qty = Double(qtyStr), qty > 0 else { return }
        guard let item: GroceryItem = PantryStore.shared.fetchOne(
            entity: "GroceryItem",
            key: "itemID",
            value: inlineSelectedItemID
        ) else { return }

        let pending = PendingIngredient(
            id: UUID().uuidString,
            groceryItemID: item.itemID,
            recipeName: item.recipeName,
            emoji: item.emoji,
            quantityNeeded: qty,
            quantityUnit: inlineUnit.isEmpty ? "pcs" : inlineUnit,
            needsToBuy: true
        )
        lab.addPendingIngredient(pending)
        FlavorFeedback.goldenCrust()

        inlineQuantity = "1"
        inlineUnit = "pcs"
        inlineSelectedItemID = ""
    }
}

// MARK: - Add Recipe Ingredient Sheet

struct AddRecipeIngredientSheet: View {

    @ObservedObject var lab: FlavorLabViewModel
    let flavor: AccentFlavor
    @Environment(\.dismiss) private var dismiss

    @State private var availableItems: [GroceryShelfItem] = []
    @State private var addMode: AddRecipeIngredientMode = .fromBasket

    enum AddRecipeIngredientMode { case new, fromBasket }

    var body: some View {
        NavigationView {
            ZStack {
                SpicePalette.burntCrustFallback
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        Picker("", selection: $addMode) {
                            Text(L10n.string("lab.addNewIngredient")).tag(AddRecipeIngredientMode.new)
                            Text(L10n.string("lab.fromBasket")).tag(AddRecipeIngredientMode.fromBasket)
                        }
                        .pickerStyle(.segmented)
                        .tint(flavor.primaryTint)

                        if addMode == .new {
                            addNewIngredientFormForExistingRecipe
                        } else {
                            selectFromBasketContent
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle(L10n.string("lab.addIngredient"))
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                availableItems = lab.availableGroceryItems()
                lab.resetNewIngredientForm()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("common.cancel")) {
                        lab.showAddIngredientSheet = false
                        dismiss()
                    }
                    .foregroundColor(SpicePalette.flourDustFallback)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string("common.add")) {
                        if addMode == .new {
                            if lab.addNewIngredientToExistingRecipe() {
                                FlavorFeedback.goldenCrust()
                                dismiss()
                            }
                        } else {
                            lab.addIngredientToRecipe()
                            dismiss()
                        }
                    }
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(flavor.primaryTint)
                    .disabled(addMode == .new
                        ? lab.newIngredientName.trimmingCharacters(in: .whitespaces).isEmpty
                        : lab.addIngredientSelectedItemID.isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var addNewIngredientFormForExistingRecipe: some View {
        VStack(alignment: .leading, spacing: 16) {
            KitchenTextField(labelKey: "basket.itemName", text: $lab.newIngredientName, icon: "tag")

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.string("basket.emoji"))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(SpicePalette.flourDustFallback)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(MarketBasketViewModel.emojiPantry, id: \.self) { emoji in
                            Button {
                                lab.newIngredientEmoji = emoji
                                FlavorFeedback.spoonTap()
                            } label: {
                                Text(emoji)
                                    .font(.system(size: 24))
                                    .frame(width: 40, height: 40)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(lab.newIngredientEmoji == emoji
                                                  ? flavor.primaryTint.opacity(0.25)
                                                  : SpicePalette.smokedPaprikaFallback)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .strokeBorder(lab.newIngredientEmoji == emoji
                                                          ? flavor.primaryTint
                                                          : Color.clear, lineWidth: 2)
                                    )
                            }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.string("basket.category"))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(SpicePalette.flourDustFallback)

                LazyVGrid(columns: [
                    GridItem(.flexible()), GridItem(.flexible()),
                    GridItem(.flexible()), GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(GroceryCategory.allCases) { cat in
                        Button {
                            lab.newIngredientCategory = cat
                            lab.newIngredientEmoji = cat.defaultEmoji
                            FlavorFeedback.pepperGrind()
                        } label: {
                            VStack(spacing: 4) {
                                Text(cat.defaultEmoji)
                                    .font(.system(size: 18))
                                Text(L10n.string(cat.labelKey))
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            .foregroundColor(lab.newIngredientCategory == cat
                                             ? SpicePalette.burntCrustFallback
                                             : SpicePalette.flourDustFallback)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(lab.newIngredientCategory == cat
                                          ? flavor.primaryTint
                                          : SpicePalette.smokedPaprikaFallback)
                            )
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.string("lab.quantity"))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(SpicePalette.flourDustFallback)

                HStack(spacing: 12) {
                    TextField("1", text: $lab.newIngredientQuantity)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(flavor.primaryTint)
                        .keyboardType(.decimalPad)
                        .frame(width: 70)
                        .multilineTextAlignment(.center)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(SpicePalette.smokedPaprikaFallback)
                        )

                    Picker("", selection: $lab.newIngredientUnit) {
                        ForEach(FlavorLabViewModel.quantityUnits, id: \.self) { unit in
                            Text(unit).tag(unit)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(flavor.primaryTint)
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var selectFromBasketContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.string("lab.selectProduct"))
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(SpicePalette.flourDustFallback)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(availableItems) { item in
                Button {
                    lab.addIngredientSelectedItemID = item.id
                    FlavorFeedback.spoonTap()
                } label: {
                    HStack(spacing: 12) {
                        Text(item.emoji)
                            .font(.system(size: 24))
                        Text(item.recipeName)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(SpicePalette.vanillaCreamFallback)
                            .lineLimit(1)
                        Spacer()
                        if lab.addIngredientSelectedItemID == item.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(flavor.primaryTint)
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(lab.addIngredientSelectedItemID == item.id
                                  ? flavor.primaryTint.opacity(0.2)
                                  : SpicePalette.smokedPaprikaFallback)
                    )
                }
                .buttonStyle(.plain)
            }

            if !lab.addIngredientSelectedItemID.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.string("lab.quantity"))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(SpicePalette.flourDustFallback)

                    HStack(spacing: 12) {
                        TextField("1", text: $lab.addIngredientQuantity)
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(flavor.primaryTint)
                            .keyboardType(.decimalPad)
                            .frame(width: 80)
                            .multilineTextAlignment(.center)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(SpicePalette.midnightCocoaFallback)
                            )

                        Picker("", selection: $lab.addIngredientUnit) {
                            ForEach(FlavorLabViewModel.quantityUnits, id: \.self) { unit in
                                Text(unit).tag(unit)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(flavor.primaryTint)
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct FlavorLabView_Previews: PreviewProvider {
    static var previews: some View {
        FlavorLabView()
            .environmentObject(KitchenCoordinator())
            .environment(\.accentFlavor, .saffron)
            .preferredColorScheme(.dark)
    }
}
#endif
