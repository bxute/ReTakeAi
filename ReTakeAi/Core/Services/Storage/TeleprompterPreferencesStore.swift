//
//  TeleprompterPreferencesStore.swift
//  ReTakeAi
//

import Foundation

enum TeleprompterPreferencesStore {
    private static let key = "teleprompterPreferences.v1"

    static func load() -> TeleprompterPreferences {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return TeleprompterPreferences()
        }
        do {
            return try JSONDecoder().decode(TeleprompterPreferences.self, from: data)
        } catch {
            return TeleprompterPreferences()
        }
    }

    static func save(_ preferences: TeleprompterPreferences) {
        do {
            let data = try JSONEncoder().encode(preferences)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            // no-op
        }
    }
}



