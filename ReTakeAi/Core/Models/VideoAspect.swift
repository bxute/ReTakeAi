//
//  VideoAspect.swift
//  ReTakeAi
//

import Foundation
import CoreGraphics

enum VideoAspect: String, Codable, CaseIterable, Hashable, Identifiable {
    case portrait9x16
    case landscape16x9
    case square1x1

    var id: String { rawValue }

    var title: String {
        switch self {
        case .portrait9x16: return "9:16"
        case .landscape16x9: return "16:9"
        case .square1x1: return "1:1"
        }
    }

    var subtitle: String {
        switch self {
        case .portrait9x16: return "Vertical"
        case .landscape16x9: return "Landscape"
        case .square1x1: return "Square"
        }
    }

    /// Aspect ratio value (width / height)
    var aspectRatio: CGFloat {
        switch self {
        case .portrait9x16: return 9.0 / 16.0
        case .landscape16x9: return 16.0 / 9.0
        case .square1x1: return 1.0
        }
    }

    /// Output canvas used during export/merge.
    /// Use 1080p targets for speed + predictable results.
    var exportRenderSize: CGSize {
        switch self {
        case .portrait9x16: return CGSize(width: 1080, height: 1920)
        case .landscape16x9: return CGSize(width: 1920, height: 1080)
        case .square1x1: return CGSize(width: 1080, height: 1080)
        }
    }
}



