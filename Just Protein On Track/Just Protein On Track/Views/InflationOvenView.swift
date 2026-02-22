// InflationOvenView.swift
// PriceKitchen
//
// The "Oven" tab — feel the heat of inflation.
// Personal inflation gauge, price chart, hottest/coolest movers,
// store duels, and dynamic insights.

import SwiftUI

// MARK: - Inflation Oven View

struct InflationOvenView: View {

    @EnvironmentObject private var coordinator: KitchenCoordinator
    @Environment(\.accentFlavor) private var flavor
    @StateObject private var oven = InflationOvenViewModel()

    @State private var sectionsAppeared = false

    var body: some View {
        NavigationView {
            ZStack {
                SpicePalette.burntCrustFallback
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        headerBar
                        periodPicker
                        personalInflationGauge
                        chartSection
                        hottestSection
                        coolestSection
                        storeDuelsSection
                        insightsSection
                        Spacer(minLength: 30)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                oven.heatUpOven()
                withAnimation(.easeOut(duration: 0.5).delay(0.15)) {
                    sectionsAppeared = true
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: – Header

    private var headerBar: some View {
        HStack {
            Text(L10n.string("oven.title"))
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(SpicePalette.vanillaCreamFallback)

            Spacer()

            Text("🔥")
                .font(.system(size: 28))
        }
        .padding(.top, 12)
    }

    // MARK: – Period Picker

    private var periodPicker: some View {
        HStack(spacing: 6) {
            ForEach(TimeSeasoning.allCases) { period in
                Button {
                    oven.selectedPeriod = period
                    oven.onPeriodChanged()
                } label: {
                    Text(L10n.string(period.labelKey))
                        .font(.system(size: 14, weight: oven.selectedPeriod == period ? .bold : .medium, design: .rounded))
                        .foregroundColor(oven.selectedPeriod == period
                                         ? SpicePalette.burntCrustFallback
                                         : SpicePalette.flourDustFallback)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(oven.selectedPeriod == period
                                      ? flavor.primaryTint
                                      : SpicePalette.smokedPaprikaFallback)
                        )
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: oven.selectedPeriod)
    }

    // MARK: – Personal Inflation Gauge

    private var personalInflationGauge: some View {
        VStack(spacing: 12) {
            Text(L10n.string("oven.personalRate"))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(SpicePalette.vanillaCreamFallback)

            if let rate = oven.personalInflation {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(rate >= 0 ? "+" : "")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(inflationColor(rate))

                    Text(String(format: "%.1f", rate))
                        .font(.system(size: 48, weight: .black, design: .monospaced))
                        .foregroundColor(inflationColor(rate))

                    Text("%")
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundColor(inflationColor(rate))
                }

                // Gauge bar
                InflationGaugeBar(value: rate, flavor: flavor)
                    .frame(height: 12)
                    .padding(.horizontal, 20)

                Text(L10n.string("oven.personalRate.desc"))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(SpicePalette.flourDustFallback)
            } else {
                Text(L10n.string("oven.noChart"))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(SpicePalette.peppercornFallback)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 8)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(SpicePalette.smokedPaprikaFallback)
        )
        .opacity(sectionsAppeared ? 1 : 0)
        .offset(y: sectionsAppeared ? 0 : 20)
        .animation(.easeOut(duration: 0.5).delay(0.05), value: sectionsAppeared)
    }

    // MARK: – Chart Section

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.string("oven.chart.title"))
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(SpicePalette.vanillaCreamFallback)

            if oven.chartableItems.isEmpty {
                Text(L10n.string("oven.noChart"))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(SpicePalette.peppercornFallback)
                    .padding(.vertical, 12)
            } else {
                // Item selector chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(oven.chartableItems) { item in
                            Button {
                                oven.selectChartItem(item.id)
                                FlavorFeedback.spoonTap()
                            } label: {
                                HStack(spacing: 4) {
                                    Text(item.emoji)
                                        .font(.system(size: 14))
                                    Text(item.recipeName)
                                        .font(.system(size: 13, weight: oven.selectedChartItemID == item.id ? .bold : .medium, design: .rounded))
                                        .lineLimit(1)
                                }
                                .foregroundColor(oven.selectedChartItemID == item.id
                                                 ? SpicePalette.burntCrustFallback
                                                 : SpicePalette.flourDustFallback)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(
                                    Capsule()
                                        .fill(oven.selectedChartItemID == item.id
                                              ? flavor.primaryTint
                                              : SpicePalette.midnightCocoaFallback)
                                )
                            }
                        }
                    }
                }

                // Chart
                if !oven.chartCrumbs.isEmpty {
                    PriceLineChart(crumbs: oven.chartCrumbs, flavor: flavor)
                        .frame(height: 180)
                        .padding(.top, 8)
                        .animation(.easeInOut(duration: 0.4), value: oven.selectedChartItemID)
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

    // MARK: – Hottest Risers

    private var hottestSection: some View {
        Group {
            if !oven.hottestMovers.isEmpty {
                MoverListCard(
                    titleKey: "oven.hottest",
                    movers: oven.hottestMovers,
                    tint: SpicePalette.chiliFlakeFallback,
                    flavor: flavor
                )
                .opacity(sectionsAppeared ? 1 : 0)
                .offset(y: sectionsAppeared ? 0 : 20)
                .animation(.easeOut(duration: 0.5).delay(0.15), value: sectionsAppeared)
            }
        }
    }

    // MARK: – Coolest Drops

    private var coolestSection: some View {
        Group {
            if !oven.coolestMovers.isEmpty {
                MoverListCard(
                    titleKey: "oven.coolest",
                    movers: oven.coolestMovers,
                    tint: SpicePalette.basilLeafFallback,
                    flavor: flavor
                )
                .opacity(sectionsAppeared ? 1 : 0)
                .offset(y: sectionsAppeared ? 0 : 20)
                .animation(.easeOut(duration: 0.5).delay(0.2), value: sectionsAppeared)
            }
        }
    }

    // MARK: – Store Duels

    private var storeDuelsSection: some View {
        Group {
            if !oven.storeDuels.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(L10n.string("oven.compare"))
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(SpicePalette.vanillaCreamFallback)
                        Spacer()
                        Text("⚔️")
                            .font(.system(size: 20))
                    }

                    Text(L10n.string("oven.compare.desc"))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(SpicePalette.flourDustFallback)

                    ForEach(oven.storeDuels) { duel in
                        StoreDuelRow(duel: duel, flavor: flavor)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(SpicePalette.smokedPaprikaFallback)
                )
                .opacity(sectionsAppeared ? 1 : 0)
                .offset(y: sectionsAppeared ? 0 : 20)
                .animation(.easeOut(duration: 0.5).delay(0.25), value: sectionsAppeared)
            }
        }
    }

    // MARK: – Insights

    private var insightsSection: some View {
        Group {
            if !oven.insights.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(oven.insights) { insight in
                        HStack(alignment: .top, spacing: 10) {
                            Text(insight.emoji)
                                .font(.system(size: 22))
                                .frame(width: 32)

                            Text(insight.text)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(SpicePalette.vanillaCreamFallback)
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(insight.tintColor.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(insight.tintColor.opacity(0.2), lineWidth: 1)
                                )
                        )
                    }
                }
                .opacity(sectionsAppeared ? 1 : 0)
                .offset(y: sectionsAppeared ? 0 : 20)
                .animation(.easeOut(duration: 0.5).delay(0.3), value: sectionsAppeared)
            }
        }
    }

    // MARK: – Helpers

    private func inflationColor(_ rate: Double) -> Color {
        if abs(rate) < 0.5 { return SpicePalette.peppercornFallback }
        return rate > 0 ? SpicePalette.chiliFlakeFallback : SpicePalette.basilLeafFallback
    }
}

// MARK: - Inflation Gauge Bar

struct InflationGaugeBar: View {

    let value: Double   // can be negative or positive
    let flavor: AccentFlavor

    var body: some View {
        GeometryReader { geo in
            let midX = geo.size.width / 2
            let maxOffset = geo.size.width / 2
            let clamped = max(-30, min(30, value))
            let barWidth = CGFloat(abs(clamped) / 30) * maxOffset

            ZStack(alignment: .leading) {
                // Track
                Capsule()
                    .fill(SpicePalette.burntCrustFallback)

                // Center marker
                Rectangle()
                    .fill(SpicePalette.peppercornFallback)
                    .frame(width: 2)
                    .position(x: midX, y: geo.size.height / 2)

                // Fill bar
                Capsule()
                    .fill(
                        value >= 0
                        ? SpicePalette.chiliFlakeFallback
                        : SpicePalette.basilLeafFallback
                    )
                    .frame(width: barWidth, height: geo.size.height)
                    .offset(x: value >= 0 ? midX : midX - barWidth)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: value)
            }
        }
        .clipShape(Capsule())
    }
}

// MARK: - Price Line Chart (custom drawn)

struct PriceLineChart: View {

    let crumbs: [PriceCrumb]
    let flavor: AccentFlavor

    @State private var drawProgress: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let points = chartPoints(in: geo.size)

            ZStack {
                // Grid lines
                gridLines(in: geo.size)

                // Gradient fill under line
                if points.count >= 2 {
                    Path { path in
                        path.move(to: CGPoint(x: points[0].x, y: geo.size.height))
                        path.addLine(to: points[0])
                        for pt in points.dropFirst() {
                            path.addLine(to: pt)
                        }
                        path.addLine(to: CGPoint(x: points.last!.x, y: geo.size.height))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [flavor.primaryTint.opacity(0.3), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .opacity(Double(drawProgress))
                }

                // Line
                if points.count >= 2 {
                    Path { path in
                        path.move(to: points[0])
                        for pt in points.dropFirst() {
                            path.addLine(to: pt)
                        }
                    }
                    .trim(from: 0, to: drawProgress)
                    .stroke(
                        flavor.primaryTint,
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                    )
                }

                // Data points
                ForEach(Array(points.enumerated()), id: \.offset) { i, pt in
                    Circle()
                        .fill(flavor.primaryTint)
                        .frame(width: 7, height: 7)
                        .position(pt)
                        .opacity(Double(drawProgress))
                }

                // Date labels
                dateLabels(points: points, geo: geo)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0).delay(0.2)) {
                drawProgress = 1.0
            }
        }
        .onChange(of: crumbs.count) { _ in
            drawProgress = 0
            withAnimation(.easeOut(duration: 1.0).delay(0.1)) {
                drawProgress = 1.0
            }
        }
    }

    private func chartPoints(in size: CGSize) -> [CGPoint] {
        guard crumbs.count >= 2 else {
            return crumbs.enumerated().map { i, _ in
                CGPoint(x: size.width / 2, y: size.height / 2)
            }
        }

        let amounts = crumbs.map { $0.amount }
        let minA = (amounts.min() ?? 0) * 0.95
        let maxA = (amounts.max() ?? 1) * 1.05
        let rangeA = maxA - minA
        guard rangeA > 0 else {
            return crumbs.enumerated().map { i, _ in
                CGPoint(x: size.width * CGFloat(i) / CGFloat(crumbs.count - 1), y: size.height / 2)
            }
        }

        let paddingTop: CGFloat = 10
        let paddingBottom: CGFloat = 24

        return crumbs.enumerated().map { i, crumb in
            let x = size.width * CGFloat(i) / CGFloat(crumbs.count - 1)
            let normalized = CGFloat((crumb.amount - minA) / rangeA)
            let y = (size.height - paddingTop - paddingBottom) * (1 - normalized) + paddingTop
            return CGPoint(x: x, y: y)
        }
    }

    private func gridLines(in size: CGSize) -> some View {
        Path { path in
            for i in 0..<4 {
                let y = size.height * CGFloat(i) / 3.0
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
        }
        .stroke(SpicePalette.peppercornFallback.opacity(0.2), lineWidth: 0.5)
    }

    @ViewBuilder
    private func dateLabels(points: [CGPoint], geo: GeometryProxy) -> some View {
        let step = max(1, crumbs.count / 4)
        ForEach(Array(stride(from: 0, to: crumbs.count, by: step)), id: \.self) { i in
            if i < points.count {
                Text(crumbs[i].shortDate)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundColor(SpicePalette.peppercornFallback)
                    .position(x: points[i].x, y: geo.size.height - 6)
            }
        }
    }
}

// MARK: - Mover List Card

struct MoverListCard: View {

    let titleKey: String
    let movers: [InflationMover]
    let tint: Color
    let flavor: AccentFlavor

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.string(titleKey))
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(SpicePalette.vanillaCreamFallback)

            ForEach(movers) { mover in
                HStack(spacing: 10) {
                    Text(mover.emoji)
                        .font(.system(size: 24))
                        .frame(width: 32)

                    Text(mover.recipeName)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(SpicePalette.vanillaCreamFallback)
                        .lineLimit(1)

                    Spacer()

                    Text(mover.formattedLatest)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(SpicePalette.vanillaCreamFallback)

                    Text(mover.formattedChange)
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundColor(tint)
                        .frame(width: 60, alignment: .trailing)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(SpicePalette.smokedPaprikaFallback)
        )
    }
}

// MARK: - Store Duel Row

struct StoreDuelRow: View {

    let duel: StoreDuel
    let flavor: AccentFlavor

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(duel.emoji)
                    .font(.system(size: 20))
                Text(duel.recipeName)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(SpicePalette.vanillaCreamFallback)
                    .lineLimit(1)
                Spacer()
            }

            HStack(spacing: 0) {
                // Store A
                storeSide(name: duel.storeA, price: duel.priceA, isCheaper: duel.priceA <= duel.priceB)
                
                Text("vs")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(SpicePalette.peppercornFallback)
                    .padding(.horizontal, 8)

                // Store B
                storeSide(name: duel.storeB, price: duel.priceB, isCheaper: duel.priceB < duel.priceA)
            }

            HStack {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(SpicePalette.basilLeafFallback)

                Text("Save \(duel.formattedSavings) at \(duel.cheaperStore)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(SpicePalette.basilLeafFallback)

                Spacer()
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(SpicePalette.midnightCocoaFallback)
        )
    }

    private func storeSide(name: String, price: Double, isCheaper: Bool) -> some View {
        VStack(spacing: 4) {
            Text(name)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(SpicePalette.flourDustFallback)
                .lineLimit(1)

            let f = NumberFormatter()
            let _ = f.numberStyle = .currency
            let _ = f.currencyCode = duel.currencyCode
            Text(f.string(from: NSNumber(value: price)) ?? "\(price)")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(isCheaper ? SpicePalette.basilLeafFallback : SpicePalette.vanillaCreamFallback)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#if DEBUG
struct InflationOvenView_Previews: PreviewProvider {
    static var previews: some View {
        InflationOvenView()
            .environmentObject(KitchenCoordinator())
            .environment(\.accentFlavor, .saffron)
            .preferredColorScheme(.dark)
    }
}
#endif
