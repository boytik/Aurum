//
//  FeedBackTypes.swift
//  Just Protein On Track
//
//  Created by Евгений on 22.02.2026.
//

import Foundation

enum FlavorFeedbackType {
    case spoonTap
    case ovenDoorShut
    case cleaverChop
    case flourDust
    case eggCrack
    case pepperGrind
    case goldenCrust
    case timerBeep
    case burntSouffle
    case champagneBubbles
    case clinkGlasses

    func trigger() {
        switch self {
        case .spoonTap:         FlavorFeedback.spoonTap()
        case .ovenDoorShut:     FlavorFeedback.ovenDoorShut()
        case .cleaverChop:      FlavorFeedback.cleaverChop()
        case .flourDust:        FlavorFeedback.flourDust()
        case .eggCrack:         FlavorFeedback.eggCrack()
        case .pepperGrind:      FlavorFeedback.pepperGrind()
        case .goldenCrust:      FlavorFeedback.goldenCrust()
        case .timerBeep:        FlavorFeedback.timerBeep()
        case .burntSouffle:     FlavorFeedback.burntSouffle()
        case .champagneBubbles: FlavorFeedback.champagneBubbles()
        case .clinkGlasses:     FlavorFeedback.clinkGlasses()
        }
    }
}
