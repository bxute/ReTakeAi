//
//  TeleprompterView.swift
//  SceneFlow
//

import SwiftUI

struct TeleprompterView: View {
    let text: String
    @State private var viewModel: TeleprompterViewModel
    
    init(text: String, settings: TeleprompterSettings = TeleprompterSettings()) {
        self.text = text
        _viewModel = State(initialValue: TeleprompterViewModel(text: text, settings: settings))
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack {
                    Color.clear.frame(height: 100)
                    
                    Text(viewModel.currentText)
                        .font(.system(size: viewModel.settings.fontSize))
                        .foregroundColor(viewModel.settings.textColor)
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    Color.clear.frame(height: 100)
                }
                .id("content")
            }
            .background(viewModel.settings.backgroundColor.opacity(viewModel.settings.opacity))
            .onChange(of: viewModel.scrollOffset) { _, _ in
                withAnimation {
                    proxy.scrollTo("content", anchor: .top)
                }
            }
        }
        .overlay(alignment: .bottom) {
            controls
        }
        .onAppear {
            viewModel.startScrolling()
        }
        .onDisappear {
            viewModel.cleanup()
        }
    }
    
    private var controls: some View {
        HStack(spacing: 20) {
            Button {
                if viewModel.isPaused {
                    viewModel.resumeScrolling()
                } else {
                    viewModel.pauseScrolling()
                }
            } label: {
                Image(systemName: viewModel.isPaused ? "play.fill" : "pause.fill")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            
            Button {
                viewModel.resetScroll()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.title2)
                    .foregroundColor(.white)
            }
        }
        .padding()
        .background(Color.black.opacity(0.5))
        .cornerRadius(12)
        .padding(.bottom, 20)
    }
}
