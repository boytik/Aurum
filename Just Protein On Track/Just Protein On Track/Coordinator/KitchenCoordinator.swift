// KitchenCoordinator.swift
// PriceKitchen
//
// MVVM + Coordinator: this is the top-level router.
// Manages app lifecycle phases (splash → onboarding → main kitchen)
// and holds shared state like the user's accent flavor.

import SwiftUI
import Combine
import CoreData

// MARK: - App Phase

enum KitchenPhase: Equatable {
    case preheating          // splash screen
    case remoteOfferGate     // server probe → WebView or native
    case tastingMenu         // onboarding
    case cooking             // main TabView
}

// MARK: - Tab Destination

enum KitchenTab: Int, CaseIterable, Identifiable {
    case kitchen     = 0
    case basket      = 1
    case lab         = 2
    case spiceRack   = 3

    var id: Int { rawValue }

    var labelKey: String {
        switch self {
        case .kitchen:   return "tab.kitchen"
        case .basket:    return "tab.basket"
        case .lab:       return "tab.lab"
        case .spiceRack: return "tab.spiceRack"
        }
    }

    var iconName: String {
        switch self {
        case .kitchen:   return "house.fill"
        case .basket:    return "cart.fill"
        case .lab:       return "flask.fill"
        case .spiceRack: return "gearshape.fill"
        }
    }

    var accessibilityKey: String {
        switch self {
        case .kitchen:   return "a11y.tab.kitchen"
        case .basket:    return "a11y.tab.basket"
        case .lab:       return "a11y.tab.lab"
        case .spiceRack: return "a11y.tab.spiceRack"
        }
    }
}

// MARK: - Kitchen Coordinator (ObservableObject)

final class KitchenCoordinator: ObservableObject {

    // MARK: – Published State

    @Published var phase: KitchenPhase = .preheating
    @Published var activeTab: KitchenTab = .kitchen
    @Published var selectedFlavor: AccentFlavor = .saffron
    @Published var saveErrorMessage: String?

    /// When set, Lab tab will expand this recipe on appear.
    @Published var labRecipeToExpand: String?

    // MARK: – Persistent Flags

    @AppStorage("hasSeenTastingMenu") private var hasSeenOnboarding = false

    // MARK: – Dependencies

    let pantry = PantryStore.shared

    // MARK: – Init

    init() {
        PantryStore.onSaveError = { [weak self] error in
            DispatchQueue.main.async {
                self?.saveErrorMessage = error.localizedDescription
            }
        }
        pantry.seedKitchenIfNeeded()
        loadAccentFromProfile()
    }

    // MARK: – Phase Transitions

    /// Called when splash animation finishes.
    func splashDidFinish() {
        withAnimation(.easeInOut(duration: 0.5)) {
            phase = .remoteOfferGate
        }
        FlavorFeedback.ovenDoorShut()
    }

    /// Called after remote-offer gate chooses the native app path.
    func enterNativeAfterRemoteOfferGate() {
        withAnimation(.easeInOut(duration: 0.5)) {
            phase = hasSeenOnboarding ? .cooking : .tastingMenu
        }
    }

    /// Called when onboarding completes.
    func onboardingDidFinish() {
        hasSeenOnboarding = true
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            phase = .cooking
        }
        FlavorFeedback.goldenCrust()
    }

    /// Switch tab programmatically.
    func switchTab(to tab: KitchenTab) {
        guard activeTab != tab else { return }
        activeTab = tab
        FlavorFeedback.pepperGrind()
    }

    /// Picks a deterministic "random" recipe for today (same all day) and switches to Lab.
    /// Returns true if a recipe was found and switched.
    @discardableResult
    func pickRandomRecipeForToday() -> Bool {
        let pots: [RecipePot] = pantry.fetchAll(
            entity: "RecipePot",
            sortKey: "dateCreated",
            ascending: true
        )
        guard !pots.isEmpty else { return false }

        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        let index = dayOfYear % pots.count
        let recipe = pots[index]

        labRecipeToExpand = recipe.potID
        activeTab = .lab
        FlavorFeedback.goldenCrust()
        return true
    }

    /// Number of recipes (for enabling random recipe button).
    var recipeCount: Int {
        let pots: [RecipePot] = pantry.fetchAll(
            entity: "RecipePot",
            sortKey: "dateCreated",
            ascending: true
        )
        return pots.count
    }

    // MARK: – Accent Flavor

    func updateAccentFlavor(_ flavor: AccentFlavor) {
        selectedFlavor = flavor
        saveAccentToProfile(flavor)
        FlavorFeedback.spoonTap()
    }

    private func loadAccentFromProfile() {
        if let profile: ChefProfile = pantry.fetchOne(
            entity: "ChefProfile",
            key: "profileID",
            value: fetchFirstProfileID() ?? ""
        ) {
            selectedFlavor = AccentFlavor(rawValue: profile.accentFlavor) ?? .saffron
        }
    }

    private func saveAccentToProfile(_ flavor: AccentFlavor) {
        if let profile: ChefProfile = pantry.fetchOne(
            entity: "ChefProfile",
            key: "profileID",
            value: fetchFirstProfileID() ?? ""
        ) {
            profile.accentFlavor = flavor.rawValue
            pantry.stir()
        }
    }

    private func fetchFirstProfileID() -> String? {
        let profiles: [ChefProfile] = pantry.fetchAll(
            entity: "ChefProfile",
            sortKey: "memberSince",
            ascending: true
        )
        return profiles.first?.profileID
    }
}

// MARK: - XP & Leveling Helpers

extension KitchenCoordinator {

    /// XP required to reach a given level.
    /// Level 1 = 0 XP, Level 2 = 100, Level 3 = 250, etc. (quadratic growth)
    static func xpThreshold(forLevel level: Int) -> Int {
        guard level > 1 else { return 0 }
        let n = level - 1
        return 50 * n + 25 * n * n
    }

    /// The level for a given XP total.
    static func levelForXP(_ xp: Int) -> Int {
        var lvl = 1
        while xpThreshold(forLevel: lvl + 1) <= xp {
            lvl += 1
        }
        return lvl
    }

    /// XP remaining to next level.
    static func xpToNextLevel(currentXP: Int) -> Int {
        let currentLevel = levelForXP(currentXP)
        let nextThreshold = xpThreshold(forLevel: currentLevel + 1)
        return max(0, nextThreshold - currentXP)
    }

    /// Progress fraction [0…1] within current level.
    static func levelProgress(currentXP: Int) -> Double {
        let lvl = levelForXP(currentXP)
        let base = xpThreshold(forLevel: lvl)
        let next = xpThreshold(forLevel: lvl + 1)
        let range = next - base
        guard range > 0 else { return 1.0 }
        return Double(currentXP - base) / Double(range)
    }

    /// Chef rank title based on level.
    static func chefRankTitle(level: Int) -> String {
        switch level {
        case 1:       return "Apprentice"
        case 2...4:   return "Line Cook"
        case 5...9:   return "Sous Chef"
        case 10...14: return "Head Chef"
        case 15...19: return "Executive Chef"
        case 20...29: return "Master Chef"
        default:      return "Legendary Chef"
        }
    }
}

// MARK: - Kitchen Gateway (Root View Router)

/// Decides which phase view to show based on coordinator state.
struct KitchenGateway: View {

    @EnvironmentObject private var coordinator: KitchenCoordinator

    var body: some View {
        ZStack {
            SpicePalette.burntCrustFallback
                .ignoresSafeArea()

            switch coordinator.phase {
            case .preheating:
                SplashBurnerView()
                    .transition(.opacity)

            case .remoteOfferGate:
                KitchenPostSplashRouter()
                    .transition(.opacity)

            case .tastingMenu:
                TastingMenuView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .opacity
                    ))

            case .cooking:
                MainKitchenTabView()
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.5), value: coordinator.phase)
        .alert(L10n.string("common.error", fallback: "Error"), isPresented: Binding(
            get: { coordinator.saveErrorMessage != nil },
            set: { if !$0 { coordinator.saveErrorMessage = nil } }
        )) {
            Button(L10n.string("common.done", fallback: "Done")) {
                coordinator.saveErrorMessage = nil
            }
        } message: {
            if let msg = coordinator.saveErrorMessage {
                Text(msg)
            }
        }
    }
}

// MARK: - Main Tab View

struct MainKitchenTabView: View {

    @EnvironmentObject private var coordinator: KitchenCoordinator
    @Environment(\.accentFlavor) private var flavor

    var body: some View {
        TabView(selection: $coordinator.activeTab) {
            ForEach(KitchenTab.allCases) { tab in
                tabContent(for: tab)
                    .tabItem {
                        Label(
                            L10n.string(tab.labelKey, fallback: tabLabelFallback(tab)),
                            systemImage: tab.iconName
                        )
                        .accessibilityLabel(L10n.string(tab.accessibilityKey, fallback: tabA11yFallback(tab)))
                    }
                    .tag(tab)
            }
        }
        .tint(flavor.primaryTint)
        .onAppear {
            configureTabBarAppearance()
            KitchenIgnitionDelegate.shared?.requestPushPermissionFromUserContextIfNeeded()
        }
    }

    @ViewBuilder
    private func tabContent(for tab: KitchenTab) -> some View {
        switch tab {
        case .kitchen:
            KitchenDashboardView()
        case .basket:
            MarketBasketView()
        case .lab:
            FlavorLabView()
        case .spiceRack:
            SpiceRackView()
        }
    }

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(SpicePalette.smokedPaprikaFallback)

        let normalColor = UIColor(SpicePalette.peppercornFallback)
        let selectedColor = UIColor(flavor.primaryTint)

        appearance.stackedLayoutAppearance.normal.iconColor = normalColor
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: normalColor]
        appearance.stackedLayoutAppearance.selected.iconColor = selectedColor
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: selectedColor]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    private func tabLabelFallback(_ tab: KitchenTab) -> String {
        switch tab {
        case .kitchen: return "Kitchen"
        case .basket: return "Basket"
        case .lab: return "Lab"
        case .spiceRack: return "Settings"
        }
    }

    private func tabA11yFallback(_ tab: KitchenTab) -> String {
        switch tab {
        case .kitchen: return "Dashboard tab"
        case .basket: return "Market basket tab"
        case .lab: return "Recipe lab tab"
        case .spiceRack: return "Settings tab"
        }
    }
}

