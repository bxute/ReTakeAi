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
    @State private var placeholderVisible = true
    @State private var placeholderHideScheduled = false
    @State private var placeholderHideTask: Task<Void, Never>?
    @State private var showingSettings = false
    @AppStorage("recording_showGrid") private var showGrid: Bool = false

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
                
                // Grid overlay
                if showGrid {
                    gridOverlay
                }
            } else {
                LoadingView(message: "Setting up camera...")
                    .foregroundStyle(.white)
            }
            
            teleprompterOverlayRegion
            
            // Top bar (close + settings) - positioned above teleprompter
            if shouldShowCloseButton {
                VStack {
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background(.black.opacity(0.35), in: Circle())
                        }
                        .buttonStyle(.plain)

                        Spacer()
                        
                        Button {
                            showingSettings = true
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background(.black.opacity(0.35), in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 14)

                    Spacer()
                }
                .transition(.opacity)
            }

            readyOverlay
            countdownOverlay
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
            placeholderHideTask?.cancel() 
            placeholderHideTask = nil
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
            if newValue == .recording {
                placeholderVisible = false
                placeholderHideScheduled = true
            }

            if newValue == .setup, placeholderVisible, !placeholderHideScheduled {
                placeholderHideScheduled = true
                placeholderHideTask?.cancel()
                placeholderHideTask = Task {
                    try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
                    if !Task.isCancelled {
                        placeholderVisible = false
                    }
                }
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
        .sheet(isPresented: $showingSettings) {
            RecordingSettingsView()
        }
    }
    
    private func cameraPreview(session: AVCaptureSession) -> some View {
        CameraPreviewView(session: session)
            .ignoresSafeArea()
    }
    
    private var gridOverlay: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            
            Path { path in
                // Vertical lines (rule of thirds)
                path.move(to: CGPoint(x: width / 3, y: 0))
                path.addLine(to: CGPoint(x: width / 3, y: height))
                path.move(to: CGPoint(x: 2 * width / 3, y: 0))
                path.addLine(to: CGPoint(x: 2 * width / 3, y: height))
                
                // Horizontal lines (rule of thirds)
                path.move(to: CGPoint(x: 0, y: height / 3))
                path.addLine(to: CGPoint(x: width, y: height / 3))
                path.move(to: CGPoint(x: 0, y: 2 * height / 3))
                path.addLine(to: CGPoint(x: width, y: 2 * height / 3))
            }
            .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
    
    private var teleprompterOverlayRegion: some View {
        VStack {
            // Hide teleprompter when close/settings buttons are visible
            if viewModel.isSetupComplete && !shouldShowCloseButton {
                ZStack(alignment: .center) {
                    // Background (edge-to-edge, no rounded corners)
                    Rectangle()
                        .fill(.black.opacity(0.264))

                    // Hint label (separate from marquee)
                    if placeholderVisible && !isTeleprompterScrolling {
                        Text("Your script will appear here…")
                            .font(.system(size: viewModel.preferences.textSize * 0.88, weight: .semibold))
                            .foregroundStyle((Color(hex: viewModel.preferences.textColor.hexValue) ?? .white).opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }

                    // Marquee label (only when recording)
                    if isTeleprompterScrolling {
                        HorizontalTeleprompterOverlay(
                            text: scene.scriptText,
                            isRunning: true,
                            direction: viewModel.preferences.scrollDirection,
                            scrollDuration: viewModel.computedScrollDuration,
                            fontSize: viewModel.preferences.textSize * 1.2,
                            opacity: viewModel.preferences.textOpacity,
                            mirror: viewModel.preferences.mirrorTextForFrontCamera,
                            textColorHex: viewModel.preferences.textColor.hexValue,
                            onComplete: {
                                viewModel.signalTeleprompterComplete()
                            }
                        )
                    }
                }
                .frame(height: 120)
                // Position just below dynamic island (minimal top padding)
                .padding(.top, 4)
                .transition(.opacity)
            }
            Spacer()
        }
        .animation(.easeInOut(duration: 0.25), value: shouldShowCloseButton)
        .allowsHitTesting(false)
    }

    private var isTeleprompterScrolling: Bool {
        viewModel.phase == .recording && viewModel.isRecording
    }

    private var readyOverlay: some View {
        Group {
            if viewModel.phase == .ready {
                GeometryReader { geometry in
                    let screenWidth = geometry.size.width
                    // Center between record button (center) and right edge: (0.5 + 1.0) / 2 = 0.75
                    let flipButtonX = screenWidth * 0.75
                    
                    VStack(spacing: 12) {
                        Spacer()
                        
                        // Record button (centered) with camera flip on right
                        ZStack {
                            // Record button - always centered
                            Button {
                                viewModel.beginRecordingTimer()
                            } label: {
                                Circle()
                                    .fill(.red)
                                    .frame(width: 72, height: 72)
                                    .overlay(
                                        Circle()
                                            .stroke(.white.opacity(0.2), lineWidth: 6)
                                    )
                            }
                            .buttonStyle(.plain)
                            .disabled(!viewModel.isSetupComplete || viewModel.captureSession == nil)
                            .accessibilityLabel("Start")
                            
                            // Camera flip - centered between record button and right edge, auto-hideable
                            if showingCloseButton {
                                Button {
                                    Task { await viewModel.switchCamera() }
                                } label: {
                                    Image(systemName: "camera.rotate")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 44, height: 44)
                                        .background(.black.opacity(0.35), in: Circle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Switch Camera")
                                .position(x: flipButtonX, y: 36) // 36 = half of 72 (record button height)
                                .transition(.opacity)
                            }
                        }
                        .frame(height: 72)
                        
                        Text("Tap Start to begin the countdown.")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.85))
                        
                        Spacer().frame(height: 38)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .transition(.opacity)
            }
        }
    }

    /// Unified countdown overlay for both setup (10→4) and final (3→1) phases
    private var countdownOverlay: some View {
        Group {
            if let countdownNumber = currentCountdownNumber {
                ZStack {
                    Color.black.opacity(0.25).ignoresSafeArea()

                    Text("\(countdownNumber)")
                        .font(.system(size: 150, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    // "Start now" button only during setup phase (not during 3-2-1)
                    if viewModel.phase == .setup {
                        VStack {
                            Spacer()
                            Button {
                                viewModel.startNow()
                            } label: {
                                Text("Start now")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.95))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(.black.opacity(0.25), in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .padding(.bottom, 60)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    /// Returns the current countdown number to display, or nil if not in countdown
    private var currentCountdownNumber: Int? {
        switch viewModel.phase {
        case .setup where viewModel.setupSecondsRemaining > 0:
            return viewModel.setupSecondsRemaining
        case .finalCountdown(let number):
            return number
        default:
            return nil
        }
    }

    private var recordingOverlay: some View {
        Group {
            EmptyView()
        }
    }

    private var completedOverlay: some View {
        Group {
            if viewModel.phase == .completed {
                VStack(spacing: 12) {
                    Text("Cut! Cut!")
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
