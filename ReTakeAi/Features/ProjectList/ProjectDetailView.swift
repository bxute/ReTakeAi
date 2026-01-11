//
//  ProjectDetailView.swift
//  ReTakeAi
//

import SwiftUI

struct ProjectDetailView: View {
    let project: Project
    @State private var currentProject: Project
    @State private var scenes: [VideoScene] = []
    @State private var showingScriptEditor = false
    @State private var showingAIGeneratedNotice = false
    @State private var showingSceneBreakdown = false
    @State private var sceneBreakdownMode: SceneBreakdownReviewViewModel.Mode = .reviewExisting
    @State private var showingShoot = false
    
    private let sceneStore = SceneStore.shared
    private let projectStore = ProjectStore.shared

    init(project: Project) {
        self.project = project
        _currentProject = State(initialValue: project)
    }
    
    var body: some View {
        let trimmedScript = (currentProject.script ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let hasScript = !trimmedScript.isEmpty
        
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                // Script
                VStack(alignment: .leading, spacing: 6) {
                    Text("Script")
                        .font(.headline)
                    
                    if !hasScript {
                        Text("No script yet. Add one to generate scenes and record take-by-take.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        showingScriptEditor = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "doc.text")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .frame(width: 28)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(hasScript ? "Edit your draft" : "Add script draft")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                if hasScript {
                                    Text(scriptPreview(trimmedScript))
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                } else {
                                    Text("Paste or type your script to get started.")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            Spacer(minLength: 0)
                            
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Intent")
                        .font(.headline)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(ScriptIntent.allCases) { intent in
                                Button {
                                    setScriptIntent(intent)
                                } label: {
                                    Text(intent.displayTitle)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .background(
                                            Capsule().fill((currentProject.scriptIntent ?? .explain) == intent ? Color.primary.opacity(0.12) : Color.clear)
                                        )
                                        .overlay(
                                            Capsule().stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Expected Duration")
                        .font(.headline)
                    
                    Picker("Duration", selection: Binding(
                        get: { durationSelection(for: currentProject.expectedDurationSeconds) },
                        set: { setDurationSelection($0) }
                    )) {
                        Text("15s").tag(DurationSelection.s15)
                        Text("30s").tag(DurationSelection.s30)
                        Text("60s").tag(DurationSelection.s60)
                        Text("90s").tag(DurationSelection.s90)
                        Text("Custom").tag(DurationSelection.custom)
                    }
                    .pickerStyle(.segmented)
                    
                    if durationSelection(for: currentProject.expectedDurationSeconds) == .custom {
                        HStack {
                            Text("Seconds")
                                .foregroundStyle(.secondary)
                            Spacer()
                            TextField("45", text: Binding(
                                get: { customDurationText(for: currentProject.expectedDurationSeconds) },
                                set: { setCustomDurationText($0) }
                            ))
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 110)
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Tone / Mood")
                        .font(.headline)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(ScriptToneMood.allCases) { tone in
                                Button {
                                    setToneMood(tone)
                                } label: {
                                    Text(tone.displayTitle)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .background(
                                            Capsule().fill((currentProject.toneMood ?? .professional) == tone ? Color.primary.opacity(0.12) : Color.clear)
                                        )
                                        .overlay(
                                            Capsule().stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

            // Bottom CTAs (A/B/C)
            VStack(alignment: .leading, spacing: 6) {
                if !hasScript {
                    Button {
                        showingScriptEditor = true
                    } label: {
                        Label("Write script", systemImage: "pencil.line")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else if scenes.isEmpty {
                    Button {
                        sceneBreakdownMode = .generateFromScript(replaceExisting: true)
                        showingSceneBreakdown = true
                    } label: {
                        Label("Generate scenes", systemImage: "sparkles")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button {
                        showingScriptEditor = true
                    } label: {
                        Text("Edit draft")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                } else {
                    Button {
                        sceneBreakdownMode = .reviewExisting
                        showingSceneBreakdown = true
                    } label: {
                        Label("Review Script", systemImage: "list.bullet.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding(.top, 14)

            Button {
                showingShoot = true
            } label: {
                Label("Go to Shoot", systemImage: "video.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.red)
            .disabled(scenes.isEmpty)
            .padding(.top, 2)

            if !currentProject.exports.isEmpty {
                NavigationLink {
                    ExportsScreen(projectID: currentProject.id)
                } label: {
                    Label("Go to Exports", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .padding(.top, 2)
            }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 16)
        .navigationTitle(currentProject.title)
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(isPresented: $showingScriptEditor) {
            ScriptInputView(project: currentProject)
        }
        .navigationDestination(isPresented: $showingSceneBreakdown) {
            SceneBreakdownReviewView(projectID: currentProject.id, mode: sceneBreakdownMode)
        }
        .navigationDestination(isPresented: $showingShoot) {
            ShootOverviewView(projectID: currentProject.id)
        }
        .navigationDestination(for: VideoScene.self) { scene in
            SceneReviewView(project: currentProject, scene: scene)
        }
        .onAppear {
            loadProjectAndScenes()
        }
        .refreshable {
            loadProjectAndScenes()
        }
    }
    
    private func loadProjectAndScenes() {
        if let latest = projectStore.getProject(by: project.id) {
            currentProject = latest
        }
        scenes = sceneStore.getScenes(for: currentProject)

        // Keep project status in sync with scene completion.
        // - exported should never be downgraded
        // - completed when every scene has a selected/best take
        // - recording once any scene has at least one take
        let desiredStatus: ProjectStatus? = {
            if currentProject.status == .exported { return nil }
            if !scenes.isEmpty && scenes.allSatisfy({ $0.isComplete }) { return .completed }
            if scenes.contains(where: { $0.isRecorded }) { return .recording }
            return .draft
        }()

        if let desiredStatus, desiredStatus != currentProject.status {
            var updated = currentProject
            updated.status = desiredStatus
            do {
                try projectStore.updateProject(updated)
                currentProject = updated
            } catch {
                AppLogger.ui.error("Failed to update project status: \(error.localizedDescription)")
            }
        }
    }
    
    private var completedScenesCount: Int {
        scenes.filter { $0.isComplete }.count
    }

    private var recordedScenesCount: Int {
        scenes.filter { $0.isRecorded }.count
    }
    
    private enum DurationSelection: String {
        case s15
        case s30
        case s60
        case s90
        case custom
    }
    
    private func durationSelection(for seconds: Int?) -> DurationSelection {
        switch seconds {
        case 15: return .s15
        case 30, nil: return .s30
        case 60: return .s60
        case 90: return .s90
        default: return .custom
        }
    }
    
    private func setDurationSelection(_ selection: DurationSelection) {
        switch selection {
        case .s15: setExpectedDurationSeconds(15)
        case .s30: setExpectedDurationSeconds(30)
        case .s60: setExpectedDurationSeconds(60)
        case .s90: setExpectedDurationSeconds(90)
        case .custom:
            if let seconds = currentProject.expectedDurationSeconds, seconds > 0, ![15, 30, 60, 90].contains(seconds) {
                return
            }
            setExpectedDurationSeconds(45)
        }
    }
    
    private func customDurationText(for seconds: Int?) -> String {
        let value = seconds ?? 45
        return "\(max(10, min(value, 300)))"
    }
    
    private func setCustomDurationText(_ text: String) {
        let digits = text.filter(\.isNumber)
        guard let value = Int(digits) else { return }
        setExpectedDurationSeconds(max(10, min(value, 300)))
    }
    
    private func setScriptIntent(_ intent: ScriptIntent) {
        var updated = currentProject
        updated.scriptIntent = intent
        persistProject(updated)
    }
    
    private func setToneMood(_ mood: ScriptToneMood) {
        var updated = currentProject
        updated.toneMood = mood
        persistProject(updated)
    }
    
    private func setExpectedDurationSeconds(_ seconds: Int) {
        var updated = currentProject
        updated.expectedDurationSeconds = seconds
        persistProject(updated)
    }
    
    private func persistProject(_ updated: Project) {
        do {
            try projectStore.updateProject(updated)
            currentProject = updated
        } catch {
            AppLogger.ui.error("Failed to update project: \(error.localizedDescription)")
        }
    }
    
    private func scriptPreview(_ script: String) -> String {
        let trimmed = script.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 160 { return trimmed }
        let idx = trimmed.index(trimmed.startIndex, offsetBy: 160)
        return String(trimmed[..<idx]) + "…"
    }

    private var hasScript: Bool {
        !(currentProject.script ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
                } else if scene.isRecorded {
                    Text("Recorded")
                        .font(.caption)
                        .foregroundColor(.blue)
                } else {
                    Text("Not recorded")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            Text(scene.scriptText)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            if scene.isRecorded {
                Text("\(scene.takeIDs.count) take\(scene.takeIDs.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ExportRowView: View {
    let export: ExportedVideo
    let project: Project
    let onDelete: () -> Void
    
    @State private var showingShareSheet = false
    @State private var showingPlayer = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(export.formattedDate)
                        .font(.headline)
                    Text("\(export.aspect.title) • \(export.formattedDuration)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button {
                    showingPlayer = true
                } label: {
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                
                Button {
                    showingShareSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3)
                        .foregroundColor(.green)
                }
                .buttonStyle(.plain)
                
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.title3)
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
            
            Text(export.formattedSize)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showingPlayer) {
            NavigationStack {
                VideoPlayerView(videoURL: export.fileURL)
                    .navigationTitle("Exported Video")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") {
                                showingPlayer = false
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [export.fileURL])
        }
    }
}

//struct ShareSheet: UIViewControllerRepresentable {
//    let items: [Any]
//    
//    func makeUIViewController(context: Context) -> UIActivityViewController {
//        UIActivityViewController(activityItems: items, applicationActivities: nil)
//    }
//    
//    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
//}
