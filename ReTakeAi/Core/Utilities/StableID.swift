//
//  StableID.swift
//  ReTakeAi
//

import Foundation
import CryptoKit

enum StableID {
    /// Deterministic ID for a take, derived from `(sceneID, takeNumber)`.
    /// This avoids random UUIDs when takes are reconstructed from filenames on disk.
    static func takeID(sceneID: UUID, takeNumber: Int) -> UUID {
        let input = "take|\(sceneID.uuidString)|\(takeNumber)"
        let digest = SHA256.hash(data: Data(input.utf8))
        let bytes = Array(digest)
        // UUID is 16 bytes.
        let uuidBytes = Array(bytes.prefix(16))

        let uuid = uuidBytes.withUnsafeBytes { raw -> UUID in
            let b = raw.bindMemory(to: UInt8.self)
            return UUID(uuid: (
                b[0], b[1], b[2], b[3],
                b[4], b[5],
                b[6], b[7],
                b[8], b[9],
                b[10], b[11], b[12], b[13], b[14], b[15]
            ))
        }

        return uuid
    }
}



