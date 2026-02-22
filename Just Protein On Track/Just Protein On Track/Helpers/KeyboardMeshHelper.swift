// KeyboardMeshHelper.swift
// PriceKitchen
//
// Keyboard-adaptive layout helpers, dismiss gestures,
// and shared UI utilities used across all screens.
// Supports iOS 16+ gracefully while looking good on iOS 26.

import SwiftUI
import Combine
import UIKit

// MARK: - Keyboard Observer

/// Publishes keyboard height changes so views can adapt their layout.
/// Works on iOS 16+ without relying on newer APIs.
final class KeyboardObserver: ObservableObject {

    @Published var keyboardHeight: CGFloat = 0
    @Published var isVisible: Bool = false

    private var cancellables = Set<AnyCancellable>()

    init() {
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .compactMap { notification -> CGFloat? in
                (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] height in
                withAnimation(.easeOut(duration: 0.25)) {
                    self?.keyboardHeight = height
                    self?.isVisible = true
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                withAnimation(.easeOut(duration: 0.25)) {
                    self?.keyboardHeight = 0
                    self?.isVisible = false
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - Keyboard Adaptive Modifier

/// Adds bottom padding equal to keyboard height so content stays visible.
/// Usage: `.keyboardAdaptive()`
struct KeyboardAdaptiveModifier: ViewModifier {

    @StateObject private var keyboard = KeyboardObserver()

    func body(content: Content) -> some View {
        content
            .padding(.bottom, keyboard.keyboardHeight > 0 ? keyboard.keyboardHeight - 34 : 0)
            .animation(.easeOut(duration: 0.25), value: keyboard.keyboardHeight)
    }
}

extension View {
    func keyboardAdaptive() -> some View {
        modifier(KeyboardAdaptiveModifier())
    }
}

// MARK: - Dismiss Keyboard on Tap

/// Adds a tap gesture to dismiss the keyboard anywhere on the view.
/// Usage: `.dismissKeyboardOnTap()`
struct DismissKeyboardModifier: ViewModifier {

    func body(content: Content) -> some View {
        content
            .onTapGesture {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil, from: nil, for: nil
                )
            }
    }
}

extension View {
    func dismissKeyboardOnTap() -> some View {
        modifier(DismissKeyboardModifier())
    }
}

// MARK: - Dismiss Keyboard on Scroll

/// Configures scroll views to dismiss keyboard on drag.
/// Usage: `.dismissKeyboardOnScroll()`
struct DismissKeyboardOnScrollModifier: ViewModifier {

    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content
                .scrollDismissesKeyboard(.interactively)
        } else {
            content
        }
    }
}

extension View {
    func dismissKeyboardOnScroll() -> some View {
        modifier(DismissKeyboardOnScrollModifier())
    }
}

// MARK: - Done Toolbar Button for Keyboard

/// Adds a "Done" button above the keyboard for numeric/decimal inputs.
/// Usage: `.keyboardDoneButton()`
struct KeyboardDoneButtonModifier: ViewModifier {

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(L10n.string("common.done")) {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil
                        )
                        FlavorFeedback.spoonTap()
                    }
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(SpicePalette.saffronGoldFallback)
                }
            }
    }
}

extension View {
    func keyboardDoneButton() -> some View {
        modifier(KeyboardDoneButtonModifier())
    }
}

// MARK: - Shimmer Loading Effect

/// A shimmering overlay for skeleton loading states.
/// Usage: `.shimmer(isActive: true)`
struct ShimmerModifier: ViewModifier {

    let isActive: Bool
    @State private var phase: CGFloat = -1.0

    func body(content: Content) -> some View {
        if isActive {
            content
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.0),
                            Color.white.opacity(0.12),
                            Color.white.opacity(0.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .offset(x: phase * 300)
                    .onAppear {
                        withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                            phase = 1.0
                        }
                    }
                )
                .mask(content)
        } else {
            content
        }
    }
}

extension View {
    func shimmer(isActive: Bool = true) -> some View {
        modifier(ShimmerModifier(isActive: isActive))
    }
}

// MARK: - Skeleton Placeholder Shapes

/// Rounded rectangle placeholder for loading states.
struct SkeletonSlab: View {

    var width: CGFloat? = nil
    var height: CGFloat = 16
    var cornerRadius: CGFloat = 6

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(SpicePalette.smokedPaprikaFallback)
            .frame(width: width, height: height)
            .shimmer()
    }
}

// MARK: - Pulse Animation Modifier

/// Makes a view gently pulse (scale up/down).
/// Usage: `.pulseGlow()`
struct PulseGlowModifier: ViewModifier {

    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.08 : 1.0)
            .opacity(isPulsing ? 1.0 : 0.85)
            .animation(
                .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear { isPulsing = true }
    }
}

extension View {
    func pulseGlow() -> some View {
        modifier(PulseGlowModifier())
    }
}

// MARK: - Conditional Modifier

extension View {
    /// Applies a modifier only when a condition is true.
    @ViewBuilder
    func conditionally<Modified: View>(
        _ condition: Bool,
        transform: (Self) -> Modified
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Safe Area Insets Helper

/// Reads safe area insets for layouts that need precise bottom padding.
struct SafeAreaInsetsKey: EnvironmentKey {
    static let defaultValue: EdgeInsets = EdgeInsets()
}

extension EnvironmentValues {
    var safeAreaInsets: EdgeInsets {
        get { self[SafeAreaInsetsKey.self] }
        set { self[SafeAreaInsetsKey.self] = newValue }
    }
}

struct SafeAreaInsetsReader: ViewModifier {

    func body(content: Content) -> some View {
        GeometryReader { geo in
            content
                .environment(\.safeAreaInsets, geo.safeAreaInsets)
        }
    }
}

extension View {
    func readSafeAreaInsets() -> some View {
        modifier(SafeAreaInsetsReader())
    }
}

// MARK: - Number Formatting Helpers

extension Double {

    /// Formats as a currency string with given code.
    func asCurrency(code: String = "EUR") -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }

    /// Formats as a percentage string like "+3.2%" or "-1.5%".
    func asPercentChange() -> String {
        let sign = self >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", self))%"
    }
}

// MARK: - Date Formatting Helpers

extension Date {

    /// Short display format: "22 Feb"
    var shortDisplay: String {
        let f = DateFormatter()
        f.dateFormat = "dd MMM"
        return f.string(from: self)
    }

    /// Medium display format: "Feb 22, 2026"
    var mediumDisplay: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: self)
    }

    /// ISO date only: "2026-02-22"
    var isoDate: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: self)
    }

    /// Is this date today?
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }
}

// MARK: - Haptic-Enhanced Button Style

/// A button style that adds a press scale + haptic feedback.
struct SpicyButtonStyle: ButtonStyle {

    var feedbackType: FlavorFeedbackType = .spoonTap

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { pressed in
                if pressed { feedbackType.trigger() }
            }
    }
}

extension ButtonStyle where Self == SpicyButtonStyle {
    static var spicy: SpicyButtonStyle { SpicyButtonStyle() }
    static func spicy(_ feedback: FlavorFeedbackType) -> SpicyButtonStyle {
        SpicyButtonStyle(feedbackType: feedback)
    }
}
