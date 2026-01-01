//
//  RecordingView.swift
//  ReTakeAi
//

import SwiftUI
import AVFoundation
import UIKit

struct RecordingView: View {
    let project: Project
    let scene: VideoScene
    
    @State private var viewModel = RecordingViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var effectiveAspect: VideoAspect = .portrait9x16

    private var isShowingError: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { newValue in
                if !newValue { viewModel.errorMessage = nil }
            }
        )
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if viewModel.isSetupComplete, let session = viewModel.captureSession {
                cameraPreview(session: session)
            } else {
                LoadingView(message: "Setting up camera...")
                    .foregroundStyle(.white)
            }
            
            VStack {
                topBar
                
                Spacer()
                
                if viewModel.showTeleprompter {
                    teleprompterOverlay
                }
                
                Spacer()
                
                bottomControls
            }
        }
        .navigationBarBackButtonHidden(viewModel.isRecording)
        .task {
            await viewModel.setup(project: project, scene: scene)
        }
        .onAppear {
            updateEffectiveAspect()
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            updateEffectiveAspect()
        }
        .onDisappear {
            UIDevice.current.endGeneratingDeviceOrientationNotifications()
            viewModel.cleanup()
        }
        .alert("Recording Error", isPresented: isShowingError) {
            if let msg = viewModel.errorMessage, msg.localizedCaseInsensitiveContains("not authorized") {
                Button("Open Settings") {
                    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                }
            }
            Button("Retry") {
                Task { await viewModel.retrySetup() }
            }
            Button("OK", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error")
        }
    }
    
    private func cameraPreview(session: AVCaptureSession) -> some View {
        CameraPreviewView(session: session)
            .ignoresSafeArea()
            .overlay {
                AspectCropOverlay(aspect: effectiveAspect)
            }
    }

    private func updateEffectiveAspect() {
        let io = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.interfaceOrientation ?? .portrait
        effectiveAspect = io.isLandscape ? .landscape16x9 : .portrait9x16
    }
    
    private var topBar: some View {
        HStack {
            if !viewModel.isRecording {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.title3)
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }
            }
            
            Spacer()
            
            Button {
                viewModel.toggleTeleprompter()
            } label: {
                Image(systemName: viewModel.showTeleprompter ? "text.bubble.fill" : "text.bubble")
                    .font(.title3)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
            
            Button {
                Task {
                    await viewModel.switchCamera()
                }
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath.camera")
                    .font(.title3)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
            .disabled(viewModel.isRecording)
        }
        .padding()
    }
    
    private var teleprompterOverlay: some View {
        ScrollView {
            Text(scene.scriptText)
                .font(.system(size: 24))
                .foregroundColor(.white)
                .padding()
        }
        .frame(maxHeight: 200)
        .background(Color.black.opacity(0.7))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var bottomControls: some View {
        VStack(spacing: 16) {
            if viewModel.isRecording {
                Text(viewModel.recordingDuration.formattedDuration)
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundColor(.red)
            }
            
            HStack(spacing: 40) {
                if viewModel.isRecording {
                    Button {
                        Task {
                            await viewModel.cancelRecording()
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Color.red.opacity(0.8))
                            .clipShape(Circle())
                    }
                }
                
                Button {
                    Task {
                        if viewModel.isRecording {
                            await viewModel.stopRecording()
                            dismiss()
                        } else {
                            await viewModel.startRecording()
                        }
                    }
                } label: {
                    Circle()
                        .fill(viewModel.isRecording ? Color.red : Color.white)
                        .frame(width: 80, height: 80)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 4)
                                .padding(4)
                        )
                }
                .disabled(!viewModel.isSetupComplete || viewModel.captureSession == nil)
                .opacity((!viewModel.isSetupComplete || viewModel.captureSession == nil) ? 0.4 : 1.0)
                
                if viewModel.isRecording {
                    Color.clear
                        .frame(width: 60, height: 60)
                }
            }
        }
        .padding(.bottom, 40)
    }
}
