//
//  CameraPreviewView.swift
//  SceneFlow
//

import SwiftUI
import AVFoundation
import UIKit

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        context.coordinator.attach(to: view)
        context.coordinator.updateOrientation()
        return view
    }
    
    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        uiView.videoPreviewLayer.session = session
        context.coordinator.updateOrientation()
    }

    static func dismantleUIView(_ uiView: PreviewUIView, coordinator: Coordinator) {
        coordinator.detach()
    }
    
    class PreviewUIView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }
        
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            // Ensure the preview layer always fills the view during rotations.
            videoPreviewLayer.frame = bounds
        }
    }
    
    final class Coordinator {
        private weak var view: PreviewUIView?
        private var observer: NSObjectProtocol?
        
        func attach(to view: PreviewUIView) {
            self.view = view
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
            observer = NotificationCenter.default.addObserver(
                forName: UIDevice.orientationDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.updateOrientation()
            }
        }
        
        func detach() {
            if let observer {
                NotificationCenter.default.removeObserver(observer)
            }
            observer = nil
            view = nil
            UIDevice.current.endGeneratingDeviceOrientationNotifications()
        }
        
        func updateOrientation() {
            guard let connection = view?.videoPreviewLayer.connection else { return }
            let orientation = currentInterfaceOrientation()
            
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = orientation
            }
        }
        
        private func currentInterfaceOrientation() -> AVCaptureVideoOrientation {
            let interfaceOrientation = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.interfaceOrientation ?? .portrait
            switch interfaceOrientation {
            case .portrait:
                return .portrait
            case .portraitUpsideDown:
                return .portraitUpsideDown
            case .landscapeLeft:
                return .landscapeLeft
            case .landscapeRight:
                return .landscapeRight
            default:
                return .portrait
            }
        }
    }
}
