// FlavorFeedback.swift
// PriceKitchen
//
// Haptic & sensory feedback engine.
// Every interaction in the kitchen should *feel* satisfying.

import SwiftUI
import UIKit
import AudioToolbox

// MARK: - Flavor Feedback

/// Centralized haptic / sound feedback manager.
/// Call static methods anywhere in the app for consistent tactile response.
enum FlavorFeedback {

    // MARK: – Haptic Generators (lazy singletons)

    private static let lightTap    = UIImpactFeedbackGenerator(style: .light)
    private static let mediumTap   = UIImpactFeedbackGenerator(style: .medium)
    private static let heavyTap    = UIImpactFeedbackGenerator(style: .heavy)
    private static let softTap     = UIImpactFeedbackGenerator(style: .soft)
    private static let rigidTap    = UIImpactFeedbackGenerator(style: .rigid)
    private static let selection   = UISelectionFeedbackGenerator()
    private static let notification = UINotificationFeedbackGenerator()

    // MARK: – Kitchen Actions

    /// Light tap — like tapping a spoon on a bowl rim.
    /// Use for: toggling switches, selecting items, minor UI taps.
    static func spoonTap() {
        lightTap.prepare()
        lightTap.impactOccurred()
    }

    /// Medium tap — like closing an oven door.
    /// Use for: confirming actions, saving entries, tab switches.
    static func ovenDoorShut() {
        mediumTap.prepare()
        mediumTap.impactOccurred()
    }

    /// Heavy tap — like slamming a cleaver on the board.
    /// Use for: deleting items, resetting data, critical actions.
    static func cleaverChop() {
        heavyTap.prepare()
        heavyTap.impactOccurred()
    }

    /// Soft tap — like dusting flour onto dough.
    /// Use for: scrolling detents, subtle state changes.
    static func flourDust() {
        softTap.prepare()
        softTap.impactOccurred()
    }

    /// Rigid tap — like cracking an egg.
    /// Use for: expanding / collapsing cards, snapping to position.
    static func eggCrack() {
        rigidTap.prepare()
        rigidTap.impactOccurred()
    }

    /// Selection change — like turning a pepper grinder one click.
    /// Use for: picker scrolls, segment changes.
    static func pepperGrind() {
        selection.prepare()
        selection.selectionChanged()
    }

    // MARK: – Notification Haptics

    /// Success — like a perfect golden crust.
    /// Use for: price entry saved, achievement unlocked.
    static func goldenCrust() {
        notification.prepare()
        notification.notificationOccurred(.success)
    }

    /// Warning — like a timer beeping.
    /// Use for: approaching budget, unusual price spike.
    static func timerBeep() {
        notification.prepare()
        notification.notificationOccurred(.warning)
    }

    /// Error — like burning the soufflé.
    /// Use for: validation errors, failed actions.
    static func burntSouffle() {
        notification.prepare()
        notification.notificationOccurred(.error)
    }

    // MARK: – Compound Patterns

    /// Multi-tap celebration — like champagne bubbles.
    /// Use for: leveling up, unlocking a trophy.
    static func champagneBubbles() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()

        for i in 0..<5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.08) {
                generator.impactOccurred(intensity: CGFloat.random(in: 0.4...1.0))
            }
        }
    }

    /// Rising intensity — like kneading dough harder.
    /// Use for: long-press progress, charging up an action.
    static func kneadDough(progress: CGFloat) {
        let clamped = min(max(progress, 0), 1)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred(intensity: clamped)
    }

    /// Double tap — like clinking glasses.
    /// Use for: sharing data, social actions.
    static func clinkGlasses() {
        let gen = UIImpactFeedbackGenerator(style: .rigid)
        gen.prepare()
        gen.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            gen.impactOccurred(intensity: 0.7)
        }
    }

    /// System keyboard sound (subtle).
    static func keyClick() {
        AudioServicesPlaySystemSound(1104)
    }
}

// MARK: - View Modifier for Tap Feedback

/// Attach to any view to get haptic + scale animation on tap.
///
/// Usage:
/// ```
/// Button("Save") { ... }
///     .flavorTap(.ovenDoorShut)
/// ```
struct FlavorTapModifier: ViewModifier {
    let feedbackType: FlavorFeedbackType
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isPressed else { return }
                        isPressed = true
                        feedbackType.trigger()
                    }
                    .onEnded { _ in
                        isPressed = false
                    }
            )
    }
}


extension View {

    /// Adds haptic feedback + subtle press animation on tap.
    func flavorTap(_ type: FlavorFeedbackType = .spoonTap) -> some View {
        modifier(FlavorTapModifier(feedbackType: type))
    }
}

// MARK: - Confetti Burst Overlay

/// Full-screen confetti for celebrations (level-up, achievement).
/// Usage: `.overlay(ConfettiBurstCanvas(isActive: $showConfetti))`
struct ConfettiBurstCanvas: View {
    @Binding var isActive: Bool
    @State private var particles: [ConfettiMorsel] = []

    var body: some View {
        ZStack {
            ForEach(particles) { morsel in
                Text(morsel.emoji)
                    .font(.system(size: morsel.size))
                    .offset(x: morsel.x, y: morsel.y)
                    .opacity(morsel.opacity)
                    .rotationEffect(.degrees(morsel.rotation))
            }
        }
        .allowsHitTesting(false)
        .onChange(of: isActive) { newValue in
            if newValue { launchBurst() }
        }
    }

    private func launchBurst() {
        FlavorFeedback.champagneBubbles()

        let emojis = ["🌟", "🏆", "🍳", "🔥", "💰", "✨", "🧂", "🌿"]
        particles = (0..<30).map { i in
            ConfettiMorsel(
                id: i,
                emoji: emojis.randomElement()!,
                size: CGFloat.random(in: 14...28),
                x: CGFloat.random(in: -160...160),
                y: -UIScreen.main.bounds.height / 2,
                rotation: Double.random(in: 0...360),
                opacity: 1.0
            )
        }

        withAnimation(.easeOut(duration: 2.0)) {
            particles = particles.map { p in
                var m = p
                m.y = UIScreen.main.bounds.height / 2 + 100
                m.x += CGFloat.random(in: -80...80)
                m.rotation += Double.random(in: -180...180)
                m.opacity = 0
                return m
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            isActive = false
            particles = []
        }
    }
}

struct ConfettiMorsel: Identifiable {
    let id: Int
    let emoji: String
    let size: CGFloat
    var x: CGFloat
    var y: CGFloat
    var rotation: Double
    var opacity: Double
}
