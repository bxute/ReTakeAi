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
    @State private var showingSceneBreakdown = false
    @State private var sceneBreakdownMode: SceneBreakdownReviewViewModel.Mode = .reviewExisting
    @State private var showingShoot = false
    @State private var showingIntentSheet = false
    @State private var showingDurationSheet = false
    @State private var showingToneSheet = false
    @State private var isEditingTitle = false
    @State private var editedTitle = ""
    @FocusState private var isTitleFocused: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteConfirm = false
    @State private var showingDeleteError = false
    @State private var deleteErrorMessage: String?
    
    private let sceneStore = SceneStore.shared
    private let projectStore = ProjectStore.shared

    init(project: Project) {
        self.project = project
        _currentProject = State(initialValue: project)
        _editedTitle = State(initialValue: project.title)
    }
    
    private var hasScript: Bool {
        !(currentProject.script ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var hasScenes: Bool {
        !scenes.isEmpty
    }
    
    private var recordedScenesCount: Int {
        scenes.filter { $0.isRecorded }.count
    }
    
    private var hasExports: Bool {
        !currentProject.exports.isEmpty
    }
    
    var body: some View {
        ZStack {
            AppTheme.Colors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        headerSection
                        scriptPreviewCard
                        projectSummaryRow
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 16)
                }
                .scrollIndicators(.hidden)
                
                actionsSection
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                
                tipSection
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
        }
        .navigationTitle("Project Overview")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppTheme.Colors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        showingDeleteConfirm = true
                    } label: {
                        Label("Delete Project", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.body)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }
        }
        .alert("Delete this project?", isPresented: $showingDeleteConfirm) {
            Button("Delete", role: .destructive) {
                deleteProject()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this project?\n\nThis will delete all the scenes and exports associated with this project.")
        }
        .alert("Error", isPresented: $showingDeleteError) {
            Button("OK") {
                deleteErrorMessage = nil
            }
        } message: {
            Text(deleteErrorMessage ?? "Something went wrong.")
        }
        .navigationDestination(isPresented: $showingScriptEditor) {
            ScriptInputView(project: currentProject)
        }
        .navigationDestination(isPresented: $showingSceneBreakdown) {
            SceneBreakdownReviewView(projectID: currentProject.id, mode: sceneBreakdownMode)
        }
        .navigationDestination(isPresented: $showingShoot) {
            ShootOverviewView(projectID: currentProject.id)
        }
        .sheet(isPresented: $showingIntentSheet) {
            IntentPickerSheet(
                selectedIntent: currentProject.scriptIntent,
                onSelect: { intent in
                    updateIntent(intent)
                }
            )
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingDurationSheet) {
            DurationPickerSheet(
                selectedDuration: currentProject.expectedDurationSeconds,
                onSelect: { duration in
                    updateDuration(duration)
                }
            )
            .presentationDetents([.height(280)])
        }
        .sheet(isPresented: $showingToneSheet) {
            TonePickerSheet(
                selectedTone: currentProject.toneMood,
                onSelect: { tone in
                    updateTone(tone)
                }
            )
            .presentationDetents([.medium])
        }
        .onAppear {
            loadProjectAndScenes()
        }
        .refreshable {
            loadProjectAndScenes()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isEditingTitle {
                HStack(spacing: 12) {
                    TextField("Project name", text: $editedTitle)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .focused($isTitleFocused)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .onSubmit { saveTitle() }
                    
                    Button {
                        saveTitle()
                    } label: {
                        Text("Done")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.cta)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(AppTheme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.Colors.cta.opacity(0.5), lineWidth: 1)
                )
            } else {
                Button {
                    editedTitle = currentProject.title
                    isEditingTitle = true
                    isTitleFocused = true
                } label: {
                    HStack(spacing: 8) {
                        Text(currentProject.title)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        
                        Image(systemName: "pencil")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Colors.textTertiary)
                    }
                }
                .buttonStyle(.plain)
            }
            
            if hasScenes {
                progressBadge
            } else if hasScript {
                Text("Script ready")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
    }
    
    private var progressBadge: some View {
        Text("\(recordedScenesCount) of \(scenes.count) scenes recorded")
            .font(.caption.weight(.medium))
            .foregroundStyle(AppTheme.Colors.textSecondary)
    }
    
    // MARK: - Script Preview Card
    
    private var scriptPreviewCard: some View {
        Button {
            showingScriptEditor = true
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                if hasScript {
                    Text(scriptPreviewText)
                        .font(.body)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .lineLimit(4)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("No script yet. Tap to add one.")
                        .font(.body)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                HStack {
                    Text("Tap to edit")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.Colors.textTertiary)
                    
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textTertiary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppTheme.Colors.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var scriptPreviewText: String {
        let script = (currentProject.script ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if script.count <= 200 { return "\"\(script)\"" }
        let idx = script.index(script.startIndex, offsetBy: 200)
        return "\"\(String(script[..<idx]))...\""
    }
    
    // MARK: - Project Summary Row
    
    private var projectSummaryRow: some View {
        HStack(spacing: 12) {
            metadataChipButton(
                icon: "scope",
                text: currentProject.scriptIntent.map { intentShortLabel($0) } ?? "Intent"
            ) {
                showingIntentSheet = true
            }
            
            metadataChipButton(
                icon: "clock",
                text: currentProject.expectedDurationSeconds.map { durationLabel($0) } ?? "Duration"
            ) {
                showingDurationSheet = true
            }
            
            metadataChipButton(
                icon: "theatermasks",
                text: currentProject.toneMood?.displayTitle ?? "Tone"
            ) {
                showingToneSheet = true
            }
            
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
    
    private func metadataChipButton(icon: String, text: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.textTertiary)
                
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppTheme.Colors.surface, in: Capsule())
            .overlay(
                Capsule().stroke(AppTheme.Colors.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func intentShortLabel(_ intent: ScriptIntent) -> String {
        switch intent {
        case .explain: return "Explain"
        case .promote: return "Promote"
        case .storytelling: return "Storytelling"
        case .educate: return "Educate"
        case .entertainment: return "Entertainment"
        case .corporate: return "Corporate"
        }
    }
    
    private func durationLabel(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds)s"
        } else {
            let minutes = seconds / 60
            let remaining = seconds % 60
            return remaining > 0 ? "\(minutes)m \(remaining)s" : "\(minutes)m"
        }
    }
    
    // MARK: - Actions Section
    
    private var actionsSection: some View {
        VStack(spacing: 12) {
            if hasScenes {
                // State: Scenes generated
                Button {
                    showingShoot = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                            .font(.body.weight(.semibold))
                        Text("Go to Shoot")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.Colors.cta)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                
                Button {
                    sceneBreakdownMode = .reviewExisting
                    showingSceneBreakdown = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.stack")
                            .font(.body.weight(.medium))
                        Text("Review Scenes")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.Colors.surface)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(AppTheme.Colors.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            } else {
                // State: No scenes yet - show Generate Scenes
                Button {
                    sceneBreakdownMode = .generateFromScript(replaceExisting: true)
                    showingSceneBreakdown = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.body.weight(.semibold))
                        Text("Generate Scenes")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.Colors.cta)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            
            if hasExports {
                NavigationLink {
                    ExportsScreen(projectID: currentProject.id)
                } label: {
                    HStack(spacing: 4) {
                        Text("View Exports")
                            .font(.subheadline.weight(.medium))
                        Image(systemName: "arrow.right")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(AppTheme.Colors.cta)
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
        }
    }
    
    // MARK: - Tip Section
    
    private var tipSection: some View {
        Text("Tip: \(ProjectDetailTips.sessionTip)")
            .font(.footnote)
            .foregroundStyle(AppTheme.Colors.textTertiary)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
    }
    
    // MARK: - Actions
    
    private func loadProjectAndScenes() {
        if let latest = projectStore.getProject(by: project.id) {
            currentProject = latest
            editedTitle = latest.title
        }
        scenes = sceneStore.getScenes(for: currentProject)
        syncProjectStatus()
    }
    
    private func syncProjectStatus() {
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
    
    private func saveTitle() {
        let trimmed = editedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            editedTitle = currentProject.title
            isEditingTitle = false
            return
        }
        
        var updated = currentProject
        updated.title = trimmed
        do {
            try projectStore.updateProject(updated)
            currentProject = updated
        } catch {
            AppLogger.ui.error("Failed to update project title: \(error.localizedDescription)")
        }
        isEditingTitle = false
    }
    
    private func updateIntent(_ intent: ScriptIntent) {
        var updated = currentProject
        updated.scriptIntent = intent
        do {
            try projectStore.updateProject(updated)
            currentProject = updated
        } catch {
            AppLogger.ui.error("Failed to update project intent: \(error.localizedDescription)")
        }
    }
    
    private func updateDuration(_ duration: Int) {
        var updated = currentProject
        updated.expectedDurationSeconds = duration
        do {
            try projectStore.updateProject(updated)
            currentProject = updated
        } catch {
            AppLogger.ui.error("Failed to update project duration: \(error.localizedDescription)")
        }
    }
    
    private func updateTone(_ tone: ScriptToneMood) {
        var updated = currentProject
        updated.toneMood = tone
        do {
            try projectStore.updateProject(updated)
            currentProject = updated
        } catch {
            AppLogger.ui.error("Failed to update project tone: \(error.localizedDescription)")
        }
    }
    
    private func deleteProject() {
        do {
            try projectStore.deleteProject(currentProject)
            NotificationCenter.default.post(name: .projectDidDelete, object: nil)
            dismiss()
        } catch {
            deleteErrorMessage = error.localizedDescription
            showingDeleteError = true
            AppLogger.ui.error("Failed to delete project: \(error.localizedDescription)")
        }
    }
}

// MARK: - Intent Picker Sheet

private struct IntentPickerSheet: View {
    let selectedIntent: ScriptIntent?
    let onSelect: (ScriptIntent) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.background.ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("What's the goal of this video?")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                    
                    FlowLayout(spacing: 10) {
                        ForEach(ScriptIntent.allCases) { intent in
                            ChipButton(
                                title: intent.displayTitle,
                                isSelected: selectedIntent == intent
                            ) {
                                onSelect(intent)
                                dismiss()
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Intent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.Colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }
        }
        .tint(AppTheme.Colors.cta)
    }
}

// MARK: - Duration Picker Sheet

private struct DurationPickerSheet: View {
    let selectedDuration: Int?
    let onSelect: (Int) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    private var currentOption: DurationOption {
        DurationOption.from(seconds: selectedDuration)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.background.ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("Target video length")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                    
                    HStack(spacing: 8) {
                        ForEach(DurationOption.allCases, id: \.self) { option in
                            DurationChip(
                                title: option.label,
                                isSelected: currentOption == option
                            ) {
                                onSelect(option.secondsValue)
                                dismiss()
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Duration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.Colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }
        }
        .tint(AppTheme.Colors.cta)
    }
    
    private enum DurationOption: CaseIterable {
        case s30, s60, s90, m2, m3plus
        
        var label: String {
            switch self {
            case .s30: return "30s"
            case .s60: return "60s"
            case .s90: return "90s"
            case .m2: return "2m"
            case .m3plus: return "3m+"
            }
        }
        
        var secondsValue: Int {
            switch self {
            case .s30: return 30
            case .s60: return 60
            case .s90: return 90
            case .m2: return 120
            case .m3plus: return 180
            }
        }
        
        static func from(seconds: Int?) -> DurationOption {
            switch seconds {
            case 30: return .s30
            case 60, nil: return .s60
            case 90: return .s90
            case 120: return .m2
            default: return seconds ?? 60 >= 180 ? .m3plus : .s60
            }
        }
    }
}

// MARK: - Tone Picker Sheet

private struct TonePickerSheet: View {
    let selectedTone: ScriptToneMood?
    let onSelect: (ScriptToneMood) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.background.ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("What vibe are you going for?")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                    
                    FlowLayout(spacing: 10) {
                        ForEach(ScriptToneMood.allCases) { tone in
                            ChipButton(
                                title: tone.displayTitle,
                                isSelected: selectedTone == tone
                            ) {
                                onSelect(tone)
                                dismiss()
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Tone / Mood")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.Colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }
        }
        .tint(AppTheme.Colors.cta)
    }
}

// MARK: - Chip Components

private struct ChipButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isSelected ? AppTheme.Colors.textPrimary : AppTheme.Colors.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(isSelected ? AppTheme.Colors.cta.opacity(0.15) : AppTheme.Colors.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(isSelected ? AppTheme.Colors.cta.opacity(0.5) : AppTheme.Colors.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct DurationChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? AppTheme.Colors.textPrimary : AppTheme.Colors.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? AppTheme.Colors.cta.opacity(0.15) : AppTheme.Colors.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isSelected ? AppTheme.Colors.cta.opacity(0.5) : AppTheme.Colors.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Flow Layout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrangeSubviews(proposal: proposal, subviews: subviews).size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: .unspecified)
        }
    }
    
    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        
        let totalHeight = y + rowHeight
        return (CGSize(width: maxWidth, height: totalHeight), frames)
    }
}

// MARK: - Tips

private enum ProjectDetailTips {
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
        "You're in control — one scene at a time.",
    ]
    
    static let sessionTip: String = options.randomElement() ?? options[0]
}

// MARK: - Legacy Row Views (kept for compatibility)

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
