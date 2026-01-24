//
//  AppButtonStyle.swift
//  ReTakeAi
//

import SwiftUI

struct AppPrimaryButtonStyle: ButtonStyle {
    let background: Color
    let foreground: Color
    let disabledBackground: Color
    let disabledForeground: Color
    let expandsToFullWidth: Bool
    let cornerRadius: CGFloat
    let verticalPadding: CGFloat
    let horizontalPadding: CGFloat

    init(
        background: Color,
        foreground: Color = AppTheme.Colors.textPrimary,
        disabledBackground: Color = AppTheme.Colors.surface,
        disabledForeground: Color = AppTheme.Colors.textSecondary,
        expandsToFullWidth: Bool = true,
        cornerRadius: CGFloat = 12,
        verticalPadding: CGFloat = 14,
        horizontalPadding: CGFloat = 14
    ) {
        self.background = background
        self.foreground = foreground
        self.disabledBackground = disabledBackground
        self.disabledForeground = disabledForeground
        self.expandsToFullWidth = expandsToFullWidth
        self.cornerRadius = cornerRadius
        self.verticalPadding = verticalPadding
        self.horizontalPadding = horizontalPadding
    }

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let base = configuration.label
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, horizontalPadding)
            .background(isEnabled ? background : disabledBackground)
            .foregroundStyle(isEnabled ? foreground : disabledForeground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppTheme.Colors.border, lineWidth: 1)
                    .opacity(isEnabled ? 0 : 1)
            )
            .opacity(configuration.isPressed ? 0.92 : 1.0)
        
        if expandsToFullWidth {
            return AnyView(base.frame(maxWidth: .infinity))
        } else {
            return AnyView(base)
        }
    }
}
