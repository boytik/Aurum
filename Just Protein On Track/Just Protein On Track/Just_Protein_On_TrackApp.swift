//
//  Just_Protein_On_TrackApp.swift
//  Just Protein On Track
//
//  Created by Евгений on 22.02.2026.
//

import SwiftUI

@main
struct Just_Protein_On_TrackApp: App {

    @StateObject private var coordinator = KitchenCoordinator()

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
