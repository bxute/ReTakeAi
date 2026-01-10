//
//  GeneratedSceneDraft.swift
//  ReTakeAi
//

import Foundation

struct GeneratedSceneDraft: Identifiable, Hashable {
    let id: UUID
    var orderIndex: Int
    var scriptText: String
    /// Expected duration (seconds) for this scene.
    var expectedDurationSeconds: Int

    init(
        id: UUID = UUID(),
        orderIndex: Int,
        scriptText: String,
        expectedDurationSeconds: Int
    ) {
        self.id = id
        self.orderIndex = orderIndex
        self.scriptText = scriptText
        self.expectedDurationSeconds = expectedDurationSeconds
    }
}


