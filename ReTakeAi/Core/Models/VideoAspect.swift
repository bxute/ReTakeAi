//
//  VideoAspect.swift
//  ReTakeAi
//

import Foundation
import CoreGraphics

enum VideoAspect: String, Codable, CaseIterable, Hashable {
    case portrait9x16
    case landscape16x9

    var title: String {
        switch self {
        case .portrait9x16: return "9:16"
        case .landscape16x9: return "16:9"
        }
    }

    /// Output canvas used during export/merge.
    /// Use 1080p targets for speed + predictable results.
    var exportRenderSize: CGSize {
        switch self {
        case .portrait9x16: return CGSize(width: 1080, height: 1920)
        case .landscape16x9: return CGSize(width: 1920, height: 1080)
        }
    }
}


