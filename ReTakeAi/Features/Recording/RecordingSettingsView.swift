//
//  RecordingSettingsView.swift
//  ReTakeAi
//

import SwiftUI

struct RecordingSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("recording_resolution") private var resolution: String = "1080p"
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
