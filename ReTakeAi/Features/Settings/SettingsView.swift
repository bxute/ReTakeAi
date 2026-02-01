//
//  SettingsView.swift
//  ReTakeAi
//

import SwiftUI

struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            AppTheme.Colors.background
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Live Preview (edge-to-edge)
                    previewSection

                    // Teleprompter Settings
                    teleprompterSection
                        .padding(.horizontal, 16)

                    // Audio Settings
                    audioSection
                        .padding(.horizontal, 16)
                }
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppTheme.Colors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
    
    // MARK: - Preview Section
    
    private var previewSection: some View {
        TeleprompterPreviewView(
            preferences: viewModel.preferences,
            restartTrigger: viewModel.previewRestartTrigger
        )
    }
    
    // MARK: - Teleprompter Section
    
    private var teleprompterSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Teleprompter")
            
            VStack(spacing: 0) {
                // Speed
                settingsRow(title: "Speed") {
                    speedPicker
                }
                
                divider
                
                // Text Size
                settingsRow(title: "Text Size", subtitle: viewModel.textSizeDisplay) {
                    textSizeSlider
                }
                
                divider
                
                // Font Color
                settingsRow(title: "Font Color") {
                    fontColorPicker
                }
                
                divider
                
                // Direction
                settingsRow(title: "Direction") {
                    directionPicker
                }
                
                divider
                
                // Mirror Text
                toggleRow(title: "Mirror Text", subtitle: "For front camera", isOn: $viewModel.mirrorText)
                
                divider
                
                // Countdown
                settingsRow(title: "Countdown") {
                    countdownPicker
                }
                
                divider
                
                // Start Beep
                toggleRow(title: "Start Beep", isOn: $viewModel.startBeepEnabled)
                
                divider
                
                // Auto-Stop
                toggleRow(title: "Auto-Stop", subtitle: "Stop recording when script ends", isOn: $viewModel.autoStopEnabled)
            }
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppTheme.Colors.border, lineWidth: 1)
            )
        }
    }
    
    // MARK: - Audio Section

    private var audioSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Audio")

            VStack(spacing: 0) {
                // Audio Recording Mode
                settingsRow(
                    title: "Recording Mode",
                    subtitle: viewModel.audioRecordingMode.description
                ) {
                    audioModePicker
                }
            }
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppTheme.Colors.border, lineWidth: 1)
            )
        }
    }

    // MARK: - Pickers

    private var speedPicker: some View {
        HStack(spacing: 8) {
            ForEach(TeleprompterSpeedPreset.allCases, id: \.self) { preset in
                chipButton(
                    title: preset.rawValue.capitalized,
                    isSelected: viewModel.speed == preset
                ) {
                    viewModel.speed = preset
                }
            }
        }
    }
    
    private var textSizeSlider: some View {
        Slider(value: $viewModel.textSize, in: 18...48, step: 1)
            .tint(AppTheme.Colors.cta)
    }
    
    private var fontColorPicker: some View {
        HStack(spacing: 10) {
            ForEach(TeleprompterTextColor.allCases, id: \.self) { color in
                colorCircleButton(
                    hexColor: color.hexValue,
                    isSelected: viewModel.textColor == color
                ) {
                    viewModel.textColor = color
                }
            }
        }
    }
    
    private var directionPicker: some View {
        HStack(spacing: 8) {
            ForEach(TeleprompterScrollDirection.allCases, id: \.self) { direction in
                chipButton(
                    title: direction.displayName,
                    isSelected: viewModel.scrollDirection == direction
                ) {
                    viewModel.scrollDirection = direction
                }
            }
        }
    }
    
    private var countdownPicker: some View {
        HStack(spacing: 8) {
            ForEach(SetupCountdownDuration.allCases, id: \.self) { duration in
                chipButton(
                    title: "\(duration.rawValue)s",
                    isSelected: viewModel.setupCountdown == duration
                ) {
                    viewModel.setupCountdown = duration
                }
            }
        }
    }

    private var audioModePicker: some View {
        HStack(spacing: 8) {
            ForEach(AudioRecordingMode.allCases, id: \.self) { mode in
                chipButton(
                    title: mode.displayName,
                    isSelected: viewModel.audioRecordingMode == mode
                ) {
                    viewModel.audioRecordingMode = mode
                }
            }
        }
    }

    // MARK: - Helper Views
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.Colors.textSecondary)
            .textCase(.uppercase)
            .tracking(0.5)
    }
    
    private func settingsRow<Content: View>(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(AppTheme.Colors.textTertiary)
                    }
                }
                Spacer()
            }
            
            content()
        }
        .padding(16)
    }
    
    private func toggleRow(title: String, subtitle: String? = nil, isOn: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.textTertiary)
                }
            }
            
            Spacer()
            
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(AppTheme.Colors.cta)
        }
        .padding(16)
    }
    
    private var divider: some View {
        Rectangle()
            .fill(AppTheme.Colors.border)
            .frame(height: 1)
            .padding(.horizontal, 16)
    }
    
    private func chipButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isSelected ? AppTheme.Colors.textPrimary : AppTheme.Colors.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isSelected ? AppTheme.Colors.cta.opacity(0.2) : AppTheme.Colors.background)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(isSelected ? AppTheme.Colors.cta.opacity(0.5) : AppTheme.Colors.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
    
    private func colorCircleButton(hexColor: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Circle()
                .fill(Color(hex: hexColor) ?? .white)
                .frame(width: 32, height: 32)
                .overlay(
                    Circle()
                        .stroke(isSelected ? AppTheme.Colors.cta : AppTheme.Colors.border, lineWidth: isSelected ? 3 : 1)
                )
                .overlay(
                    Circle()
                        .stroke(AppTheme.Colors.background, lineWidth: isSelected ? 2 : 0)
                        .padding(2)
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
