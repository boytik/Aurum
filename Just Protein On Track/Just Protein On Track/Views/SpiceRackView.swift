// SpiceRackView.swift
// PriceKitchen
//
// The "Spice Rack" tab — settings & personalization.
// Chef profile, avatar picker, accent flavors, stats, trophies, export, reset.

import SwiftUI

// MARK: - Spice Rack View

struct SpiceRackView: View {

    @EnvironmentObject private var coordinator: KitchenCoordinator
    @Environment(\.accentFlavor) private var flavor
    @StateObject private var rack = SpiceRackViewModel()

    @State private var sectionsAppeared = false

    var body: some View {
        NavigationView {
            ZStack {
                SpicePalette.burntCrustFallback
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        headerBar
                        profileCard
                        accentFlavorCard
                        statsCard
                        trophyCaseButton
                        exportButton
                        dangerZone
                        versionFooter
                        Spacer(minLength: 30)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                rack.openSpiceJars()
                withAnimation(.easeOut(duration: 0.5).delay(0.15)) {
                    sectionsAppeared = true
                }
            }
            .sheet(isPresented: $rack.showAvatarPicker) {
                AvatarKitchenPicker(rack: rack, flavor: flavor)
            }
            .sheet(isPresented: $rack.showTrophyCase) {
                TrophyCaseSheet(trophies: rack.trophies, flavor: flavor)
            }
            .sheet(isPresented: $rack.showExportSheet) {
                if let url = rack.exportCSVURL {
                    ActivityShareSheet(items: [url])
                }
            }
            .alert(
                L10n.string("spice.resetAll"),
                isPresented: $rack.showResetConfirm
            ) {
                Button(L10n.string("common.cancel"), role: .cancel) { }
                Button(L10n.string("common.delete"), role: .destructive) {
                    rack.resetKitchen()
                }
            } message: {
                Text(L10n.string("spice.resetAll.confirm"))
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: – Header

    private var headerBar: some View {
        HStack {
            Text(L10n.string("spice.title"))
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(SpicePalette.vanillaCreamFallback)
            Spacer()
            Text("🧂")
                .font(.system(size: 28))
        }
        .padding(.top, 12)
    }

    // MARK: – Profile Card

    private var profileCard: some View {
        VStack(spacing: 16) {
            // Section label
            SectionSpiceLabel(text: L10n.string("spice.profile"))

            // Avatar + name row
            HStack(spacing: 16) {
                // Avatar button
                Button {
                    FlavorFeedback.eggCrack()
                    rack.showAvatarPicker = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(flavor.primaryTint.opacity(0.15))
                            .frame(width: 68, height: 68)

                        Text(rack.avatarEmoji)
                            .font(.system(size: 38))

                        // Edit badge
                        Circle()
                            .fill(flavor.primaryTint)
                            .frame(width: 22, height: 22)
                            .overlay(
                                Image(systemName: "pencil")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(SpicePalette.burntCrustFallback)
                            )
                            .offset(x: 24, y: 24)
                    }
                }
                .flavorTap(.eggCrack)

                // Name field
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.string("spice.name"))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(SpicePalette.flourDustFallback)

                    TextField("Chef", text: $rack.chefName, onCommit: {
                        rack.saveChefName()
                    })
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(SpicePalette.vanillaCreamFallback)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(SpicePalette.burntCrustFallback)
                    )
                    .submitLabel(.done)
                }
            }

            // Level badge
            HStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .font(.system(size: 13))
                    .foregroundColor(flavor.primaryTint)

                Text(String(format: L10n.string("common.level"), rack.currentLevel))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(flavor.primaryTint)

                Text("·")
                    .foregroundColor(SpicePalette.peppercornFallback)

                Text(KitchenCoordinator.chefRankTitle(level: rack.currentLevel))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(SpicePalette.flourDustFallback)

                Spacer()

                Text("\(rack.totalXP) \(L10n.string("common.xp"))")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(SpicePalette.peppercornFallback)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(SpicePalette.smokedPaprikaFallback)
        )
        .opacity(sectionsAppeared ? 1 : 0)
        .offset(y: sectionsAppeared ? 0 : 20)
        .animation(.easeOut(duration: 0.5).delay(0.05), value: sectionsAppeared)
    }

    // MARK: – Accent Flavor Card

    private var accentFlavorCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionSpiceLabel(text: L10n.string("spice.accent"))

            HStack(spacing: 10) {
                ForEach(AccentFlavor.allCases) { flav in
                    Button {
                        rack.selectAccentFlavor(flav, coordinator: coordinator)
                    } label: {
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(flav.primaryTint)
                                    .frame(width: 44, height: 44)

                                Text(flav.emoji)
                                    .font(.system(size: 20))

                                if rack.accentFlavor == flav {
                                    Circle()
                                        .strokeBorder(SpicePalette.vanillaCreamFallback, lineWidth: 3)
                                        .frame(width: 50, height: 50)
                                }
                            }

                            Text(flav.displayName)
                                .font(.system(size: 11, weight: rack.accentFlavor == flav ? .bold : .medium, design: .rounded))
                                .foregroundColor(rack.accentFlavor == flav
                                                 ? SpicePalette.vanillaCreamFallback
                                                 : SpicePalette.flourDustFallback)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .flavorTap(.spoonTap)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(SpicePalette.smokedPaprikaFallback)
        )
        .opacity(sectionsAppeared ? 1 : 0)
        .offset(y: sectionsAppeared ? 0 : 20)
        .animation(.easeOut(duration: 0.5).delay(0.1), value: sectionsAppeared)
    }

    // MARK: – Stats Card

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionSpiceLabel(text: L10n.string("spice.stats"))

            ForEach(rack.statRows) { row in
                HStack(spacing: 12) {
                    Text(row.emoji)
                        .font(.system(size: 22))
                        .frame(width: 32)

                    Text(L10n.string(row.labelKey))
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(SpicePalette.vanillaCreamFallback)

                    Spacer()

                    Text(row.value)
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundColor(flavor.primaryTint)
                }
                .padding(.vertical, 4)

                if row.id != rack.statRows.last?.id {
                    Divider()
                        .background(SpicePalette.peppercornFallback.opacity(0.3))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(SpicePalette.smokedPaprikaFallback)
        )
        .opacity(sectionsAppeared ? 1 : 0)
        .offset(y: sectionsAppeared ? 0 : 20)
        .animation(.easeOut(duration: 0.5).delay(0.15), value: sectionsAppeared)
    }

    // MARK: – Trophy Case Button

    private var trophyCaseButton: some View {
        Button {
            FlavorFeedback.ovenDoorShut()
            rack.showTrophyCase = true
        } label: {
            HStack(spacing: 12) {
                Text("🏆")
                    .font(.system(size: 26))

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.string("spice.trophies"))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(SpicePalette.vanillaCreamFallback)

                    Text(rack.trophies.isEmpty
                         ? L10n.string("spice.trophies.empty")
                         : L10n.string("spice.trophies.unlocked", fallback: "%d unlocked", rack.trophies.count))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(SpicePalette.flourDustFallback)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(SpicePalette.peppercornFallback)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(SpicePalette.smokedPaprikaFallback)
            )
        }
        .flavorTap(.ovenDoorShut)
        .opacity(sectionsAppeared ? 1 : 0)
        .offset(y: sectionsAppeared ? 0 : 20)
        .animation(.easeOut(duration: 0.5).delay(0.2), value: sectionsAppeared)
    }

    // MARK: – Export Button

    private var exportButton: some View {
        Button {
            rack.buildCSVExport()
        } label: {
            HStack(spacing: 12) {
                Text("📤")
                    .font(.system(size: 26))

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.string("spice.export"))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(SpicePalette.vanillaCreamFallback)

                    Text(L10n.string("spice.export.desc"))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(SpicePalette.flourDustFallback)
                }

                Spacer()

                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(flavor.primaryTint)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(SpicePalette.smokedPaprikaFallback)
            )
        }
        .flavorTap(.clinkGlasses)
        .opacity(sectionsAppeared ? 1 : 0)
        .offset(y: sectionsAppeared ? 0 : 20)
        .animation(.easeOut(duration: 0.5).delay(0.25), value: sectionsAppeared)
    }

    // MARK: – Danger Zone

    private var dangerZone: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionSpiceLabel(text: L10n.string("spice.danger"))

            Button {
                FlavorFeedback.timerBeep()
                rack.showResetConfirm = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 16))
                    Text(L10n.string("spice.resetAll"))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }
                .foregroundColor(SpicePalette.chiliFlakeFallback)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(SpicePalette.chiliFlakeFallback.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(SpicePalette.chiliFlakeFallback.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .flavorTap(.cleaverChop)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(SpicePalette.smokedPaprikaFallback)
        )
        .opacity(sectionsAppeared ? 1 : 0)
        .offset(y: sectionsAppeared ? 0 : 20)
        .animation(.easeOut(duration: 0.5).delay(0.3), value: sectionsAppeared)
    }

    // MARK: – Version Footer

    private var versionFooter: some View {
        Text(String(format: L10n.string("spice.version"), rack.appVersion))
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundColor(SpicePalette.peppercornFallback)
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
    }
}

// MARK: - Section Label

struct SectionSpiceLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundColor(SpicePalette.flourDustFallback)
            .textCase(.uppercase)
            .tracking(1.2)
    }
}

// MARK: - Avatar Kitchen Picker

struct AvatarKitchenPicker: View {

    @ObservedObject var rack: SpiceRackViewModel
    let flavor: AccentFlavor
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.adaptive(minimum: 56), spacing: 12)
    ]

    var body: some View {
        NavigationView {
            ZStack {
                SpicePalette.burntCrustFallback
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    // Current selection preview
                    ZStack {
                        Circle()
                            .fill(flavor.primaryTint.opacity(0.15))
                            .frame(width: 90, height: 90)

                        Text(rack.avatarEmoji)
                            .font(.system(size: 50))
                    }
                    .padding(.top, 16)

                    // Grid
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(SpiceRackViewModel.avatarCatalog, id: \.self) { emoji in
                                Button {
                                    rack.selectAvatar(emoji)
                                    dismiss()
                                } label: {
                                    Text(emoji)
                                        .font(.system(size: 32))
                                        .frame(width: 54, height: 54)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(rack.avatarEmoji == emoji
                                                      ? flavor.primaryTint.opacity(0.25)
                                                      : SpicePalette.smokedPaprikaFallback)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .strokeBorder(rack.avatarEmoji == emoji
                                                              ? flavor.primaryTint
                                                              : Color.clear, lineWidth: 2)
                                        )
                                }
                                .flavorTap(.spoonTap)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
            .navigationTitle(L10n.string("spice.avatar.pick"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("common.close")) {
                        dismiss()
                    }
                    .foregroundColor(SpicePalette.flourDustFallback)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Trophy Case Sheet

struct TrophyCaseSheet: View {

    let trophies: [TrophyRibbon]
    let flavor: AccentFlavor
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                SpicePalette.burntCrustFallback
                    .ignoresSafeArea()

                if trophies.isEmpty {
                    VStack(spacing: 16) {
                        Text("🏆")
                            .font(.system(size: 56))
                            .opacity(0.5)
                        Text(L10n.string("spice.trophies.empty"))
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(SpicePalette.flourDustFallback)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(trophies) { trophy in
                                TrophyRibbonRow(trophy: trophy, flavor: flavor)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle(L10n.string("spice.trophies"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("common.close")) {
                        dismiss()
                    }
                    .foregroundColor(SpicePalette.flourDustFallback)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Trophy Ribbon Row

struct TrophyRibbonRow: View {

    let trophy: TrophyRibbon
    let flavor: AccentFlavor

    @State private var appeared = false

    var body: some View {
        HStack(spacing: 14) {
            // Badge
            ZStack {
                Circle()
                    .fill(flavor.primaryTint.opacity(0.15))
                    .frame(width: 52, height: 52)

                Text(trophy.badgeEmoji)
                    .font(.system(size: 28))
            }
            .scaleEffect(appeared ? 1.0 : 0.5)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(trophy.localizedName)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(SpicePalette.vanillaCreamFallback)

                Text(trophy.flavorText)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(SpicePalette.flourDustFallback)
                    .lineLimit(2)
            }

            Spacer()

            // XP + date
            VStack(alignment: .trailing, spacing: 4) {
                Text("+\(trophy.xpReward) XP")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundColor(flavor.primaryTint)

                Text(trophy.formattedDate)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(SpicePalette.peppercornFallback)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(SpicePalette.smokedPaprikaFallback)
        )
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                appeared = true
            }
        }
    }
}

// MARK: - Activity Share Sheet (UIKit bridge)

struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}

// MARK: - Preview

#if DEBUG
struct SpiceRackView_Previews: PreviewProvider {
    static var previews: some View {
        SpiceRackView()
            .environmentObject(KitchenCoordinator())
            .environment(\.accentFlavor, .saffron)
            .preferredColorScheme(.dark)
    }
}
#endif
