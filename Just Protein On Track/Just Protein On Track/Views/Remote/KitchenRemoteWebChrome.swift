// KitchenRemoteWebChrome.swift
// Just Protein On Track — Remote WebKit shell (reference flow)
// Full-screen `WKWebView` chrome for remote offer flow.

import SwiftUI
import UIKit
import WebKit
import Combine

// MARK: ═══════════════════════════════════════════════════════════
// MARK: Remote offer WebKit (full screen, Zeruneo parity)
// ═══════════════════════════════════════════════════════════════

private let kitchenRemoteProcessPool = WKProcessPool()

private let kitchenRemoteDataStore: WKWebsiteDataStore = {
    if #available(iOS 17.0, *) {
        return WKWebsiteDataStore(forIdentifier: KitchenRemoteWebKitStoreID.value)
    }
    return .default()
}()

private enum KitchenRemoteWebKitStoreID {
    static let value = UUID(uuidString: "A9D1C4EE-7B3A-4E2F-9C81-5F6E2D0A1B3C")!
}

private enum KitchenRemoteLoadTimeouts {
    static let requestInterval: TimeInterval = 45
    static let coordinatorTimer: TimeInterval = 45
}

// MARK: Diagnostics + safe-area probe

private enum KitchenRemoteChromeDiagnostics {

    private static var lastPaddingSignature = ""

    static func logWindowInsets(_ ui: UIEdgeInsets, interfaceOrientation: UIInterfaceOrientation?) {
        #if DEBUG
        let o = interfaceOrientation.map { String(describing: $0) } ?? "nil"
        print("[KitchenRemoteChrome] safeArea top=\(fmt(ui.top)) left=\(fmt(ui.left)) bottom=\(fmt(ui.bottom)) right=\(fmt(ui.right)) orientation=\(o)")
        #endif
    }

    static func logNotchPaddingIfChanged(
        signature: String,
        portrait: Bool,
        padding: EdgeInsets,
        policy: String
    ) {
        #if DEBUG
        guard signature != lastPaddingSignature else { return }
        lastPaddingSignature = signature
        print("[KitchenRemoteChrome] padding portrait=\(portrait) t=\(fmt(padding.top)) l=\(fmt(padding.leading)) b=\(fmt(padding.bottom)) r=\(fmt(padding.trailing)) — \(policy)")
        #endif
    }

    static func resetPaddingLogThrottle() {
        lastPaddingSignature = ""
    }

    private static func fmt(_ v: CGFloat) -> String {
        String(format: "%.1f", Double(v))
    }
}

private struct KitchenRemoteWindowInsetsProbe: UIViewRepresentable {

    @Binding var insets: UIEdgeInsets
    @Binding var interfaceOrientation: UIInterfaceOrientation

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> LayoutView {
        let v = LayoutView()
        let coordinator = context.coordinator
        v.onLayout = { [weak coordinator] window in
            coordinator?.apply(window: window)
        }
        return v
    }

    func updateUIView(_ uiView: LayoutView, context: Context) {
        context.coordinator.insetsBinding = $insets
        context.coordinator.orientationBinding = $interfaceOrientation
        let coordinator = context.coordinator
        uiView.onLayout = { [weak coordinator] window in
            coordinator?.apply(window: window)
        }
        uiView.setNeedsLayout()
    }

    final class Coordinator {
        var insetsBinding: Binding<UIEdgeInsets>?
        var orientationBinding: Binding<UIInterfaceOrientation>?
        private var lastLoggedInsets: UIEdgeInsets?
        private var lastLoggedOrientation: UIInterfaceOrientation?

        func apply(window: UIWindow) {
            let ui = window.safeAreaInsets
            let io = window.windowScene?.interfaceOrientation ?? .unknown

            if let b = insetsBinding {
                let prev = b.wrappedValue
                if !Self.nearlyEqualInsets(prev, ui) {
                    b.wrappedValue = ui
                }
            }
            if let ob = orientationBinding, ob.wrappedValue != io {
                ob.wrappedValue = io
            }

            let logInsets = lastLoggedInsets.map { !Self.nearlyEqualInsets($0, ui) } ?? true
            let logOrient = lastLoggedOrientation != io
            if logInsets || logOrient {
                lastLoggedInsets = ui
                lastLoggedOrientation = io
                KitchenRemoteChromeDiagnostics.logWindowInsets(ui, interfaceOrientation: io)
            }
        }

        private static func nearlyEqualInsets(_ a: UIEdgeInsets, _ b: UIEdgeInsets, eps: CGFloat = 0.25) -> Bool {
            abs(a.top - b.top) < eps
                && abs(a.left - b.left) < eps
                && abs(a.bottom - b.bottom) < eps
                && abs(a.right - b.right) < eps
        }
    }

    final class LayoutView: UIView {
        var onLayout: ((UIWindow) -> Void)?

        override func layoutSubviews() {
            super.layoutSubviews()
            guard let w = window else { return }
            onLayout?(w)
        }
    }
}

// MARK: Bridge + navigation delegate + Representable

final class KitchenRemoteWebBridge: ObservableObject {
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var pageTitle: String = ""

    weak var webView: WKWebView?
    var homeURL: URL?

    func syncNavigationState() {
        guard let w = webView else { return }
        canGoBack = w.canGoBack
        canGoForward = w.canGoForward
        if let t = w.title, !t.isEmpty {
            pageTitle = t
        }
    }

    func goBack() { webView?.goBack() }
    func goForward() { webView?.goForward() }
    func reload() { webView?.reload() }

    func goHome() {
        guard let w = webView, let url = homeURL else { return }
        var request = URLRequest(url: url)
        request.timeoutInterval = KitchenRemoteLoadTimeouts.requestInterval
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue(w.customUserAgent ?? "", forHTTPHeaderField: "User-Agent")
        w.load(request)
    }
}

final class KitchenRemoteBrowseCoordinator: NSObject, WKNavigationDelegate {

    let onError: () -> Void
    let on404Detected: () -> Void
    weak var bridge: KitchenRemoteWebBridge?
    var timeoutTimer: Timer?
    weak var host: WKWebView?
    weak var refreshControl: UIRefreshControl?
    var lastSynchronizedURL: URL?
    var isFirstPageLoad = true

    /// WebKit updates `canGoBack` / `canGoForward` outside `didFinish` (e.g. after `goBack`). KVO keeps toolbar state in sync.
    private var navigationBackObservation: NSKeyValueObservation?
    private var navigationForwardObservation: NSKeyValueObservation?

    init(onError: @escaping () -> Void, on404Detected: @escaping () -> Void) {
        self.onError = onError
        self.on404Detected = on404Detected
    }

    deinit {
        navigationBackObservation?.invalidate()
        navigationForwardObservation?.invalidate()
    }

    func trackNavigationCapabilities(of webView: WKWebView) {
        navigationBackObservation?.invalidate()
        navigationForwardObservation?.invalidate()
        navigationBackObservation = webView.observe(\.canGoBack, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.bridge?.syncNavigationState()
            }
        }
        navigationForwardObservation = webView.observe(\.canGoForward, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.bridge?.syncNavigationState()
            }
        }
    }

    func stopTrackingNavigationCapabilities() {
        navigationBackObservation?.invalidate()
        navigationForwardObservation?.invalidate()
        navigationBackObservation = nil
        navigationForwardObservation = nil
    }

    @objc func handleRefresh() {
        host?.reload()
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        timeoutTimer?.invalidate()
        startTimeoutTimer()
        bridge?.syncNavigationState()
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        bridge?.syncNavigationState()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        timeoutTimer?.invalidate()
        timeoutTimer = nil
        refreshControl?.endRefreshing()
        bridge?.syncNavigationState()
        if isFirstPageLoad {
            isFirstPageLoad = false
        }

        let script = """
        (function() {
            var title = document.title ? document.title.toLowerCase() : '';
            var bodyText = document.body ? document.body.innerText.toLowerCase() : '';
            return title.includes('404') || bodyText.includes('404') || bodyText.includes('not found');
        })();
        """
        webView.evaluateJavaScript(script) { [weak self] result, _ in
            if let is404 = result as? Bool, is404 {
                self?.on404Detected()
            }
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if isCancelledNavigation(error) {
            bridge?.syncNavigationState()
            return
        }
        timeoutTimer?.invalidate()
        timeoutTimer = nil
        refreshControl?.endRefreshing()
        if isNetworkError(error) { onError() }
        bridge?.syncNavigationState()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        if isCancelledNavigation(error) {
            bridge?.syncNavigationState()
            return
        }
        timeoutTimer?.invalidate()
        timeoutTimer = nil
        refreshControl?.endRefreshing()
        if isNetworkError(error) { onError() }
        bridge?.syncNavigationState()
    }

    private func isCancelledNavigation(_ error: Error) -> Bool {
        (error as NSError).code == NSURLErrorCancelled
    }

    private func isNetworkError(_ error: Error) -> Bool {
        let code = (error as NSError).code
        return code == NSURLErrorTimedOut
            || code == NSURLErrorNotConnectedToInternet
            || code == NSURLErrorCannotConnectToHost
            || code == NSURLErrorNetworkConnectionLost
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        if navigationAction.targetFrame == nil {
            KitchenRemoteFlowLog.logURL("WebView main-frame navigation", navigationAction.request.url)
        }
        decisionHandler(.allow)
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
    ) {
        if navigationResponse.isForMainFrame,
           let response = navigationResponse.response as? HTTPURLResponse,
           response.statusCode >= 400 && response.statusCode != 403 && response.statusCode <= 599 {
            timeoutTimer?.invalidate()
            refreshControl?.endRefreshing()
            on404Detected()
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    func startTimeoutTimer() {
        timeoutTimer?.invalidate()
        let interval = KitchenRemoteLoadTimeouts.coordinatorTimer
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.onError()
        }
    }
}

struct KitchenRemoteBrowseCanvas: UIViewRepresentable {

    let address: URL
    @ObservedObject var bridge: KitchenRemoteWebBridge
    let onError: () -> Void
    let on404Detected: () -> Void

    func makeCoordinator() -> KitchenRemoteBrowseCoordinator {
        KitchenRemoteBrowseCoordinator(onError: onError, on404Detected: on404Detected)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.processPool = kitchenRemoteProcessPool
        config.websiteDataStore = kitchenRemoteDataStore
        if #available(iOS 14.0, *) {
            config.limitsNavigationsToAppBoundDomains = false
        }

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_6_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Mobile/15E148 Safari/604.1"
        let uiBg = UIColor.kitchenRemoteWebChrome
        webView.backgroundColor = uiBg
        webView.scrollView.backgroundColor = uiBg
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.allowsBackForwardNavigationGestures = true

        context.coordinator.bridge = bridge
        context.coordinator.host = webView
        webView.navigationDelegate = context.coordinator

        bridge.webView = webView
        context.coordinator.trackNavigationCapabilities(of: webView)

        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(context.coordinator, action: #selector(KitchenRemoteBrowseCoordinator.handleRefresh), for: .valueChanged)
        webView.scrollView.refreshControl = refreshControl
        context.coordinator.refreshControl = refreshControl

        load(webView: webView, coordinator: context.coordinator, url: address)

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let uiBg = UIColor.kitchenRemoteWebChrome
        webView.backgroundColor = uiBg
        webView.scrollView.backgroundColor = uiBg
        if context.coordinator.lastSynchronizedURL != address {
            load(webView: webView, coordinator: context.coordinator, url: address)
        }
        bridge.webView = webView
        context.coordinator.bridge = bridge
        context.coordinator.trackNavigationCapabilities(of: webView)
    }

    private func load(webView: WKWebView, coordinator: KitchenRemoteBrowseCoordinator, url: URL) {
        KitchenRemoteFlowLog.logURL("WebView load(request)", url)
        coordinator.lastSynchronizedURL = url
        var request = URLRequest(url: url)
        request.timeoutInterval = KitchenRemoteLoadTimeouts.requestInterval
        request.cachePolicy = .useProtocolCachePolicy
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue(webView.customUserAgent ?? "", forHTTPHeaderField: "User-Agent")
        coordinator.startTimeoutTimer()
        webView.load(request)
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: KitchenRemoteBrowseCoordinator) {
        coordinator.stopTrackingNavigationCapabilities()
        coordinator.timeoutTimer?.invalidate()
        coordinator.host = nil
        coordinator.refreshControl = nil
        coordinator.bridge?.webView = nil
    }
}

// MARK: Chrome shell (toolbar + notch padding)

struct KitchenRemoteChromeShell: View {

    let address: URL
    let flowState: KitchenLaunchState

    private let homeURL: URL

    @StateObject private var webBridge = KitchenRemoteWebBridge()
    @State private var currentAddress: URL
    @State private var refreshKey = 0
    @State private var windowInsets = UIEdgeInsets.zero
    @State private var windowSceneOrientation: UIInterfaceOrientation = .unknown

    init(address: URL, flowState: KitchenLaunchState) {
        self.address = address
        self.flowState = flowState
        self.homeURL = address
        _currentAddress = State(initialValue: address)
    }

    var body: some View {
        ZStack {
            SpicePalette.remoteRecipeBrowserChromeFallback.ignoresSafeArea()

            GeometryReader { geo in
                let portrait = geo.size.height >= geo.size.width
                let uiLive = liveKeyWindowInsets()
                let pad = notchOnlyPadding(portrait: portrait, ui: uiLive)
                let notchOnLeft = !portrait && notchIsOnPhysicalLeft(uiLive)
                let sig = paddingSignature(portrait: portrait, ui: uiLive, pad: pad, notchOnLeft: notchOnLeft)

                chromeStack(portrait: portrait, notchPad: pad, uiLive: uiLive)
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                    .onChange(of: sig) { _ in
                        KitchenRemoteChromeDiagnostics.logNotchPaddingIfChanged(
                            signature: sig,
                            portrait: portrait,
                            padding: pad,
                            policy: notchPolicyDescription(portrait: portrait, notchOnLeft: notchOnLeft)
                        )
                    }
            }
            .ignoresSafeArea()

            KitchenRemoteWindowInsetsProbe(insets: $windowInsets, interfaceOrientation: $windowSceneOrientation)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
        }
        .ignoresSafeArea()
        .onAppear {
            KitchenRemoteChromeDiagnostics.resetPaddingLogThrottle()
            webBridge.homeURL = homeURL
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
            KitchenIgnitionDelegate.shared?.orientationLock = .allButUpsideDown
            KitchenIgnitionDelegate.shared?.requestPushPermissionFromUserContextIfNeeded()
            DispatchQueue.main.async {
                syncInsetsFromKeyWindow(reason: "onAppear async")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            DispatchQueue.main.async {
                syncInsetsFromKeyWindow(reason: "orientationDidChange")
            }
        }
    }

    @ViewBuilder
    private func chromeStack(portrait: Bool, notchPad: EdgeInsets, uiLive: UIEdgeInsets) -> some View {
        if portrait {
            VStack(spacing: 0) {
                SpicePalette.remoteRecipeBrowserChromeFallback
                    .frame(height: notchPad.top)
                    .frame(maxWidth: .infinity)

                webBlock
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                compactToolbar(axis: .horizontal)
                    .frame(height: KitchenRemoteChromeMetrics.toolbarThickness)
                    .frame(maxWidth: .infinity)
                    .background(SpicePalette.remoteRecipeBrowserChromeFallback)
            }
        } else {
            let notchOnLeft = notchIsOnPhysicalLeft(uiLive)
            HStack(spacing: 0) {
                if notchOnLeft {
                    landscapeToolbarRail(dividerAlignment: .trailing)
                    webBlock
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    if notchPad.leading > 0 {
                        SpicePalette.remoteRecipeBrowserChromeFallback
                            .frame(width: notchPad.leading)
                    }
                } else {
                    if notchPad.trailing > 0 {
                        SpicePalette.remoteRecipeBrowserChromeFallback
                            .frame(width: notchPad.trailing)
                    }
                    webBlock
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    landscapeToolbarRail(dividerAlignment: .leading)
                }
            }
        }
    }

    private func landscapeToolbarRail(dividerAlignment: HorizontalAlignment) -> some View {
        compactToolbar(axis: .vertical, landscapeCompact: true)
            .frame(width: KitchenRemoteChromeMetrics.toolbarThickness)
            .frame(maxHeight: .infinity)
            .background(SpicePalette.remoteRecipeBrowserChromeFallback)
    }

    private var webBlock: some View {
        KitchenRemoteBrowseCanvas(
            address: currentAddress,
            bridge: webBridge,
            onError: handleError,
            on404Detected: handle404
        )
        .id(currentAddress.absoluteString + String(refreshKey))
    }

    private func compactToolbar(axis: Axis, landscapeCompact: Bool = false) -> some View {
        Group {
            if axis == .horizontal {
                HStack(spacing: KitchenRemoteChromeMetrics.toolbarItemSpacing) {
                    toolbarButtons
                }
                .frame(maxWidth: .infinity)
            } else if landscapeCompact {
                VStack(spacing: KitchenRemoteChromeMetrics.landscapeToolbarSpacing) {
                    Spacer(minLength: 0)
                    toolbarButtons
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: KitchenRemoteChromeMetrics.toolbarItemSpacing) {
                    toolbarButtons
                }
                .frame(maxHeight: .infinity)
            }
        }
    }

    private var toolbarButtons: some View {
        Group {
            chromeButton("chevron.backward", enabled: webBridge.canGoBack) {
                webBridge.goBack()
            }
            chromeButton("chevron.forward", enabled: webBridge.canGoForward) {
                webBridge.goForward()
            }
            chromeButton("arrow.clockwise", enabled: true) {
                webBridge.reload()
            }
            chromeButton("house.fill", enabled: true) {
                webBridge.goHome()
            }
        }
    }

    private func chromeButton(_ systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: KitchenRemoteChromeMetrics.iconSize, weight: .semibold))
                .frame(width: KitchenRemoteChromeMetrics.hitTarget, height: KitchenRemoteChromeMetrics.hitTarget)
                .contentShape(Rectangle())
        }
        .disabled(!enabled)
        .foregroundColor(enabled ? SpicePalette.saffronGoldFallback : SpicePalette.peppercornFallback.opacity(0.35))
        .buttonStyle(.plain)
    }

    private func notchOnlyPadding(portrait: Bool, ui: UIEdgeInsets) -> EdgeInsets {
        if portrait {
            return EdgeInsets(top: ui.top, leading: 0, bottom: 0, trailing: 0)
        }
        return landscapeNotchEdgeInsets(ui)
    }

    private func landscapeNotchEdgeInsets(_ ui: UIEdgeInsets) -> EdgeInsets {
        if notchIsOnPhysicalLeft(ui) {
            return EdgeInsets(top: 0, leading: ui.left, bottom: 0, trailing: 0)
        }
        return EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: ui.right)
    }

    private func notchIsOnPhysicalLeft(_ ui: UIEdgeInsets) -> Bool {
        if let gaps = liveKeyWindowSafeAreaLayoutGaps() {
            let ge: CGFloat = 0.25
            if abs(gaps.left - gaps.right) > ge {
                return gaps.left > gaps.right
            }
        }

        let dl = ui.left
        let dr = ui.right
        let eps: CGFloat = 0.5
        if dl > dr + eps { return true }
        if dr > dl + eps { return false }

        let io = landscapeInterfaceOrientationForSymmetricTieBreak()
        switch io {
        case .landscapeLeft:
            return true
        case .landscapeRight:
            return false
        default:
            return true
        }
    }

    private func landscapeInterfaceOrientationForSymmetricTieBreak() -> UIInterfaceOrientation {
        if windowSceneOrientation == .landscapeLeft || windowSceneOrientation == .landscapeRight {
            return windowSceneOrientation
        }
        if let s = keyWindowScene() {
            let io = s.interfaceOrientation
            if io == .landscapeLeft || io == .landscapeRight {
                return io
            }
        }
        switch UIDevice.current.orientation {
        case .landscapeLeft:
            return .landscapeLeft
        case .landscapeRight:
            return .landscapeRight
        default:
            return .unknown
        }
    }

    private func liveKeyWindowSafeAreaLayoutGaps() -> (left: CGFloat, right: CGFloat)? {
        guard let w = keyWindow() else { return nil }
        let b = w.bounds
        let g = w.safeAreaLayoutGuide.layoutFrame
        return (g.minX, b.width - g.maxX)
    }

    private func keyWindow() -> UIWindow? {
        guard let scene = keyWindowScene() else { return nil }
        return scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first
    }

    private func notchPolicyDescription(portrait: Bool, notchOnLeft: Bool) -> String {
        if portrait { return "portrait: top inset only" }
        if notchOnLeft { return "landscape: notch left" }
        return "landscape: notch right"
    }

    private func paddingSignature(portrait: Bool, ui: UIEdgeInsets, pad: EdgeInsets, notchOnLeft: Bool) -> String {
        let side = portrait ? "P" : (notchOnLeft ? "L" : "R")
        return "\(side)|\(ui.top)|\(ui.left)|\(ui.bottom)|\(ui.right)|\(pad.top)|\(pad.leading)|\(pad.bottom)|\(pad.trailing)"
    }

    private func keyWindowScene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let s = scenes.first(where: { $0.activationState == .foregroundActive && $0.windows.contains(where: \.isKeyWindow) }) {
            return s
        }
        if let s = scenes.first(where: { $0.windows.contains(where: \.isKeyWindow) }) {
            return s
        }
        return scenes.first
    }

    private func liveKeyWindowInsets() -> UIEdgeInsets {
        guard let w = keyWindow() else {
            return windowInsets
        }
        return w.safeAreaInsets
    }

    private func syncInsetsFromKeyWindow(reason _: String) {
        guard let scene = keyWindowScene() else { return }
        let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first
        guard let window else { return }
        let ui = window.safeAreaInsets
        windowInsets = ui
        let io = window.windowScene?.interfaceOrientation ?? scene.interfaceOrientation
        windowSceneOrientation = io
        KitchenRemoteChromeDiagnostics.logWindowInsets(ui, interfaceOrientation: io)
    }

    private func handleError() {
        flowState.triggerFallback(currentAddress: currentAddress) { newAddress in
            if let url = newAddress {
                currentAddress = url
                refreshKey += 1
            }
        }
    }

    private func handle404() {
        handleError()
    }
}

private enum KitchenRemoteChromeMetrics {
    static let toolbarThickness: CGFloat = 52
    static let iconSize: CGFloat = 17
    static let hitTarget: CGFloat = 40
    static let toolbarItemSpacing: CGFloat = 8
    static let landscapeToolbarSpacing: CGFloat = 10
}

