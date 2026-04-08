//
//  Just_Protein_On_TrackApp.swift
//  Just Protein On Track
//
//  Created by Евгений on 22.02.2026.
//

import SwiftUI
import WebKit

@main
struct Just_Protein_On_TrackApp: App {

    @UIApplicationDelegateAdaptor(KitchenIgnitionDelegate.self) private var kitchenIgnitionDelegate

    @StateObject private var coordinator = KitchenCoordinator()

    init() {
        Task.detached(priority: .background) {
            _ = await MainActor.run { WKWebView(frame: .zero) }
        }
    }

    var body: some Scene {
        WindowGroup {
            KitchenGateway()
                .environmentObject(coordinator)
                .environment(\.accentFlavor, coordinator.selectedFlavor)
                .environment(\.managedObjectContext, coordinator.pantry.viewContext)
                .preferredColorScheme(.dark)
        }
    }
}
