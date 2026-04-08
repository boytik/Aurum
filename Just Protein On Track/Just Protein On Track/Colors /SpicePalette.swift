// SpicePalette.swift
// PriceKitchen
//
// Culinary-themed color palette for the app.
// Dark base with vibrant gold & green accents.

import SwiftUI
import UIKit

// MARK: - Spice Palette

enum SpicePalette {

    // MARK: – Backgrounds (dark tones)

    /// Main background — deep charcoal like burnt toast
    static let burntCrust = Color("BurntCrust")

    /// Card / surface background — slightly lighter
    static let smokedPaprika = Color("SmokedPaprika")

    /// Elevated surface — modals, sheets
    static let midnightCocoa = Color("MidnightCocoa")

    // MARK: – Primary Accents (gold family)

    /// Bright saffron gold — primary accent
    static let saffronGold = Color("SaffronGold")

    /// Muted honey — secondary gold tone
    static let honeyGlaze = Color("HoneyGlaze")

    /// Warm turmeric — tertiary warm accent
    static let turmericDust = Color("TurmericDust")

    // MARK: – Secondary Accents (green family)

    /// Vivid basil green — success / positive change
    static let basilLeaf = Color("BasilLeaf")

    /// Muted sage — secondary green
    static let sageMist = Color("SageMist")

    /// Dark olive — subtle green background tint
    static let oliveBrine = Color("OliveBrine")

    // MARK: – Semantic Colors

    /// Error / negative change — chili red
    static let chiliFlake = Color("ChiliFlake")

    /// Warning / caution — papaya orange
    static let papayaPulp = Color("PapayaPulp")

    /// Neutral / inactive — peppercorn gray
    static let peppercorn = Color("Peppercorn")

    // MARK: – Text

    /// Primary text — vanilla cream on dark
    static let vanillaCream = Color("VanillaCream")

    /// Secondary text — lighter gray
    static let flourDust = Color("FlourDust")

    /// Disabled / placeholder text
    static let steamWhisper = Color("SteamWhisper")
}

// MARK: - Programmatic Fallbacks

/// Use these when Color assets are not yet added to the asset catalog.
/// Once you add the named colors to Assets.xcassets, the palette above
/// will pick them up automatically. Until then, this extension provides
/// hard-coded fallback values so the app compiles and runs.

extension SpicePalette {

    // MARK: Backgrounds
    static let burntCrustFallback       = Color(red: 0.08, green: 0.08, blue: 0.10)
    static let smokedPaprikaFallback    = Color(red: 0.13, green: 0.13, blue: 0.16)
    static let midnightCocoaFallback    = Color(red: 0.18, green: 0.17, blue: 0.21)

    // MARK: Gold Family
    static let saffronGoldFallback      = Color(red: 1.00, green: 0.80, blue: 0.20)
    static let honeyGlazeFallback       = Color(red: 0.90, green: 0.72, blue: 0.30)
    static let turmericDustFallback     = Color(red: 0.85, green: 0.65, blue: 0.15)

    // MARK: Green Family
    static let basilLeafFallback        = Color(red: 0.18, green: 0.80, blue: 0.44)
    static let sageMistFallback         = Color(red: 0.40, green: 0.68, blue: 0.52)
    static let oliveBrineFallback       = Color(red: 0.22, green: 0.35, blue: 0.25)

    // MARK: Semantic
    static let chiliFlakeFallback       = Color(red: 0.92, green: 0.26, blue: 0.22)
    static let papayaPulpFallback       = Color(red: 1.00, green: 0.62, blue: 0.18)
    static let peppercornFallback       = Color(red: 0.45, green: 0.45, blue: 0.48)

    // MARK: Text
    static let vanillaCreamFallback     = Color(red: 0.96, green: 0.94, blue: 0.90)
    static let flourDustFallback        = Color(red: 0.70, green: 0.68, blue: 0.65)
    static let steamWhisperFallback     = Color(red: 0.50, green: 0.48, blue: 0.46)

    /// Remote WebView: toolbar, safe-area bands, chrome — **#2D221E** (sRGB).
    static let remoteRecipeBrowserChromeFallback = Color(
        .sRGB,
        red: Double(0x2D) / 255,
        green: Double(0x22) / 255,
        blue: Double(0x1E) / 255,
        opacity: 1
    )
}

extension UIColor {
    /// Same as `SpicePalette.remoteRecipeBrowserChromeFallback` — **#2D221E** (WKWebView background / scroll view).
    static var kitchenRemoteWebChrome: UIColor {
        UIColor(
            red: CGFloat(0x2D) / 255,
            green: CGFloat(0x22) / 255,
            blue: CGFloat(0x1E) / 255,
            alpha: 1
        )
    }
}

// MARK: - Accent Flavor (User-selectable accent sets)

/// Users can pick an «accent flavor» in SpiceRack (Settings).
/// Each flavor defines a primary and secondary accent color.
enum AccentFlavor: String, CaseIterable, Identifiable {
    case saffron   // gold + green  (default)
    case matcha    // green + gold
    case chili     // red + gold
    case lavender  // purple + gold

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .saffron:  return String(localized: "accent.saffron",  defaultValue: "Saffron Gold")
        case .matcha:   return String(localized: "accent.matcha",   defaultValue: "Matcha Zen")
        case .chili:    return String(localized: "accent.chili",    defaultValue: "Chili Ember")
        case .lavender: return String(localized: "accent.lavender", defaultValue: "Lavender Frost")
        }
    }

    var primaryTint: Color {
        switch self {
        case .saffron:  return SpicePalette.saffronGoldFallback
        case .matcha:   return SpicePalette.basilLeafFallback
        case .chili:    return SpicePalette.chiliFlakeFallback
        case .lavender: return Color(red: 0.68, green: 0.52, blue: 0.88)
        }
    }

    var secondaryTint: Color {
        switch self {
        case .saffron:  return SpicePalette.basilLeafFallback
        case .matcha:   return SpicePalette.saffronGoldFallback
        case .chili:    return SpicePalette.honeyGlazeFallback
        case .lavender: return SpicePalette.saffronGoldFallback
        }
    }

    var emoji: String {
        switch self {
        case .saffron:  return "🌾"
        case .matcha:   return "🍵"
        case .chili:    return "🌶️"
        case .lavender: return "💜"
        }
    }
}

// MARK: - Environment Key for Accent Flavor

private struct AccentFlavorKey: EnvironmentKey {
    static let defaultValue: AccentFlavor = .saffron
}

extension EnvironmentValues {
    var accentFlavor: AccentFlavor {
        get { self[AccentFlavorKey.self] }
        set { self[AccentFlavorKey.self] = newValue }
    }
}
