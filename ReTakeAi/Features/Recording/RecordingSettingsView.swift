//
//  RecordingSettingsView.swift
//  ReTakeAi
//

import SwiftUI

struct RecordingSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("recording_resolution") private var resolution: String = "1080p"
    @AppStorage("recording_frameRate") private var frameRate: Int = 30
    @AppStorage("recording_showGrid") private var showGrid: Bool = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Video Quality") {
                    Picker("Resolution", selection: $resolution) {
                        Text("720p").tag("720p")
                        Text("1080p").tag("1080p")
                        Text("4K").tag("4K")
                    }
                    
                    Picker("Frame Rate", selection: $frameRate) {
                        Text("24 fps").tag(24)
                        Text("30 fps").tag(30)
                        Text("60 fps").tag(60)
                    }
                }
                
                Section {
                    Toggle("Show Grid", isOn: $showGrid)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    RecordingSettingsView()
}
