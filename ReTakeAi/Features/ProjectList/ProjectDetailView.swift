//
//  ProjectDetailView.swift
//  ReTakeAi
//

import SwiftUI

struct ProjectDetailView: View {
    let project: Project
    @State private var scenes: [VideoScene] = []
    
    private let sceneStore = SceneStore.shared
    
    var body: some View {
        List {
            Section("Project Info") {
                LabeledContent("Status", value: project.status.rawValue.capitalized)
                LabeledContent("Created", value: project.createdAt.formatted(style: .medium))
                LabeledContent("Updated", value: project.updatedAt.formatted(style: .medium))
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
                        NavigationLink(value: scene) {
                            VideoSceneRowView(scene: scene)
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
                    }
                }
            }
        }
        .navigationTitle(project.title)
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: VideoScene.self) { scene in
            SceneReviewView(project: project, scene: scene)
        }
        .onAppear {
            loadScenes()
        }
    }
    
    private func loadScenes() {
        scenes = sceneStore.getScenes(for: project)
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
                }
            }
            
            Text(scene.scriptText)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            Text("\(scene.takeIDs.count) take\(scene.takeIDs.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}
