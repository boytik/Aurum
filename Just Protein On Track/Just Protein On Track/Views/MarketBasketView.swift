// MarketBasketView.swift
// PriceKitchen
//
// The "Basket" tab — browse, add, and manage grocery items and price entries.
// Features: search, category chips, sort picker, add item/price sheets, swipe delete.

import SwiftUI

// MARK: - Market Basket View

struct MarketBasketView: View {

    @EnvironmentObject private var coordinator: KitchenCoordinator
    @Environment(\.accentFlavor) private var flavor
    @StateObject private var basket = MarketBasketViewModel()
    @State private var listAppeared = false

    var body: some View {
        NavigationView {
            ZStack {
                SpicePalette.burntCrustFallback
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    headerBar
                    searchBar
                    categoryChips
                    sortStrip

                    if basket.filteredShelf.isEmpty {
                        emptyBasketView
                    } else {
                        itemList
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                basket.stockShelves()
                withAnimation(.easeOut(duration: 0.4).delay(0.15)) {
                    listAppeared = true
                }
            }
            .sheet(isPresented: $basket.showAddItemSheet) {
                AddIngredientSheet(basket: basket, flavor: flavor)
            }
            .sheet(isPresented: $basket.showAddPriceSheet) {
                AddPriceTagSheet(basket: basket, flavor: flavor)
            }
            .alert(L10n.string("common.error"), isPresented: Binding(
                get: { basket.validationError != nil },
                set: { if !$0 { basket.validationError = nil } }
            )) {
                Button(L10n.string("common.done")) {
                    basket.validationError = nil
                }
            } message: {
                if let msg = basket.validationError {
                    Text(msg)
                }
            }
            .alert(
                L10n.string("common.delete"),
                isPresented: $basket.showDeleteConfirm
            ) {
                Button(L10n.string("common.cancel"), role: .cancel) { }
                Button(L10n.string("common.delete"), role: .destructive) {
                    basket.confirmDelete()
                }
            } message: {
                Text(L10n.string("basket.delete.confirm"))
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: – Header Bar

    private var headerBar: some View {
        HStack {
            Text(L10n.string("basket.title"))
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(SpicePalette.vanillaCreamFallback)

            Spacer()

            Button {
                FlavorFeedback.ovenDoorShut()
                basket.showAddItemSheet = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(flavor.primaryTint)
                    .symbolRenderingMode(.hierarchical)
            }
            .flavorTap(.ovenDoorShut)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    // MARK: – Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(SpicePalette.peppercornFallback)
                .font(.system(size: 15))

            TextField(
                L10n.string("basket.search.placeholder"),
                text: $basket.searchQuery
            )
            .font(.system(size: 15, design: .rounded))
            .foregroundColor(SpicePalette.vanillaCreamFallback)
            .autocorrectionDisabled()

            if !basket.searchQuery.isEmpty {
                Button {
                    basket.searchQuery = ""
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
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    // MARK: – Category Chips

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "All" chip
                CategoryChipView(
                    label: "All",
                    emoji: "🗂️",
                    isSelected: basket.selectedCategory == nil,
                    tint: flavor.primaryTint
                ) {
                    basket.selectedCategory = nil
                    FlavorFeedback.pepperGrind()
                }

                ForEach(GroceryCategory.allCases) { cat in
                    CategoryChipView(
                        label: L10n.string(cat.labelKey),
                        emoji: cat.defaultEmoji,
                        isSelected: basket.selectedCategory == cat,
                        tint: flavor.primaryTint
                    ) {
                        basket.selectedCategory = (basket.selectedCategory == cat) ? nil : cat
                        FlavorFeedback.pepperGrind()
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }

    // MARK: – Sort Strip

    private var sortStrip: some View {
        HStack(spacing: 6) {
            Text("⇅")
                .font(.system(size: 13))
                .foregroundColor(SpicePalette.flourDustFallback)

            ForEach(SortSeasoning.allCases) { sort in
                Button {
                    basket.activeSorting = sort
                    FlavorFeedback.spoonTap()
                } label: {
                    Text(L10n.string(sort.labelKey))
                        .font(.system(size: 13, weight: basket.activeSorting == sort ? .bold : .medium, design: .rounded))
                        .foregroundColor(basket.activeSorting == sort ? flavor.primaryTint : SpicePalette.flourDustFallback)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(basket.activeSorting == sort
                                      ? flavor.primaryTint.opacity(0.15)
                                      : Color.clear)
                        )
                }
            }

            Spacer()

            Text("\(basket.filteredShelf.count)")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(SpicePalette.peppercornFallback)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    // MARK: – Item List

    private var itemList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 10) {
                ForEach(Array(basket.filteredShelf.enumerated()), id: \.element.id) { index, item in
                    GroceryShelfRow(
                        item: item,
                        flavor: flavor,
                        onAddPrice: {
                            basket.prepareAddPrice(for: item)
                        },
                        onDelete: {
                            basket.prepareDelete(for: item)
                        }
                    )
                    .opacity(listAppeared ? 1 : 0)
                    .offset(y: listAppeared ? 0 : 15)
                    .animation(
                        .easeOut(duration: 0.35).delay(Double(index) * 0.04),
                        value: listAppeared
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 30)
        }
    }

    // MARK: – Empty State

    private var emptyBasketView: some View {
        VStack(spacing: 16) {
            Spacer()

            Text("🧺")
                .font(.system(size: 56))
                .opacity(0.7)

            Text(L10n.string("basket.empty"))
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(SpicePalette.flourDustFallback)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                FlavorFeedback.ovenDoorShut()
                basket.showAddItemSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text(L10n.string("basket.addItem"))
                }
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(SpicePalette.burntCrustFallback)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(flavor.primaryTint, in: Capsule())
            }
            .flavorTap(.ovenDoorShut)

            Spacer()
        }
    }
}

// MARK: - Category Chip View

struct CategoryChipView: View {

    let label: String
    let emoji: String
    let isSelected: Bool
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(emoji)
                    .font(.system(size: 13))
                Text(label)
                    .font(.system(size: 13, weight: isSelected ? .bold : .medium, design: .rounded))
                    .lineLimit(1)
            }
            .foregroundColor(isSelected ? SpicePalette.burntCrustFallback : SpicePalette.flourDustFallback)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(isSelected ? tint : SpicePalette.smokedPaprikaFallback)
            )
        }
    }
}

// MARK: - Grocery Shelf Row

struct GroceryShelfRow: View {

    let item: GroceryShelfItem
    let flavor: AccentFlavor
    let onAddPrice: () -> Void
    let onDelete: () -> Void

    @State private var swipeOffset: CGFloat = 0

    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete background
            HStack {
                Spacer()
                Button(action: onDelete) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                }
                .background(SpicePalette.chiliFlakeFallback)
                .cornerRadius(12)
            }
            .opacity(swipeOffset < -30 ? 1 : 0)

            // Main card
            HStack(spacing: 12) {
                // Emoji badge
                Text(item.emoji)
                    .font(.system(size: 30))
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(SpicePalette.midnightCocoaFallback)
                    )

                // Info
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.recipeName)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(SpicePalette.vanillaCreamFallback)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(item.marketStall)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(SpicePalette.flourDustFallback)
                            .lineLimit(1)

                        if item.priceCount > 0 {
                            Text("·")
                                .foregroundColor(SpicePalette.peppercornFallback)
                            Text(L10n.string("basket.priceCount", fallback: "%d entries", item.priceCount))
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(SpicePalette.peppercornFallback)
                        }
                    }
                }

                Spacer()

                // Price + change
                VStack(alignment: .trailing, spacing: 3) {
                    Text(item.formattedLatestPrice)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(SpicePalette.vanillaCreamFallback)

                    if let pct = item.percentChange {
                        let sign = pct >= 0 ? "+" : ""
                        Text("\(sign)\(String(format: "%.1f", pct))%")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(item.changeColor)
                    }
                }

                // Add price button
                Button(action: onAddPrice) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 22))
                        .foregroundColor(flavor.primaryTint)
                }
                .flavorTap(.spoonTap)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(SpicePalette.smokedPaprikaFallback)
            )
            .offset(x: swipeOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.width < 0 {
                            swipeOffset = max(value.translation.width, -80)
                        }
                    }
                    .onEnded { value in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if value.translation.width < -50 {
                                swipeOffset = -70
                            } else {
                                swipeOffset = 0
                            }
                        }
                    }
            )
            .onTapGesture {
                if swipeOffset != 0 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        swipeOffset = 0
                    }
                }
            }
        }
    }
}

// MARK: - Add Ingredient Sheet

struct AddIngredientSheet: View {

    @ObservedObject var basket: MarketBasketViewModel
    let flavor: AccentFlavor
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                SpicePalette.burntCrustFallback
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {

                        // Emoji picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.string("basket.emoji"))
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(SpicePalette.flourDustFallback)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(MarketBasketViewModel.emojiPantry, id: \.self) { emoji in
                                        Button {
                                            basket.newEmoji = emoji
                                            FlavorFeedback.spoonTap()
                                        } label: {
                                            Text(emoji)
                                                .font(.system(size: 26))
                                                .frame(width: 42, height: 42)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                        .fill(basket.newEmoji == emoji
                                                              ? flavor.primaryTint.opacity(0.25)
                                                              : SpicePalette.smokedPaprikaFallback)
                                                )
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                        .strokeBorder(basket.newEmoji == emoji
                                                                      ? flavor.primaryTint
                                                                      : Color.clear, lineWidth: 2)
                                                )
                                        }
                                    }
                                }
                            }
                        }

                        // Product name
                        KitchenTextField(
                            labelKey: "basket.itemName",
                            text: $basket.newRecipeName,
                            icon: "tag"
                        )

                        // Store
                        KitchenTextField(
                            labelKey: "basket.storeName",
                            text: $basket.newMarketStall,
                            icon: "building.2"
                        )

                        // Unit
                        KitchenTextField(
                            labelKey: "basket.unit",
                            text: $basket.newUnitLabel,
                            icon: "scalemass"
                        )

                        // Category picker
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
                                        basket.newCategory = cat
                                        basket.newEmoji = cat.defaultEmoji
                                        FlavorFeedback.pepperGrind()
                                    } label: {
                                        VStack(spacing: 4) {
                                            Text(cat.defaultEmoji)
                                                .font(.system(size: 20))
                                            Text(L10n.string(cat.labelKey))
                                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.7)
                                        }
                                        .foregroundColor(basket.newCategory == cat
                                                         ? SpicePalette.burntCrustFallback
                                                         : SpicePalette.flourDustFallback)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(basket.newCategory == cat
                                                      ? flavor.primaryTint
                                                      : SpicePalette.smokedPaprikaFallback)
                                        )
                                    }
                                }
                            }
                        }

                        // Currency picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.string("basket.currency"))
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(SpicePalette.flourDustFallback)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(MarketBasketViewModel.currencyBowl, id: \.code) { cur in
                                        Button {
                                            basket.newCurrencyCode = cur.code
                                            FlavorFeedback.spoonTap()
                                        } label: {
                                            Text("\(cur.symbol) \(cur.code)")
                                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                                .foregroundColor(basket.newCurrencyCode == cur.code
                                                                 ? SpicePalette.burntCrustFallback
                                                                 : SpicePalette.flourDustFallback)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(
                                                    Capsule()
                                                        .fill(basket.newCurrencyCode == cur.code
                                                              ? flavor.primaryTint
                                                              : SpicePalette.smokedPaprikaFallback)
                                                )
                                        }
                                    }
                                }
                            }
                        }

                        // Notes
                        KitchenTextField(
                            labelKey: "basket.notes",
                            text: $basket.newNotes,
                            icon: "note.text"
                        )

                        Spacer(minLength: 20)
                    }
                    .padding(16)
                }
            }
            .navigationTitle(L10n.string("basket.addItem"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("common.cancel")) {
                        basket.resetAddItemForm()
                        dismiss()
                    }
                    .foregroundColor(SpicePalette.flourDustFallback)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string("common.save")) {
                        basket.addGroceryItem()
                    }
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(flavor.primaryTint)
                }
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - Add Price Tag Sheet

struct AddPriceTagSheet: View {

    @ObservedObject var basket: MarketBasketViewModel
    let flavor: AccentFlavor
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                SpicePalette.burntCrustFallback
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Item label
                        HStack {
                            Text("🏷️")
                                .font(.system(size: 28))
                            Text(basket.priceTargetName)
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(SpicePalette.vanillaCreamFallback)
                            Spacer()
                        }
                        .padding(.top, 8)

                        // Price input
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.string("basket.price"))
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(SpicePalette.flourDustFallback)

                            HStack(spacing: 12) {
                                Text("💰")
                                    .font(.system(size: 24))

                                TextField("0.00", text: $basket.newPriceAmount)
                                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                                    .foregroundColor(flavor.primaryTint)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(SpicePalette.smokedPaprikaFallback)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .strokeBorder(flavor.primaryTint.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }

                        // Store
                        KitchenTextField(
                            labelKey: "basket.storeName",
                            text: $basket.newPriceMarket,
                            icon: "building.2"
                        )

                        // Memo
                        KitchenTextField(
                            labelKey: "basket.notes",
                            text: $basket.newPriceMemo,
                            icon: "note.text"
                        )

                        Spacer(minLength: 20)
                    }
                    .padding(16)
                }
            }
            .navigationTitle(L10n.string("basket.addPrice"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("common.cancel")) {
                        basket.resetAddPriceForm()
                        dismiss()
                    }
                    .foregroundColor(SpicePalette.flourDustFallback)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string("common.save")) {
                        basket.addPriceTag()
                    }
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(flavor.primaryTint)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Kitchen Text Field (Reusable)

struct KitchenTextField: View {

    let labelKey: String
    @Binding var text: String
    var icon: String = "pencil"

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.string(labelKey))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(SpicePalette.flourDustFallback)

            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(SpicePalette.peppercornFallback)
                    .frame(width: 20)

                TextField("", text: $text)
                    .font(.system(size: 15, design: .rounded))
                    .foregroundColor(SpicePalette.vanillaCreamFallback)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(SpicePalette.smokedPaprikaFallback)
            )
        }
    }
}

// MARK: - Preview

#if DEBUG
struct MarketBasketView_Previews: PreviewProvider {
    static var previews: some View {
        MarketBasketView()
            .environmentObject(KitchenCoordinator())
            .environment(\.accentFlavor, .saffron)
            .preferredColorScheme(.dark)
    }
}
#endif
