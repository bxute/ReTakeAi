//
//  ScriptIntent.swift
//  ReTakeAi
//

import Foundation

enum ScriptIntent: String, Codable, CaseIterable, Identifiable {
    case explain
    case promote
    case storytelling
    case educate
    case entertainment
    case corporate

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .explain: return "🎓 Explain"
        case .promote: return "📢 Promote"
        case .storytelling: return "🎬 Storytelling"
        case .educate: return "🧠 Educate"
        case .entertainment: return "🎉 Entertainment"
        case .corporate: return "💼 Corporate"
        }
    }
}


