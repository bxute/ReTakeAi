//
//  ScriptToneMood.swift
//  ReTakeAi
//

import Foundation

enum ScriptToneMood: String, Codable, CaseIterable, Identifiable {
    case professional
    case emotional
    case energetic
    case calm
    case cinematic
    case fun
    case serious

    var id: String { rawValue }

    var displayTitle: String {
        rawValue.prefix(1).uppercased() + rawValue.dropFirst()
    }
}


