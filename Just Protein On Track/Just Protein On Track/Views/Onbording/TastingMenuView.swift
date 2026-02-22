// TastingMenuView.swift
// PriceKitchen
//
// Onboarding flow — the "Tasting Menu" before the real cooking begins.
// 4 animated pages explaining the app, with a final CTA to start.

import SwiftUI

// MARK: - Tasting Menu View (Onboarding)

struct TastingMenuView: View {

    @EnvironmentObject private var coordinator: KitchenCoordinator
    @Environment(\.accentFlavor) private var flavor

    @State private var currentCourse: Int = 0
    @State private var appeared = false
    @State private var buttonPulse = false

    private let courses = TastingCourse.allCourses

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Base background (dark, doesn't fill edges)
                SpicePalette.burntCrustFallback
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Page content with contained background
                    TabView(selection: $currentCourse) {
                        ForEach(Array(courses.enumerated()), id: \.offset) { index, course in
                            ZStack(alignment: .topTrailing) {
                                TastingCoursePage(
                                    course: course,
                                    isActive: currentCourse == index,
                                    flavor: flavor
                                )
                                // Skip button inside content area
                                skipButton
                                    .padding(.top, 12)
                                    .padding(.trailing, 20)
                            }
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentCourse)

                    // Bottom controls
                    bottomControls
                        .padding(.horizontal, 32)
                        .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { appeared = true }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(0.5)) {
                buttonPulse = true
            }
        }
        .onChange(of: currentCourse) { _ in
            FlavorFeedback.pepperGrind()
        }
    }

    // MARK: – Skip Button (inside content, white)

    private var skipButton: some View {
        Button {
            FlavorFeedback.spoonTap()
            coordinator.onboardingDidFinish()
        } label: {
            Text(L10n.string("common.skip", fallback: "Skip"))
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .opacity(currentCourse < courses.count - 1 ? 1 : 0)
        .animation(.easeInOut, value: currentCourse)
    }

    // MARK: – Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 20) {
            // Tappable page dots — functional navigation
            courseDots

            // Action button
            if currentCourse < courses.count - 1 {
                nextButton
            } else {
                startCookingButton
            }
        }
    }

    // MARK: – Course Dots (tappable for direct navigation)

    private var courseDots: some View {
        HStack(spacing: 10) {
            ForEach(0..<courses.count, id: \.self) { index in
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        currentCourse = index
                    }
                    FlavorFeedback.spoonTap()
                } label: {
                    Capsule()
                        .fill(index == currentCourse ? flavor.primaryTint : SpicePalette.peppercornFallback)
                        .frame(
                            width: index == currentCourse ? 28 : 8,
                            height: 8
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Page \(index + 1) of \(courses.count)")
                .accessibilityAddTraits(index == currentCourse ? [.isSelected] : [])
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: currentCourse)
    }

    // MARK: – Next Button

    private var nextButton: some View {
        Button {
            FlavorFeedback.ovenDoorShut()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                currentCourse = min(currentCourse + 1, courses.count - 1)
            }
        } label: {
            HStack(spacing: 8) {
                Text(L10n.string("common.next", fallback: "Next"))
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                Image(systemName: "arrow.right")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(SpicePalette.burntCrustFallback)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(flavor.primaryTint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .flavorTap(.ovenDoorShut)
    }

    // MARK: – Start Cooking Button

    private var startCookingButton: some View {
        Button {
            FlavorFeedback.champagneBubbles()
            coordinator.onboardingDidFinish()
        } label: {
            HStack(spacing: 8) {
                Text("🍳")
                    .font(.system(size: 20))
                    .scaleEffect(buttonPulse ? 1.1 : 1.0)
                Text(L10n.string("onboard.getStarted", fallback: "Get Started"))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
            }
            .foregroundColor(SpicePalette.burntCrustFallback)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                LinearGradient(
                    colors: [flavor.primaryTint, flavor.secondaryTint],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .shadow(color: flavor.primaryTint.opacity(0.4), radius: buttonPulse ? 16 : 12, y: 4)
        }
        .buttonStyle(ScaleButtonStyle())
        .flavorTap(.champagneBubbles)
        .scaleEffect(appeared ? 1.0 : 0.8)
        .animation(
            .spring(response: 0.5, dampingFraction: 0.6).delay(0.2),
            value: appeared
        )
    }
}

// MARK: - Scale Button Style (press animation)

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Tasting Course Data

struct TastingCourse {
    let emoji: String
    let titleKey: String
    let bodyKey: String
    let titleFallback: String
    let bodyFallback: String
    let decorEmojis: [String]
    let gradientColors: [Color]

    static let allCourses: [TastingCourse] = [
        TastingCourse(
            emoji: "📊",
            titleKey: "onboard.page1.title",
            bodyKey: "onboard.page1.body",
            titleFallback: "Your Personal Price Tracker",
            bodyFallback: "Stop guessing how much things cost. Log prices once and see how your grocery spending changes over time.",
            decorEmojis: ["💰", "📈", "🏷️", "🛒"],
            gradientColors: [
                SpicePalette.saffronGoldFallback.opacity(0.3),
                SpicePalette.burntCrustFallback
            ]
        ),
        TastingCourse(
            emoji: "🧺",
            titleKey: "onboard.page2.title",
            bodyKey: "onboard.page2.body",
            titleFallback: "Add Products in Seconds",
            bodyFallback: "Create your list of regular purchases. Each time you shop, tap and record the price — no spreadsheets needed.",
            decorEmojis: ["🥛", "🍞", "🥩", "🍎"],
            gradientColors: [
                SpicePalette.basilLeafFallback.opacity(0.25),
                SpicePalette.burntCrustFallback
            ]
        ),
        TastingCourse(
            emoji: "🍲",
            titleKey: "onboard.page3.title",
            bodyKey: "onboard.page3.body",
            titleFallback: "Recipes & Real Costs",
            bodyFallback: "Build recipes from your products and see exactly what a dish costs. Compare stores to find the best deals.",
            decorEmojis: ["📈", "📉", "🧪", "⚖️"],
            gradientColors: [
                SpicePalette.chiliFlakeFallback.opacity(0.25),
                SpicePalette.burntCrustFallback
            ]
        ),
        TastingCourse(
            emoji: "🏆",
            titleKey: "onboard.page4.title",
            bodyKey: "onboard.page4.body",
            titleFallback: "Earn Rewards as You Track",
            bodyFallback: "Unlock trophies and level up for every price you log. Turn boring receipts into a satisfying habit.",
            decorEmojis: ["⭐", "🎖️", "🎯", "🚀"],
            gradientColors: [
                Color(red: 0.68, green: 0.52, blue: 0.88).opacity(0.25),
                SpicePalette.burntCrustFallback
            ]
        )
    ]
}

// MARK: - Single Course Page

struct TastingCoursePage: View {

    let course: TastingCourse
    let isActive: Bool
    let flavor: AccentFlavor

    @State private var emojiScale: CGFloat = 0.3
    @State private var emojiBounce: CGFloat = 1.0
    @State private var textOpacity: Double = 0
    @State private var textOffset: CGFloat = 25
    @State private var orbitsAngle: Double = 0
    @State private var decorVisible = false
    @State private var decorScale: CGFloat = 0.2
    @State private var glowPulse: Double = 0.2

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Contained gradient background (not full screen — with padding)
                LinearGradient(
                    colors: course.gradientColors,
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .cornerRadius(24)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                VStack(spacing: 24) {
                    Spacer()

                    // Hero illustration with animations
                    heroOrbit
                        .frame(width: 220, height: 220)

                    // Title with staggered animation
                    Text(L10n.string(course.titleKey, fallback: course.titleFallback))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(SpicePalette.vanillaCreamFallback)
                        .multilineTextAlignment(.center)
                        .opacity(textOpacity)
                        .offset(y: textOffset)

                    // Body text
                    Text(L10n.string(course.bodyKey, fallback: course.bodyFallback))
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundColor(SpicePalette.flourDustFallback)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 32)
                        .opacity(textOpacity)
                        .offset(y: textOffset * 0.6)

                    Spacer()
                    Spacer()
                }
            }
        }
        .onChange(of: isActive) { active in
            if active { animateIn() } else { resetState() }
        }
        .onAppear {
            if isActive { animateIn() }
        }
    }

    // MARK: – Hero Orbit (Central emoji with orbiting decor)

    private var heroOrbit: some View {
        ZStack {
            // Pulsing glow background
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            flavor.primaryTint.opacity(glowPulse),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 110
                    )
                )
                .scaleEffect(emojiScale)

            // Orbiting decor emojis with bounce
            ForEach(Array(course.decorEmojis.enumerated()), id: \.offset) { index, emoji in
                let angle = (Double(index) / Double(course.decorEmojis.count)) * 360 + orbitsAngle
                let radius: CGFloat = 80

                Text(emoji)
                    .font(.system(size: 24))
                    .scaleEffect(decorScale)
                    .offset(
                        x: cos(angle * .pi / 180) * radius,
                        y: sin(angle * .pi / 180) * radius
                    )
                    .opacity(decorVisible ? 0.9 : 0)
            }

            // Central emoji with bounce animation
            Text(course.emoji)
                .font(.system(size: 72))
                .scaleEffect(emojiScale * emojiBounce)
                .shadow(color: flavor.primaryTint.opacity(0.4), radius: 15)
        }
    }

    // MARK: – Animation

    private func animateIn() {
        emojiScale = 0.3
        emojiBounce = 1.0
        textOpacity = 0
        textOffset = 25
        decorVisible = false
        decorScale = 0.2
        glowPulse = 0.2

        // Emoji scale-in with spring
        withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
            emojiScale = 1.0
        }

        // Bounce effect on emoji
        withAnimation(.spring(response: 0.5, dampingFraction: 0.5).delay(0.3)) {
            emojiBounce = 1.15
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.5)) {
            emojiBounce = 1.0
        }

        // Glow pulse
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true).delay(0.4)) {
            glowPulse = 0.35
        }

        // Decor emojis — scale & fade with stagger
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.2)) {
            decorVisible = true
            decorScale = 1.0
        }

        // Text fade-in with slide
        withAnimation(.easeOut(duration: 0.5).delay(0.35)) {
            textOpacity = 1.0
            textOffset = 0
        }

        // Continuous orbit
        withAnimation(.linear(duration: 25).repeatForever(autoreverses: false)) {
            orbitsAngle = 360
        }
    }

    private func resetState() {
        emojiScale = 0.3
        emojiBounce = 1.0
        textOpacity = 0
        textOffset = 25
        decorVisible = false
        decorScale = 0.2
        glowPulse = 0.2
        orbitsAngle = 0
    }
}

// MARK: - Preview

#if DEBUG
struct TastingMenuView_Previews: PreviewProvider {
    static var previews: some View {
        TastingMenuView()
            .environmentObject(KitchenCoordinator())
            .environment(\.accentFlavor, .saffron)
            .preferredColorScheme(.dark)
    }
}
#endif
