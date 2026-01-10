//
//  SceneReviewView.swift
//  ReTakeAi
//

import SwiftUI

struct SceneReviewView: View {
    let project: Project
    let scene: VideoScene
    
    @State private var viewModel: SceneReviewViewModel
    @State private var selectedTake: Take?
    @State private var showingRecording = false
    
    init(project: Project, scene: VideoScene) {
        self.project = project
        self.scene = scene
        _viewModel = State(initialValue: SceneReviewViewModel(project: project))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if let take = selectedTake {
                videoPreview(take: take)
            }
            
            takesList
        }
        .navigationTitle("Scene \(scene.orderIndex + 1)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingRecording = true
                } label: {
                    Label("Record Take", systemImage: "video.badge.plus")
                }
            }
        }
        .sheet(isPresented: $showingRecording) {
            NavigationStack {
                RecordingView(project: project, scene: scene)
            }
        }
        .onAppear {
            viewModel.loadScenes()
            selectFirstTakeIfNeeded()
        }
    }
    
    private func videoPreview(take: Take) -> some View {
        VideoPlayerView(videoURL: take.fileURL)
            .frame(height: 300)
            .background(Color.black)
    }
    
    private var takesList: some View {
        List {
            Section {
                Text(scene.scriptText)
                    .font(.body)
                    .padding(.vertical, 8)
            } header: {
                Text("Script")
            }

            if let direction = scene.aiDirection ?? project.aiDirection {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(direction.tone.rawValue)
                            .font(.headline)

                        Text(direction.delivery)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text(direction.actorInstructions)
                            .font(.body)
                    }
                    .padding(.vertical, 6)
                } header: {
                    Text("Direction")
                }
            }
            
            Section {
                let takes = viewModel.getTakes(for: scene)
                
                if takes.isEmpty {
                    ContentUnavailableView(
                        "No Takes Yet",
                        systemImage: "video.slash",
                        description: Text("Record your first take to get started")
                    )
                } else {
                    ForEach(takes) { take in
                        TakeRowView(
                            take: take,
                            isSelected: scene.selectedTakeID == take.id,
                            onSelect: {
                                selectedTake = take
                            },
                            onMarkBest: {
                                viewModel.selectTake(take, for: scene)
                            }
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                viewModel.deleteTake(take, from: scene)
                                if selectedTake?.id == take.id {
                                    selectedTake = nil
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            } header: {
                Text("Takes (\(viewModel.getTakes(for: scene).count))")
            }
        }
    }
    
    private func selectFirstTakeIfNeeded() {
        let takes = viewModel.getTakes(for: scene)
        if selectedTake == nil, !takes.isEmpty {
            selectedTake = takes.first
        }
    }
}

struct TakeRowView: View {
    let take: Take
    let isSelected: Bool
    let onSelect: () -> Void
    let onMarkBest: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Take \(take.takeNumber)")
                            .font(.headline)
                        
                        if isSelected {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                        }
                    }
                    
                    HStack(spacing: 12) {
                        Label(take.duration.shortDuration, systemImage: "clock")
                        Label(ByteCountFormatter.string(fromByteCount: take.fileSize, countStyle: .file), systemImage: "doc")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    Text(take.recordedAt.timeAgo)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if !isSelected {
                    Button {
                        onMarkBest()
                    } label: {
                        Label("Mark Best", systemImage: "star")
                            .labelStyle(.iconOnly)
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
