// KitchenDashboardView.swift
// PriceKitchen
//
// The "Kitchen" tab — your daily flavor report.
// Shows chef rank, XP bar, stat cards, recent price moves, and a daily tip.

import SwiftUI

// MARK: - Kitchen Dashboard View

struct KitchenDashboardView: View {

    @EnvironmentObject private var coordinator: KitchenCoordinator
    @Environment(\.accentFlavor) private var flavor
    @StateObject private var burner = KitchenDashboardViewModel()

    @State private var cardsAppeared = false
    @State private var showConfetti = false

    var body: some View {
        NavigationView {
            ZStack {
                SpicePalette.burntCrustFallback
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        greetingHeader
                        chefRankCard
                        statsGrid
                        randomRecipeButton
                        recentMovesSection
                        dailyTipCard
                        Spacer(minLength: 30)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }

                // Level-up confetti overlay
                ConfettiBurstCanvas(isActive: $showConfetti)
            }
            .navigationBarHidden(true)
            .onAppear {
                burner.warmUpKitchen()
                withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                    cardsAppeared = true
                }
            }
            .onChange(of: coordinator.activeTab) { tab in
                if tab == .kitchen {
                    burner.warmUpKitchen()
                }
            }
            .onChange(of: burner.showLevelUpCelebration) { celebrating in
                if celebrating {
                    showConfetti = true
                    burner.showLevelUpCelebration = false
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: – Greeting Header

    private var greetingHeader: some View {
        HStack(spacing: 12) {
            // Avatar
            Text(burner.avatarEmoji)
                .font(.system(size: 44))
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(SpicePalette.smokedPaprikaFallback)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.string("kitchen.greeting", fallback: "Hello, %@!", burner.chefName))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(SpicePalette.vanillaCreamFallback)

                Text(L10n.string("kitchen.subtitle", fallback: "Your daily flavor report"))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(SpicePalette.flourDustFallback)
            }

            Spacer()
        }
        .padding(.top, 12)
        .opacity(cardsAppeared ? 1 : 0)
        .offset(y: cardsAppeared ? 0 : 15)
        .animation(.easeOut(duration: 0.5), value: cardsAppeared)
    }

    // MARK: – Chef Rank Card (XP + Progress)

    private var chefRankCard: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.string("kitchen.card.level", fallback: "Chef Rank"))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(SpicePalette.flourDustFallback)

                    Text(burner.rankTitle)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(flavor.primaryTint)
                }

                Spacer()

                // Level badge
                ZStack {
                    Circle()
                        .fill(flavor.primaryTint.opacity(0.15))
                        .frame(width: 52, height: 52)

                    Text("\(burner.currentLevel)")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundColor(flavor.primaryTint)
                }
            }

            // XP progress bar
            VStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(SpicePalette.burntCrustFallback)
                            .frame(height: 10)

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [flavor.primaryTint, flavor.secondaryTint],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: geo.size.width * CGFloat(burner.levelProgress),
                                height: 10
                            )
                            .animation(.spring(response: 0.8, dampingFraction: 0.7), value: burner.levelProgress)
                    }
                }
                .frame(height: 10)

                HStack {
                    Text("\(burner.totalXP) \(L10n.string("common.xp", fallback: "XP"))")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(flavor.primaryTint)

                    Spacer()

                    Text(L10n.string("kitchen.xpToNext", fallback: "%d XP to next level", burner.xpToNext))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(SpicePalette.flourDustFallback)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(SpicePalette.smokedPaprikaFallback)
        )
        .opacity(cardsAppeared ? 1 : 0)
        .offset(y: cardsAppeared ? 0 : 20)
        .animation(.easeOut(duration: 0.5).delay(0.1), value: cardsAppeared)
    }

    // MARK: – Stats Grid (3 cards)

    private var statsGrid: some View {
        HStack(spacing: 12) {
            StatMorselCard(
                iconEmoji: "🧺",
                titleKey: "kitchen.card.items",
                titleFallback: "Items Tracked",
                value: "\(burner.dishesTracked)",
                tint: flavor.primaryTint,
                delay: 0.15
            )

            StatMorselCard(
                iconEmoji: "🏷️",
                titleKey: "kitchen.card.entries",
                titleFallback: "Prices Logged",
                value: "\(burner.pricesLogged)",
                tint: flavor.secondaryTint,
                delay: 0.2
            )

            StatMorselCard(
                iconEmoji: "🔥",
                titleKey: "kitchen.card.streak",
                titleFallback: "Day Streak",
                value: "\(burner.dayStreak)",
                tint: SpicePalette.papayaPulpFallback,
                delay: 0.25
            )
        }
        .opacity(cardsAppeared ? 1 : 0)
        .animation(.easeOut(duration: 0.5).delay(0.15), value: cardsAppeared)
    }

    // MARK: – Random Recipe Button

    private var randomRecipeButton: some View {
        Button {
            coordinator.pickRandomRecipeForToday()
        } label: {
            HStack(spacing: 12) {
                Text("🎲")
                    .font(.system(size: 28))
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(flavor.primaryTint.opacity(burner.recipeCount > 0 ? 0.2 : 0.08))
                    )

                Text(L10n.string("kitchen.randomRecipe"))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(burner.recipeCount > 0 ? SpicePalette.vanillaCreamFallback : SpicePalette.flourDustFallback)
                    .multilineTextAlignment(.leading)

                Spacer()

                if burner.recipeCount > 0 {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(flavor.primaryTint)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(SpicePalette.smokedPaprikaFallback)
            )
        }
        .buttonStyle(.plain)
        .disabled(burner.recipeCount == 0)
        .opacity(cardsAppeared ? 1 : 0)
        .offset(y: cardsAppeared ? 0 : 20)
        .animation(.easeOut(duration: 0.5).delay(0.2), value: cardsAppeared)
    }

    // MARK: – Recent Price Moves

    private var recentMovesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.string("kitchen.recent.title", fallback: "Latest Price Moves"))
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(SpicePalette.vanillaCreamFallback)

            if burner.recentMoves.isEmpty {
                emptyMovesPlaceholder
            } else {
                VStack(spacing: 8) {
                    ForEach(burner.recentMoves.prefix(5)) { move in
                        PriceMoveRow(move: move, flavor: flavor)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(SpicePalette.smokedPaprikaFallback)
        )
        .opacity(cardsAppeared ? 1 : 0)
        .offset(y: cardsAppeared ? 0 : 20)
        .animation(.easeOut(duration: 0.5).delay(0.25), value: cardsAppeared)
    }

    private var emptyMovesPlaceholder: some View {
        HStack(spacing: 12) {
            Text("📊")
                .font(.system(size: 28))

            Text(L10n.string("kitchen.recent.empty", fallback: "Log your first price to see changes here."))
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(SpicePalette.flourDustFallback)
                .lineSpacing(3)
        }
        .padding(.vertical, 8)
    }

    // MARK: – Daily Tip Card

    private var dailyTipCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(burner.dailyTip.emoji)
                .font(.system(size: 30))
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(flavor.primaryTint.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.string(burner.dailyTip.titleKey, fallback: "Chef's Tip"))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(flavor.primaryTint)

                Text(L10n.string(burner.dailyTip.bodyKey, fallback: "Track the same item weekly for the best inflation insights."))
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(SpicePalette.flourDustFallback)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(SpicePalette.smokedPaprikaFallback)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(flavor.primaryTint.opacity(0.15), lineWidth: 1)
                )
        )
        .opacity(cardsAppeared ? 1 : 0)
        .offset(y: cardsAppeared ? 0 : 20)
        .animation(.easeOut(duration: 0.5).delay(0.3), value: cardsAppeared)
    }
}

// MARK: - Stat Morsel Card

struct StatMorselCard: View {

    let iconEmoji: String
    let titleKey: String
    let titleFallback: String
    let value: String
    let tint: Color
    let delay: Double

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 8) {
            Text(iconEmoji)
                .font(.system(size: 24))

            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundColor(tint)

            Text(L10n.string(titleKey, fallback: titleFallback))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(SpicePalette.flourDustFallback)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(SpicePalette.smokedPaprikaFallback)
        )
        .scaleEffect(appeared ? 1.0 : 0.7)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.65).delay(delay)) {
                appeared = true
            }
        }
    }
}

// MARK: - Price Move Row

struct PriceMoveRow: View {

    let move: RecentPriceMove
    let flavor: AccentFlavor

    var body: some View {
        HStack(spacing: 12) {
            // Emoji
            Text(move.emoji)
                .font(.system(size: 26))
                .frame(width: 38, height: 38)

            // Name + store
            VStack(alignment: .leading, spacing: 2) {
                Text(move.recipeName)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(SpicePalette.vanillaCreamFallback)
                    .lineLimit(1)

                Text(move.marketStall)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(SpicePalette.flourDustFallback)
                    .lineLimit(1)
            }

            Spacer()

            // Price + change
            VStack(alignment: .trailing, spacing: 2) {
                Text(move.formattedPrice)
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundColor(SpicePalette.vanillaCreamFallback)

                Text(move.formattedChange)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(changeColor)
            }

            // Arrow indicator
            Image(systemName: arrowIcon)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(changeColor)
                .frame(width: 20)
        }
        .padding(.vertical, 6)
    }

    private var changeColor: Color {
        if move.isStable {
            return SpicePalette.peppercornFallback
        } else if move.isRising {
            return SpicePalette.chiliFlakeFallback
        } else {
            return SpicePalette.basilLeafFallback
        }
    }

    private var arrowIcon: String {
        if move.isStable {
            return "minus"
        } else if move.isRising {
            return "arrow.up.right"
        } else {
            return "arrow.down.right"
        }
    }
}

// MARK: - Preview

#if DEBUG
struct KitchenDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        KitchenDashboardView()
            .environmentObject(KitchenCoordinator())
            .environment(\.accentFlavor, .saffron)
            .preferredColorScheme(.dark)
    }
}
#endif
