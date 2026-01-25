//
//  ShootOverviewView.swift
//  ReTakeAi
//

import SwiftUI

struct ShootOverviewView: View {
    let projectID: UUID
    @State private var viewModel: ShootOverviewViewModel

    @State private var selectedSceneForRecording: VideoScene?
    @State private var selectedSceneForDetails: VideoScene?
    
    // Reorder mode
    @State private var isReorderMode = false
    @State private var reorderedScenes: [VideoScene] = []

    init(projectID: UUID) {
        self.projectID = projectID
        _viewModel = State(initialValue: ShootOverviewViewModel(projectID: projectID))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            AppTheme.Colors.background
                .ignoresSafeArea()

            if isReorderMode {
                // Reorder mode with arrow buttons
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(reorderedScenes.enumerated()), id: \.element.id) { index, scene in
                            reorderableSceneRow(for: scene, at: index)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 16)
                }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        if viewModel.project != nil {
                            scenesSection
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 16)
                    .padding(.bottom, 80) // Space for sticky CTA
                }
                
                // Sticky bottom CTA
                if !viewModel.scenes.isEmpty {
                    stickyBottomCTA
                }
            }
        }
        .navigationTitle("Shoot")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppTheme.Colors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(isReorderMode ? "Reorder Scenes" : "Scene Shoot")
                        .font(.headline)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    if !isReorderMode {
                        Text("\(viewModel.scenes.count) scenes • \(viewModel.recordedScenesCount) recorded")
                            .font(.caption)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                if isReorderMode {
                    Button("Done") {
                        saveReorderedScenes()
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.cta)
                } else if viewModel.scenes.count > 1 {
                    Menu {
                        Button {
                            enterReorderMode()
                        } label: {
                            Label("Reorder Scenes", systemImage: "arrow.up.arrow.down")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                }
            }
            
            if isReorderMode {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        exitReorderMode()
                    }
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }
        }
        .navigationDestination(item: $selectedSceneForDetails) { scene in
            ShootSceneDetailView(projectID: projectID, sceneID: scene.id)
        }
        .onAppear {
            viewModel.load()
        }
        .onReceive(NotificationCenter.default.publisher(for: .sceneDidUpdate)) { _ in
            viewModel.load()
        }
        .refreshable {
            viewModel.load()
        }
        .fullScreenCover(item: $selectedSceneForRecording, onDismiss: {
            viewModel.load()
        }) { scene in
            if let project = viewModel.project {
                NavigationStack {
                    RecordingView(project: project, scene: scene)
                }
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            if let msg = viewModel.errorMessage { Text(msg) }
        }
    }

    // MARK: - Sticky Bottom CTA

    private var stickyBottomCTA: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(AppTheme.Colors.border)
                .frame(height: 1)

            Group {
                if let nextScene = viewModel.nextSceneToRecord {
                    Button {
                        selectedSceneForRecording = nextScene
                    } label: {
                        Label("Record Next Scene", systemImage: "video.fill")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AppPrimaryButtonStyle(background: AppTheme.Colors.cta, expandsToFullWidth: true))
                } else {
                    NavigationLink {
                        PreviewScreen(projectID: projectID)
                    } label: {
                        Label("Review & Export", systemImage: "square.and.arrow.up")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AppPrimaryButtonStyle(background: AppTheme.Colors.cta, expandsToFullWidth: true))
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(AppTheme.Colors.surface)
    }

    // MARK: - Scenes Section

    private var scenesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.scenes.isEmpty {
                Text("Generate scenes to start shooting.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            } else {
                ForEach(viewModel.scenes.sorted(by: { $0.orderIndex < $1.orderIndex })) { scene in
                    sceneCard(for: scene)
                }
            }
        }
    }
    
    private func reorderableSceneRow(for scene: VideoScene, at index: Int) -> some View {
        let isRecorded = viewModel.hasTakes(for: scene)
        let isFirst = index == 0
        let isLast = index == reorderedScenes.count - 1
        
        return HStack(spacing: 12) {
            // Move buttons
            VStack(spacing: 4) {
                Button {
                    moveScene(at: index, direction: -1)
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isFirst ? AppTheme.Colors.textTertiary.opacity(0.3) : AppTheme.Colors.textSecondary)
                        .frame(width: 28, height: 24)
                }
                .disabled(isFirst)
                
                Button {
                    moveScene(at: index, direction: 1)
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isLast ? AppTheme.Colors.textTertiary.opacity(0.3) : AppTheme.Colors.textSecondary)
                        .frame(width: 28, height: 24)
                }
                .disabled(isLast)
            }
            
            // Status dot
            Circle()
                .fill(isRecorded ? AppTheme.Colors.success : AppTheme.Colors.textTertiary)
                .frame(width: 8, height: 8)
            
            // Scene info
            VStack(alignment: .leading, spacing: 2) {
                Text("Scene \(index + 1)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                
                Text(scene.scriptText)
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.Colors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.Colors.border, lineWidth: 1)
        )
    }
    
    private func moveScene(at index: Int, direction: Int) {
        let newIndex = index + direction
        guard newIndex >= 0 && newIndex < reorderedScenes.count else { return }
        
        withAnimation(.easeInOut(duration: 0.2)) {
            reorderedScenes.swapAt(index, newIndex)
        }
    }
    
    // MARK: - Reorder Actions
    
    private func enterReorderMode() {
        reorderedScenes = viewModel.scenes.sorted { $0.orderIndex < $1.orderIndex }
        withAnimation(.easeInOut(duration: 0.2)) {
            isReorderMode = true
        }
    }
    
    private func exitReorderMode() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isReorderMode = false
        }
        reorderedScenes = []
    }
    
    private func saveReorderedScenes() {
        // Update orderIndex for each scene based on new position
        for (index, scene) in reorderedScenes.enumerated() {
            if scene.orderIndex != index {
                var updated = scene
                updated.orderIndex = index
                try? SceneStore.shared.updateScene(updated)
            }
        }
        
        // Exit reorder mode and reload
        withAnimation(.easeInOut(duration: 0.2)) {
            isReorderMode = false
        }
        reorderedScenes = []
        viewModel.load()
    }

    // MARK: - Scene Card

    private func sceneCard(for scene: VideoScene) -> some View {
        let takes = viewModel.getTakes(for: scene)
        let best = viewModel.bestTake(for: scene)
        let isRecorded = viewModel.hasTakes(for: scene)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                // Thumbnail: Only show for recorded scenes
                if isRecorded, let best {
                    VideoThumbnailView(
                        videoURL: best.fileURL,
                        isPortrait: best.resolution.height > best.resolution.width,
                        durationText: nil
                    )
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 6) {
                    // Header: Status dot + Scene title + duration + action button
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        // Status indicator dot
                        Circle()
                            .fill(isRecorded ? AppTheme.Colors.success : AppTheme.Colors.textTertiary)
                            .frame(width: 8, height: 8)

                        Text("Scene \(scene.orderIndex + 1)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)

                        if let duration = scene.duration {
                            Text("\(Int(duration))s")
                                .font(.caption)
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                        }

                        Spacer()

                        // Action button: different for recorded vs unrecorded
                        if isRecorded {
                            Button {
                                selectedSceneForRecording = scene
                            } label: {
                                Text("Retake")
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(AppTheme.Colors.textSecondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(AppTheme.Colors.surface)
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .stroke(AppTheme.Colors.border, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button {
                                selectedSceneForRecording = scene
                            } label: {
                                Text("Record Scene")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.Colors.textPrimary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(AppTheme.Colors.cta)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Script preview
                    Text(scene.scriptText)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .lineLimit(2)

                    // Takes info: Only show for recorded scenes
                    if isRecorded {
                        HStack(spacing: 6) {
                            Text("Takes: \(takes.count)")
                                .font(.caption)
                                .foregroundStyle(AppTheme.Colors.textSecondary)

                            if let best {
                                Text("•")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.Colors.textTertiary)

                                Text("Best: #\(best.takeNumber)")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.Colors.textSecondary)

                                Text("•")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.Colors.textTertiary)

                                Text(best.duration.shortDuration)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.Colors.textSecondary)
                            }

                            Spacer(minLength: 0)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.Colors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isRecorded ? AppTheme.Colors.success.opacity(0.3) : AppTheme.Colors.border, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            selectedSceneForDetails = scene
        }
    }
}

