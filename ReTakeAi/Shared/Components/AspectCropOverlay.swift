//
//  AspectCropOverlay.swift
//  ReTakeAi
//

import SwiftUI

/// A simple crop guide overlay to help users frame for a fixed output aspect ratio.
struct AspectCropOverlay: View {
    let aspect: VideoAspect

    var body: some View {
        GeometryReader { proxy in
            let container = proxy.size
            let targetRect = cropRect(container: container, aspect: aspect)

            ZStack {
                // Dim the outside area.
                Path { path in
                    path.addRect(CGRect(origin: .zero, size: container))
                    path.addRect(targetRect)
                }
                .fill(Color.black.opacity(0.45), style: FillStyle(eoFill: true))

                // Crop frame
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .path(in: targetRect)
                    .stroke(Color.white.opacity(0.85), lineWidth: 2)

                // Small label
                Text(aspect.title)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.6))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .position(x: targetRect.midX, y: max(24, targetRect.minY - 18))
            }
            .allowsHitTesting(false)
        }
    }

    private func cropRect(container: CGSize, aspect: VideoAspect) -> CGRect {
        let targetRatio = aspect.aspectRatio

        let containerRatio = container.width / max(container.height, 1)

        // Fit crop rect inside the container (like aspectFit).
        let width: CGFloat
        let height: CGFloat
        if containerRatio > targetRatio {
            // container is wider than target, limit by height
            height = container.height
            width = height * targetRatio
        } else {
            width = container.width
            height = width / targetRatio
        }

        let origin = CGPoint(
            x: (container.width - width) / 2.0,
            y: (container.height - height) / 2.0
        )

        return CGRect(origin: origin, size: CGSize(width: width, height: height))
    }
}



