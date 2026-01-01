//
//  ProjectDetailView.swift
//  ReTakeAi
//

import SwiftUI

struct ProjectDetailView: View {
    let project: Project
    @State private var scenes: [VideoScene] = []
    @State private var showRecording = false
    @State private var selectedSceneForRecording: VideoScene?
    
    private let sceneStore = SceneStore.shared
    
    var body: some View {
        List {
            if !scenes.isEmpty {
                // Progress Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Recording Progress")
                                .font(.headline)
                            Spacer()
                            Text("\(completedScenesCount)/\(scenes.count)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        ProgressView(value: Double(completedScenesCount), total: Double(scenes.count))
                            .tint(completedScenesCount == scenes.count ? .green : .blue)
                        
                        if let nextScene = nextIncompleteScene {
                            Button {
                                selectedSceneForRecording = nextScene
                                showRecording = true
                            } label: {
                                Label("Record Scene \(nextScene.orderIndex + 1)", systemImage: "video.fill")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            
            Section("Scenes") {
                if scenes.isEmpty {
                    NavigationLink {
                        ScriptInputView(project: project)
                    } label: {
                        Label("Add Script & Generate Scenes", systemImage: "text.badge.plus")
                    }
                } else {
                    ForEach(scenes) { scene in
                        HStack {
                            NavigationLink(value: scene) {
                                VideoSceneRowView(scene: scene)
                            }
                            
                            // Quick record button for incomplete scenes
                            if !scene.isComplete {
                                Button {
                                    selectedSceneForRecording = scene
                                    showRecording = true
                                } label: {
                                    Image(systemName: "video.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            
            if !scenes.isEmpty && scenes.allSatisfy({ $0.isComplete }) {
                Section {
                    NavigationLink {
                        ExportView(project: project)
                    } label: {
                        Label("Export Final Video", systemImage: "square.and.arrow.up")
                            .foregroundColor(.green)
                    }
                } footer: {
                    Text("All scenes recorded! Ready to export.")
                }
            }
            
            Section("Project Info") {
                LabeledContent("Status", value: project.status.rawValue.capitalized)
                LabeledContent("Created", value: project.createdAt.formatted(style: .medium))
            }
        }
        .navigationTitle(project.title)
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: VideoScene.self) { scene in
            SceneReviewView(project: project, scene: scene)
        }
        .fullScreenCover(isPresented: $showRecording) {
            if let scene = selectedSceneForRecording {
                NavigationStack {
                    RecordingView(project: project, scene: scene)
                }
            }
        }
        .onAppear {
            loadScenes()
        }
        .refreshable {
            loadScenes()
        }
    }
    
    private func loadScenes() {
        scenes = sceneStore.getScenes(for: project)
    }
    
    private var completedScenesCount: Int {
        scenes.filter { $0.isComplete }.count
    }
    
    private var nextIncompleteScene: VideoScene? {
        scenes.first { !$0.isComplete }
    }
}

struct VideoSceneRowView: View {
    let scene: VideoScene
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Scene \(scene.orderIndex + 1)")
                    .font(.headline)
                
                Spacer()
                
                if scene.isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else if scene.takeIDs.isEmpty {
                    Text("Not recorded")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            Text(scene.scriptText)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            if !scene.takeIDs.isEmpty {
                Text("\(scene.takeIDs.count) take\(scene.takeIDs.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
