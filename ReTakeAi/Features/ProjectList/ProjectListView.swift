//
//  ProjectListView.swift
//  SceneFlow
//

import SwiftUI

struct ProjectListView: View {
    @State private var viewModel = ProjectListViewModel()
    @State private var showingCreateSheet = false
    @State private var newProjectTitle = ""
    @FocusState private var isNewProjectTitleFocused: Bool
    @State private var emptyStateContent: EmptyStateContent.Content = EmptyStateContent.random()
    @State private var tipText: String = TipContent.random()
    @State private var resumeRecordingProject: Project?
    @State private var resumeRecordingScene: VideoScene?
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.hasProjects {
                    homeWithProjects
                } else {
                    emptyState
                }
            }
            .navigationDestination(for: Project.self) { project in
                ProjectDetailView(project: project)
            }
            .sheet(isPresented: $showingCreateSheet) {
                createProjectSheet
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
            .fullScreenCover(item: $resumeRecordingScene, onDismiss: {
                resumeRecordingProject = nil
                viewModel.refresh()
            }) { scene in
                if let project = resumeRecordingProject {
                    NavigationStack {
                        RecordingView(project: project, scene: scene)
                    }
                }
            }
        }
        .tint(AppTheme.Colors.cta)
        .onAppear {
            // Ensure we never navigate with a stale Project value (draft/empty scenes).
            viewModel.refresh()
        }
    }
    
    private var homeWithProjects: some View {
        ZStack(alignment: .bottomTrailing) {
            AppTheme.Colors.background
                .ignoresSafeArea()
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    topBar
                    
                    if let resume = viewModel.resumeProject {
                        resumeRecordingCard(for: resume)
                    }
                    
                    projectsSection
                    
                    ViewThatFits(in: .vertical) {
                        tipCard
                        EmptyView()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 96)
            }
            .scrollIndicators(.hidden)
            .refreshable {
                viewModel.refresh()
                tipText = TipContent.random()
            }
            
            floatingCreateButton
                .padding(.trailing, 20)
                .padding(.bottom, 20)
        }
        .onAppear {
            tipText = TipContent.random()
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Tagline + Explanation
            VStack(spacing: 16) {
                Text(emptyStateContent.tagline)
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text(emptyStateContent.explanation)
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(.horizontal, 32)
            
            Spacer()
                .frame(height: 40)
            
            // Primary CTA
            Button {
                showingCreateSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                    Text("Create New Video")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(AppTheme.Colors.cta)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .cornerRadius(12)
            }
            .padding(.horizontal, 32)
            
            Spacer()
                .frame(height: 48)
            
            // Workflow hint
            HStack(spacing: 12) {
                Text("Script")
                Image(systemName: "arrow.right")
                    .font(.caption)
                Text("Record")
                Image(systemName: "arrow.right")
                    .font(.caption)
                Text("Export")
            }
            .font(.subheadline)
            .foregroundStyle(AppTheme.Colors.textTertiary)
            
            Spacer()
            
            // TODO: Social proof placeholder (future)
            // "Trusted by educators & professional creators"
            // Do not show fake numbers - add real data when available
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.Colors.background)
        .onAppear {
            emptyStateContent = EmptyStateContent.random()
        }
    }
    
    private var topBar: some View {
        HStack(alignment: .center) {
            Text("Home")
                .font(.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)
            
            Spacer(minLength: 0)
            
            Button {
                // TODO: Settings screen
            } label: {
                Image(systemName: "gearshape")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .padding(8)
                    .background(AppTheme.Colors.surface, in: Circle())
                    .overlay(
                        Circle().stroke(AppTheme.Colors.border, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
        }
        .padding(.top, 6)
    }
    
    private func resumeRecordingCard(for project: Project) -> some View {
        let progress = viewModel.progress(for: project)
        
        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(project.title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                
                HStack(spacing: 10) {
                    Text("Scene \(max(1, progress.nextSceneNumber)) of \(max(0, progress.totalScenes))")
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                    
                    Text("•")
                        .foregroundStyle(AppTheme.Colors.textTertiary)
                    
                    Text("Last edited \(project.updatedAt.timeAgo)")
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                .font(.subheadline)
                .lineLimit(1)
            }
            
            Button {
                startResumeRecording(for: project)
            } label: {
                Text("Resume Recording")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppTheme.Colors.cta)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.Colors.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 6)
    }
    
    private var projectsSection: some View {
        LazyVStack(alignment: .leading, spacing: 10) {
            ForEach(viewModel.projects) { project in
                NavigationLink(value: project) {
                    ProjectHomeRowView(
                        project: project,
                        progress: viewModel.progress(for: project)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var tipCard: some View {
        Text(tipText)
            .font(.subheadline)
            .foregroundStyle(AppTheme.Colors.textSecondary)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppTheme.Colors.border, lineWidth: 1)
            )
    }
    
    private var floatingCreateButton: some View {
        Button {
            showingCreateSheet = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .frame(width: 54, height: 54)
                .background(AppTheme.Colors.cta, in: Circle())
                .overlay(
                    Circle().stroke(AppTheme.Colors.border, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.20), radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Create New Video")
    }
    
    private func startResumeRecording(for project: Project) {
        let scenes = SceneStore.shared.getScenes(for: project)
        guard let nextScene = scenes.first(where: { !$0.isRecorded }) ?? scenes.first else { return }
        
        resumeRecordingProject = ProjectStore.shared.getProject(by: project.id) ?? project
        resumeRecordingScene = nextScene
    }
}

// MARK: - Home Project Row

private struct ProjectHomeRowView: View {
    let project: Project
    let progress: ProjectListViewModel.ProjectProgress
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(project.title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(1)
                
                Spacer(minLength: 0)
                
                platformBadge
            }
            
            HStack(spacing: 10) {
                progressDots
                
                Spacer(minLength: 0)
                
                Text(statusText)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
        .padding(14)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.Colors.border, lineWidth: 1)
        )
    }
    
    private var platformText: String {
        switch project.videoAspect {
        case .portrait9x16: return "Reels"
        case .landscape16x9: return "YouTube"
        case .square1x1: return "LinkedIn"
        }
    }
    
    private var platformBadge: some View {
        Text(platformText)
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppTheme.Colors.textTertiary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(AppTheme.Colors.background, in: Capsule())
            .overlay(
                Capsule().stroke(AppTheme.Colors.border, lineWidth: 1)
            )
    }
    
    private var statusText: String {
        switch project.status {
        case .draft: return "Draft"
        case .recording: return "Draft"
        case .completed: return "Ready to export"
        case .exported: return "Exported"
        }
    }
    
    private var progressDots: some View {
        let totalDots = 5
        let filled = min(
            totalDots,
            max(0, Int(round(Double(progress.recordedScenes) / Double(max(1, progress.totalScenes)) * Double(totalDots))))
        )
        
        return HStack(spacing: 6) {
            ForEach(0..<totalDots, id: \.self) { idx in
                Circle()
                    .fill(idx < filled ? AppTheme.Colors.cta : AppTheme.Colors.border)
                    .frame(width: 7, height: 7)
            }
        }
        .accessibilityLabel("Progress \(progress.recordedScenes) of \(progress.totalScenes) scenes")
    }
}

// MARK: - Empty State Content

private enum EmptyStateContent {
    struct Content {
        let tagline: String
        let explanation: String
    }
    
    // Tagline options (A/B test candidates). We randomly pick ONE each time the empty state appears.
    static let options: [Content] = [
        Content(tagline: "Record professional videos — one scene at a time.", explanation: "Create clean videos without re-recording everything."),
        Content(tagline: "Create clean videos without re-recording everything.", explanation: "Record once, fix only the scene that needs it."),
        Content(tagline: "No pressure. Record one scene at a time.", explanation: "Mess up a line? Just retake that scene."),
        Content(tagline: "Record once. Fix one scene. Move on.", explanation: "Scene-based recording makes retakes effortless."),
        Content(tagline: "A calmer way to record professional videos.", explanation: "Plan, read, and record in short, focused scenes."),
        Content(tagline: "Stop recording full takes. Start recording scenes.", explanation: "Break your video into manageable, editable parts."),
        Content(tagline: "From idea to finished video — faster.", explanation: "Script, record, and auto-assemble with ease."),
        Content(tagline: "Break videos into scenes, not retries.", explanation: "Save time by redoing only what matters."),
        Content(tagline: "Designed for clear, confident on-camera delivery.", explanation: "Use structured scenes and a built-in teleprompter."),
        Content(tagline: "Less setup. Fewer retakes. Better videos.", explanation: "A simple workflow built for busy creators."),
    ]
    
    static func random() -> Content {
        options.randomElement() ?? options[0]
    }
}

// MARK: - Tip Content

private enum TipContent {
    static let options: [String] = [
        "Record scene-by-scene to avoid full re-records.",
        "Short scenes make retakes faster and easier.",
        "If a scene feels off, retake just that scene.",
        "Pause naturally — silences are trimmed automatically.",
        "Lock exposure to prevent brightness flicker.",
        "Clean audio matters more than perfect video.",
        "Most creators finish a video in under 10 minutes.",
        "Structure reduces recording stress.",
        "Progress beats perfection.",
        "You’re in control — one scene at a time.",
    ]
    
    static func random() -> String {
        options.randomElement() ?? options[0]
    }
}

// MARK: - ProjectListView (continued)

extension ProjectListView {
    private var createProjectSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Project title")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                    
                    TextField("e.g. Travel vlog — episode 1", text: $newProjectTitle)
                        .padding(12)
                        .background(AppTheme.Colors.surface)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(AppTheme.Colors.border, lineWidth: 1)
                        )
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .focused($isNewProjectTitleFocused)
                        .onSubmit { createProject() }
                }
                
                Button {
                    createProject()
                } label: {
                    Text("Create Project")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(trimmedNewProjectTitle.isEmpty ? AppTheme.Colors.textTertiary : AppTheme.Colors.cta)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .cornerRadius(12)
                }
                .disabled(trimmedNewProjectTitle.isEmpty)
                
                Spacer(minLength: 0)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.Colors.background)
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.Colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingCreateSheet = false
                        newProjectTitle = ""
                    }
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }
            .onAppear {
                // Defer focus to ensure the sheet has finished presenting.
                DispatchQueue.main.async {
                    isNewProjectTitleFocused = true
                }
            }
        }
        .tint(AppTheme.Colors.cta)
    }
    
    private var trimmedNewProjectTitle: String {
        newProjectTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func createProject() {
        let title = trimmedNewProjectTitle
        guard !title.isEmpty else { return }
        
        viewModel.errorMessage = nil
        viewModel.createProject(title: title)
        
        guard viewModel.errorMessage == nil else { return }
        newProjectTitle = ""
        showingCreateSheet = false
    }
}

struct ProjectRowView: View {
    let project: Project
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(project.title)
                .font(.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)
            
            HStack {
                StatusBadge(status: project.status)
                
                Spacer()
                
                Text(project.updatedAt.timeAgo)
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.textTertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct StatusBadge: View {
    let status: ProjectStatus
    
    var body: some View {
        Text(status.rawValue.capitalized)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.15))
            .foregroundStyle(statusColor)
            .cornerRadius(6)
    }
    
    private var statusColor: Color {
        switch status {
        case .draft: return AppTheme.Colors.textTertiary
        case .recording: return AppTheme.Colors.cta
        case .completed: return AppTheme.Colors.success
        case .exported: return AppTheme.Colors.cta
        }
    }
}

#Preview {
    ProjectListView()
}
