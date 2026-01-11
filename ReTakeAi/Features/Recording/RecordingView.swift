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
    @State private var showingCloseButton = true
    @State private var closeAutoHideTask: Task<Void, Never>?

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
            
            if shouldShowCloseButton {
                VStack {
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.white, .black.opacity(0.35))
                        }
                        .buttonStyle(.plain)

                        Spacer()
                    }
                    .padding(.leading, 14)
                    .padding(.top, 10)

                    Spacer()
                }
                .transition(.opacity)
            }

            teleprompterOverlay

            readyOverlay
            setupOverlay
            finalCountdownOverlay
            recordingOverlay
            completedOverlay
        }
        .statusBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await viewModel.setup(project: project, scene: scene)
        }
        .onAppear {
            scheduleCloseAutoHide()
        }
        .onDisappear {
            closeAutoHideTask?.cancel()
            closeAutoHideTask = nil
            viewModel.cleanup()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showingCloseButton = true
            scheduleCloseAutoHide()
        }
        .onChange(of: viewModel.phase) { _, newValue in
            if newValue == .completed {
                Task {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    dismiss()
                }
            }
            if newValue == .recording || newValue == .finalCountdown(number: 3) || newValue == .finalCountdown(number: 2) || newValue == .finalCountdown(number: 1) {
                showingCloseButton = false
            }
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
    }
    
    private var teleprompterOverlay: some View {
        VStack {
            if viewModel.isSetupComplete {
                HorizontalTeleprompterOverlay(
                    text: scene.scriptText,
                    isRunning: viewModel.phase == .recording && viewModel.isRecording,
                    direction: viewModel.preferences.scrollDirection,
                    pointsPerSecond: derivedTeleprompterPointsPerSecond(),
                    fontSize: viewModel.preferences.textSize * 1.5,
                    opacity: viewModel.phase == .completed ? 0 : viewModel.preferences.textOpacity,
                    mirror: viewModel.preferences.mirrorTextForFrontCamera
                )
                .padding(.top, 40)
                .animation(.easeInOut(duration: 0.25), value: viewModel.phase)
            }
            Spacer()
        }
        .allowsHitTesting(false)
    }

    private var setupOverlay: some View {
        Group {
            if viewModel.phase == .setup, viewModel.setupSecondsRemaining > 3 {
                VStack(spacing: 10) {
                    Spacer()

                    VStack(spacing: 6) {
                        Text("Get ready")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.9))

                        Text("\(viewModel.setupSecondsRemaining)s")
                            .font(.system(size: 44, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)

                        Text("Recording starts soon")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    Button {
                        viewModel.startNow()
                    } label: {
                        Text("Start now")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.95))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.black.opacity(0.2), in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Spacer().frame(height: 44)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.setupSecondsRemaining)
    }

    private var readyOverlay: some View {
        Group {
            if viewModel.phase == .ready {
                VStack(spacing: 12) {
                    Spacer()

                    Button {
                        viewModel.beginRecordingTimer()
                    } label: {
                        Text("Start")
                            .font(.headline.weight(.semibold))
                            .frame(width: 140, height: 56)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(!viewModel.isSetupComplete || viewModel.captureSession == nil)

                    Text("Tap Start to begin the countdown.")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.85))

                    Spacer().frame(height: 38)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
            }
        }
    }

    private var finalCountdownOverlay: some View {
        Group {
            if case let .finalCountdown(number) = viewModel.phase {
                ZStack {
                    Color.black.opacity(0.25).ignoresSafeArea()
                    Text("\(number)")
                        .id(number)
                        .font(.system(size: 150, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .transition(.opacity)
                }
                .animation(.easeInOut(duration: 0.4), value: number)
            }
        }
    }

    private var recordingOverlay: some View {
        Group {
            if viewModel.phase == .recording && viewModel.isRecording {
                VStack {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(.red)
                            .frame(width: 10, height: 10)
                        Text("REC")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.red)

                        Spacer()

                        Text(TimeInterval(viewModel.remainingSeconds).formattedDuration)
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.18), in: Capsule())
                    .padding(.top, 20)

                    Spacer()
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: viewModel.remainingSeconds)
            }
        }
    }

    private var completedOverlay: some View {
        Group {
            if viewModel.phase == .completed {
                VStack(spacing: 12) {
                    Text("Scene recorded")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.25))
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.phase)
    }

    private func derivedTeleprompterPointsPerSecond() -> Double {
        let expected = Double(max(1, viewModel.expectedSeconds))
        let characters = Double(scene.scriptText.count)
        let base = max(30, min(180, (characters / expected) * 6.0))
        return base * viewModel.preferences.defaultSpeed.multiplier
    }

    private var shouldShowCloseButton: Bool {
        showingCloseButton && (viewModel.phase == .ready || viewModel.phase == .setup)
    }

    private func scheduleCloseAutoHide() {
        closeAutoHideTask?.cancel()
        closeAutoHideTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if !Task.isCancelled {
                showingCloseButton = false
            }
        }
    }
}
