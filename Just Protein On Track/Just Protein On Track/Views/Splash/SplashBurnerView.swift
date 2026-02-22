// SplashBurnerView.swift
// PriceKitchen
//
// Animated splash screen — "preheating the oven."
// Shows a pulsing flame, rotating loading texts, and floating spice particles.
// Auto-advances to the next phase after ~3 seconds.

import SwiftUI

// MARK: - Splash Burner View

struct SplashBurnerView: View {

    @EnvironmentObject private var coordinator: KitchenCoordinator
    @Environment(\.accentFlavor) private var flavor

    // MARK: – Animation State

    @State private var flameScale: CGFloat = 0.5
    @State private var flameOpacity: Double = 0.0
    @State private var flamePulse: CGFloat = 1.0
    @State private var ringRotation: Double = 0
    @State private var ringScale: CGFloat = 0.9
    @State private var titleOffset: CGFloat = 40
    @State private var titleOpacity: Double = 0
    @State private var titleScale: CGFloat = 0.9
    @State private var subtitleIndex: Int = 0
    @State private var subtitleOpacity: Double = 0
    @State private var particlesVisible = false
    @State private var progressValue: CGFloat = 0
    @State private var progressGlow: Bool = false

    private let subtitleKeys = ["splash.line1", "splash.line2", "splash.line3"]
    private let subtitleFallbacks = [
        "Warming up the stove…",
        "Seasoning the data…",
        "Preparing your kitchen…"
    ]

    // MARK: – Body

    var body: some View {
        ZStack {
            // Gradient background
            backgroundGradient
                .ignoresSafeArea()

            // Floating spice particles
            if particlesVisible {
                SpiceParticleField()
                    .transition(.opacity)
            }

            VStack(spacing: 32) {
                Spacer()

                // Animated flame emblem
                flameEmblem
                    .frame(width: 160, height: 160)

                // App title with animations
                VStack(spacing: 10) {
                    Text("Price Kitchen")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(SpicePalette.vanillaCreamFallback)
                        .offset(y: titleOffset)
                        .opacity(titleOpacity)
                        .scaleEffect(titleScale)
                        .shadow(color: flavor.primaryTint.opacity(0.2), radius: 8)

                    Text("🍳")
                        .font(.system(size: 24))
                        .opacity(titleOpacity)
                        .scaleEffect(titleScale)
                }

                Spacer()

                // Rotating subtitle with smooth transition
                Text(L10n.string(subtitleKeys[subtitleIndex], fallback: subtitleFallbacks[subtitleIndex]))
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(SpicePalette.flourDustFallback)
                    .opacity(subtitleOpacity)
                    .id(subtitleIndex)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
                    .animation(.easeInOut(duration: 0.45), value: subtitleIndex)

                // Enhanced progress bar
                progressBar
                    .padding(.horizontal, 48)
                    .padding(.bottom, 12)

                Spacer()
                    .frame(height: 50)
            }
        }
        .onAppear(perform: startPreheatingSequence)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading app")
    }

    // MARK: – Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                SpicePalette.burntCrustFallback,
                SpicePalette.smokedPaprikaFallback.opacity(0.5),
                SpicePalette.burntCrustFallback
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: – Flame Emblem

    private var flameEmblem: some View {
        ZStack {
            // Outer spinning ring with scale pulse
            Circle()
                .strokeBorder(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            flavor.primaryTint.opacity(0.9),
                            flavor.secondaryTint.opacity(0.5),
                            flavor.primaryTint.opacity(0.15),
                            flavor.primaryTint.opacity(0.9)
                        ]),
                        center: .center
                    ),
                    lineWidth: 4
                )
                .scaleEffect(ringScale)
                .rotationEffect(.degrees(ringRotation))

            // Inner glow (pulsing)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            flavor.primaryTint.opacity(0.35),
                            flavor.primaryTint.opacity(0.1),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 15,
                        endRadius: 70
                    )
                )
                .scaleEffect(flameScale * flamePulse)

            // Flame emoji
            Text("🔥")
                .font(.system(size: 60))
                .scaleEffect(flameScale * flamePulse)
                .opacity(flameOpacity)
        }
    }

    // MARK: – Progress Bar

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track
                Capsule()
                    .fill(SpicePalette.smokedPaprikaFallback.opacity(0.8))
                    .frame(height: 8)

                // Fill with gradient
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [flavor.primaryTint, flavor.secondaryTint],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * progressValue, height: 8)
                    .shadow(
                        color: progressGlow ? flavor.primaryTint.opacity(0.5) : .clear,
                        radius: 6
                    )
                    .animation(.easeInOut(duration: 0.35), value: progressValue)
            }
        }
        .frame(height: 8)
    }

    // MARK: – Animation Sequence

    private func startPreheatingSequence() {
        // Phase 1 (0.0s): Flame appears + ring spins
        withAnimation(.easeOut(duration: 0.9)) {
            flameScale = 1.0
            flameOpacity = 1.0
        }
        withAnimation(.easeOut(duration: 0.6)) {
            ringScale = 1.0
        }
        withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
            ringRotation = 360
        }
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            flamePulse = 1.08
        }

        // Phase 2 (0.35s): Title slides in with scale
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                titleOffset = 0
                titleOpacity = 1.0
                titleScale = 1.0
            }
        }

        // Phase 3 (0.65s): Particles appear
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
            withAnimation(.easeIn(duration: 0.6)) {
                particlesVisible = true
            }
        }

        // Phase 4 (0.9s): First subtitle + progress
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.easeInOut(duration: 0.4)) {
                subtitleOpacity = 1.0
                progressValue = 0.33
                progressGlow = true
            }
            FlavorFeedback.flourDust()
        }

        // Phase 5 (1.7s): Second subtitle
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) {
            withAnimation { subtitleIndex = 1 }
            progressValue = 0.66
            FlavorFeedback.flourDust()
        }

        // Phase 6 (2.5s): Third subtitle
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { subtitleIndex = 2 }
            progressValue = 1.0
            FlavorFeedback.flourDust()
        }

        // Phase 7 (3.2s): Transition out
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            coordinator.splashDidFinish()
        }
    }
}

// MARK: - Spice Particle Field

struct SpiceParticleField: View {

    @State private var morsels: [SteamMorsel] = []
    @State private var phase: Double = 0

    private let steamEmojis = ["✨", "🌿", "🧂", "💨", "🌾", "⭐", "🍃", "🌙"]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(morsels) { morsel in
                    Text(morsel.emoji)
                        .font(.system(size: morsel.size))
                        .position(x: morsel.x, y: morsel.y)
                        .opacity(morsel.opacity)
                }
            }
            .onAppear {
                generateMorsels(in: geo.size)
                animateMorsels(in: geo.size)
            }
        }
        .allowsHitTesting(false)
    }

    private func generateMorsels(in size: CGSize) {
        morsels = (0..<20).map { i in
            SteamMorsel(
                id: i,
                emoji: steamEmojis.randomElement()!,
                size: CGFloat.random(in: 12...24),
                x: CGFloat.random(in: 0...size.width),
                y: size.height + CGFloat.random(in: 30...100),
                opacity: Double.random(in: 0.2...0.6)
            )
        }
    }

    private func animateMorsels(in size: CGSize) {
        for i in morsels.indices {
            let delay = Double.random(in: 0...2.0)
            let duration = Double.random(in: 3.5...7)
            let drift = CGFloat.random(in: -50...50)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: false)) {
                    morsels[i].y = -50
                    morsels[i].x += drift
                    morsels[i].opacity = 0
                }
            }
        }
    }
}

struct SteamMorsel: Identifiable {
    let id: Int
    let emoji: String
    let size: CGFloat
    var x: CGFloat
    var y: CGFloat
    var opacity: Double
}
