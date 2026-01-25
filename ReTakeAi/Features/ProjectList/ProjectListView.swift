//
//  ProjectListView.swift
//  SceneFlow
//

import SwiftUI

private struct ShootDestination: Hashable {
    let projectID: UUID
}

private struct ExportsDestination: Hashable {
    let projectID: UUID
}

private struct SettingsDestination: Hashable {}

struct ProjectListView: View {
    @State private var viewModel = ProjectListViewModel()
    @State private var showingCreateSheet = false
    @State private var newProjectTitle = ""
    @FocusState private var isNewProjectTitleFocused: Bool
    @State private var emptyStateContent: EmptyStateContent.Content = EmptyStateContent.random()
    @State private var isKeyboardVisible = false
    @State private var navigationPath = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
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
            .navigationDestination(for: ShootDestination.self) { dest in
                ShootOverviewView(projectID: dest.projectID)
            }
            .navigationDestination(for: ExportsDestination.self) { dest in
                ExportsScreen(projectID: dest.projectID)
            }
            .navigationDestination(for: SettingsDestination.self) { _ in
                SettingsView()
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
        }
        .tint(AppTheme.Colors.cta)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
        .onAppear {
            // Ensure we never navigate with a stale Project value (draft/empty scenes).
            viewModel.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: .projectDidDelete)) { _ in
            viewModel.refresh()
        }
    }
    
    private var homeWithProjects: some View {
        ZStack {
            AppTheme.Colors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        topBar
                        
                        if let resume = viewModel.resumeProject {
                            resumeRecordingCard(for: resume)
                        }
                        
                        projectsSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 96)
                }
                .scrollIndicators(.hidden)
                .refreshable {
                    viewModel.refresh()
                }
                
                if !isKeyboardVisible {
                    tipHint
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                }
            }
            
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    floatingCreateButton
                        .padding(.trailing, 20)
                        .padding(.bottom, isKeyboardVisible ? 20 : 56)
                }
            }
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
                navigationPath.append(SettingsDestination())
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
        
        return NavigationLink(value: project) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text("🎬")
                        Text(project.title)
                            .lineLimit(1)
                    }
                    .font(.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    
                    Text("Scene \(max(1, progress.nextSceneNumber)) of \(progress.totalScenes) • Last edited \(project.updatedAt.timeAgo)")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
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
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppTheme.Colors.border, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
    
    private var projectsSection: some View {
        let resumeProjectID = viewModel.resumeProject?.id
        let filteredProjects = viewModel.projects.filter { $0.id != resumeProjectID }
        
        return VStack(spacing: 10) {
            ForEach(filteredProjects) { project in
                NavigationLink(value: project) {
                    ProjectHomeRowView(
                        project: project,
                        progress: viewModel.progress(for: project),
                        onExportsTap: {
                            navigationPath.append(ExportsDestination(projectID: project.id))
                        }
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var tipHint: some View {
        Text("Tip: \(TipContent.sessionTip)")
            .font(.footnote)
            .foregroundStyle(AppTheme.Colors.textTertiary)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
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
        navigationPath.append(ShootDestination(projectID: project.id))
    }
}

// MARK: - Home Project Row

private struct ProjectHomeRowView: View {
    let project: Project
    let progress: ProjectListViewModel.ProjectProgress
    var onExportsTap: (() -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(project.title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(1)
                
                Spacer(minLength: 0)
                
                statusChip
            }
            
            GeometryReader { geo in
                HStack(alignment: .bottom) {
                    StepProgressIndicator(progress: progress)
                        .frame(width: geo.size.width * 0.4, alignment: .leading)
                    
                    Spacer(minLength: 0)
                    
                    if progress.hasExport {
                        Button {
                            onExportsTap?()
                        } label: {
                            HStack(spacing: 4) {
                                Text("View Exports")
                                    .font(.caption2.weight(.medium))
                                Image(systemName: "chevron.right")
                                    .font(.caption2.weight(.semibold))
                            }
                            .foregroundStyle(AppTheme.Colors.cta)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text(project.updatedAt.timeAgo)
                            .font(.caption2)
                            .foregroundStyle(AppTheme.Colors.textTertiary)
                    }
                }
            }
            .frame(height: 34)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.Colors.border, lineWidth: 1)
        )
    }
    
    private var statusText: String {
        if progress.hasExport {
            return "Exported"
        }
        if progress.isRecordComplete {
            return "Ready to export"
        }
        return "Draft"
    }
    
    private var statusChip: some View {
        Text(statusText)
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppTheme.Colors.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(AppTheme.Colors.background, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(AppTheme.Colors.border, lineWidth: 1)
            )
    }
}

// MARK: - Step Progress Indicator

private struct StepProgressIndicator: View {
    let progress: ProjectListViewModel.ProjectProgress
    
    private enum StepState {
        case completed
        case current
        case upcoming
    }
    
    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 0) {
                stepLabel("Script", state: scriptState)
                    .frame(maxWidth: .infinity, alignment: .leading)
                stepLabel("Record", state: recordState)
                    .frame(maxWidth: .infinity, alignment: .leading)
                stepLabel("Export", state: exportState)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            GeometryReader { geo in
                let w = geo.size.width
                let y = geo.size.height / 2
                let col = w / 3.0
                // Center dots under leading-aligned labels (fixed step titles).
                let nodeXInColumn = min(22.0, col / 2.0)
                let x1 = nodeXInColumn - 8.0
                let x2 = col + nodeXInColumn
                let x3 = (2.0 * col) + nodeXInColumn - 3.0
                
                ZStack {
                    Path { p in
                        p.move(to: CGPoint(x: x1, y: y))
                        p.addLine(to: CGPoint(x: x2, y: y))
                    }
                    .stroke(connectorColor(from: scriptState, to: recordState), lineWidth: 1)
                    
                    Path { p in
                        p.move(to: CGPoint(x: x2, y: y))
                        p.addLine(to: CGPoint(x: x3, y: y))
                    }
                    .stroke(connectorColor(from: recordState, to: exportState), lineWidth: 1)
                    
                    stepNode(state: scriptState)
                        .position(x: x1, y: y)
                    
                    stepNode(state: recordState)
                        .position(x: x2, y: y)
                    
                    stepNode(state: exportState)
                        .position(x: x3, y: y)
                }
            }
            .frame(height: 12)
        }
        .font(.caption2)
        .accessibilityLabel(accessibilityText)
    }
    
    private var scriptState: StepState {
        progress.hasScript ? .completed : .current
    }
    
    private var recordState: StepState {
        if !progress.hasScript { return .upcoming }
        if progress.isRecordComplete { return .completed }
        return .current
    }
    
    private var exportState: StepState {
        if progress.hasExport { return .completed }
        if progress.hasScript && progress.isRecordComplete { return .current }
        return .upcoming
    }
    
    private func stepLabel(_ text: String, state: StepState) -> some View {
        Text(text)
            .foregroundStyle(colorFor(state))
            .fontWeight(weightFor(state))
    }
    
    private func stepNode(state: StepState) -> some View {
        Group {
            switch state {
            case .completed:
                ZStack {
                    Circle()
                        .fill(AppTheme.Colors.background)
                    Circle()
                        .stroke(AppTheme.Colors.border, lineWidth: 1)
                    Image(systemName: "checkmark")
                        .font(.system(size: 7, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                .frame(width: 12, height: 12)
            case .current:
                Circle()
                    .fill(AppTheme.Colors.textSecondary)
                    .frame(width: 10, height: 10)
            case .upcoming:
                Circle()
                    .stroke(AppTheme.Colors.textTertiary, lineWidth: 1.25)
                    .frame(width: 10, height: 10)
            }
        }
        .accessibilityHidden(true)
    }
    
    private func stepConnector(from left: StepState, to right: StepState) -> some View {
        Rectangle()
            .fill(connectorColor(from: left, to: right))
            .frame(height: 1)
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
    }
    
    private func connectorColor(from left: StepState, to right: StepState) -> Color {
        if left == .completed && (right == .completed || right == .current) {
            return AppTheme.Colors.textTertiary
        }
        return AppTheme.Colors.border
    }
    
    private func colorFor(_ state: StepState) -> Color {
        switch state {
        case .completed: return AppTheme.Colors.textSecondary
        case .current: return AppTheme.Colors.textSecondary
        case .upcoming: return AppTheme.Colors.textTertiary
        }
    }
    
    private func weightFor(_ state: StepState) -> Font.Weight {
        switch state {
        case .completed: return .regular
        case .current: return .medium
        case .upcoming: return .regular
        }
    }
    
    private var accessibilityText: String {
        let script = progress.hasScript ? "complete" : "current"
        let record = progress.isRecordComplete ? "complete" : (progress.hasScript ? "current" : "upcoming")
        let export = progress.hasExport ? "complete" : (progress.hasScript && progress.isRecordComplete ? "current" : "upcoming")
        return "Script \(script), Record \(record), Export \(export)"
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
    
    // Selected once per cold start, stays constant for the entire app session.
    static let sessionTip: String = options.randomElement() ?? options[0]
}

// MARK: - ProjectListView (continued)

extension ProjectListView {
    private var createProjectSheet: some View {
        CreateProjectOnboardingSheet(
            onCancel: {
                showingCreateSheet = false
            },
            onCreate: { title, intent, durationSeconds, toneMood in
                viewModel.errorMessage = nil
                if let newProject = viewModel.createProject(
                    title: title,
                    scriptIntent: intent,
                    expectedDurationSeconds: durationSeconds,
                    toneMood: toneMood
                ) {
                    showingCreateSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        navigationPath.append(newProject)
                    }
                }
            }
        )
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

private struct CreateProjectOnboardingSheet: View {
    let onCancel: () -> Void
    let onCreate: (_ title: String, _ intent: ScriptIntent?, _ durationSeconds: Int?, _ toneMood: ScriptToneMood?) -> Void
    
    @State private var title: String = ""
    @State private var selectedIntent: VideoIntent = .socialContent
    @State private var otherIntentText: String = ""
    @State private var duration: TargetDuration = .s60
    @State private var tone: ToneOption = .professional
    
    @FocusState private var isTitleFocused: Bool
    @FocusState private var isOtherIntentFocused: Bool
    
    private var isCreateEnabled: Bool { !trimmedTitle.isEmpty }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 28) {
                            // MARK: - Step 1: Project Name
                            sectionCard {
                                VStack(alignment: .leading, spacing: 14) {
                                    sectionHeader(number: 1, title: "Project Name")
                                    
                                    TextField("e.g., Product Launch Video", text: $title)
                                        .font(.body)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 14)
                                        .background(AppTheme.Colors.background)
                                        .foregroundStyle(AppTheme.Colors.textPrimary)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(isTitleFocused ? AppTheme.Colors.cta.opacity(0.6) : AppTheme.Colors.border, lineWidth: 1)
                                        )
                                        .textInputAutocapitalization(.words)
                                        .submitLabel(.next)
                                        .focused($isTitleFocused)
                                        .onSubmit { isTitleFocused = false }
                                }
                            }
                            
                            // MARK: - Step 2: Video Intent
                            sectionCard {
                                VStack(alignment: .leading, spacing: 14) {
                                    sectionHeader(number: 2, title: "Video Intent")
                                    
                                    FlowLayout(spacing: 10) {
                                        ForEach(VideoIntent.allCases, id: \.self) { intent in
                                            ChipButton(
                                                title: intent.title,
                                                isSelected: selectedIntent == intent
                                            ) {
                                                withAnimation(.easeInOut(duration: 0.15)) {
                                                    selectedIntent = intent
                                                    if intent != .other {
                                                        otherIntentText = ""
                                                        isOtherIntentFocused = false
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    
                                    if selectedIntent == .other {
                                        TextField("Describe your intent", text: $otherIntentText)
                                            .font(.subheadline)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 12)
                                            .background(AppTheme.Colors.background)
                                            .foregroundStyle(AppTheme.Colors.textPrimary)
                                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                    .stroke(AppTheme.Colors.border, lineWidth: 1)
                                            )
                                            .submitLabel(.done)
                                            .focused($isOtherIntentFocused)
                                            .transition(.opacity.combined(with: .move(edge: .top)))
                                    }
                                }
                            }
                            
                            // MARK: - Step 3: Duration
                            sectionCard {
                                VStack(alignment: .leading, spacing: 14) {
                                    sectionHeader(number: 3, title: "Target Duration")
                                    
                                    HStack(spacing: 8) {
                                        ForEach(TargetDuration.allCases, id: \.self) { d in
                                            DurationChip(
                                                title: d.label,
                                                isSelected: duration == d
                                            ) {
                                                withAnimation(.easeInOut(duration: 0.15)) {
                                                    duration = d
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // MARK: - Step 4: Tone
                            sectionCard {
                                VStack(alignment: .leading, spacing: 14) {
                                    sectionHeader(number: 4, title: "Vibe")
                                    
                                    FlowLayout(spacing: 10) {
                                        ForEach(ToneOption.allCases, id: \.self) { option in
                                            ChipButton(
                                                title: option.displayTitle,
                                                isSelected: tone == option
                                            ) {
                                                withAnimation(.easeInOut(duration: 0.15)) {
                                                    tone = option
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 100)
                    }
                    
                    // MARK: - Bottom CTA
                    VStack(spacing: 0) {
                        Divider()
                            .overlay(AppTheme.Colors.border.opacity(0.5))
                        
                        Button {
                            onCreate(trimmedTitle, selectedIntent.mappedScriptIntent, duration.secondsValue, tone.mappedToneMood)
                        } label: {
                            Text("Create Project")
                                .font(.headline)
                                .foregroundStyle(isCreateEnabled ? .white : AppTheme.Colors.textTertiary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(isCreateEnabled ? AppTheme.Colors.cta : AppTheme.Colors.surface)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(AppTheme.Colors.border.opacity(isCreateEnabled ? 0 : 1), lineWidth: 1)
                                )
                        }
                        .disabled(!isCreateEnabled)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(AppTheme.Colors.background)
                    }
                }
            }
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.Colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }
            .onAppear {
                DispatchQueue.main.async {
                    isTitleFocused = true
                }
            }
        }
        .tint(AppTheme.Colors.cta)
    }
    
    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    @ViewBuilder
    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    @ViewBuilder
    private func sectionHeader(number: Int, title: String) -> some View {
        HStack(spacing: 10) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.Colors.cta)
                .frame(width: 22, height: 22)
                .background(AppTheme.Colors.cta.opacity(0.15))
                .clipShape(Circle())
            
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
    }
    
    private enum VideoIntent: CaseIterable, Hashable {
        case marketingAd
        case tutorialHowTo
        case productDemo
        case storytelling
        case socialContent
        case other
        
        var title: String {
            switch self {
            case .marketingAd: return "Marketing / Ad"
            case .tutorialHowTo: return "Tutorial / How-to"
            case .productDemo: return "Product Demo"
            case .storytelling: return "Storytelling"
            case .socialContent: return "Social Content"
            case .other: return "Other"
            }
        }
        
        var mappedScriptIntent: ScriptIntent? {
            switch self {
            case .marketingAd: return .promote
            case .tutorialHowTo: return .educate
            case .productDemo: return .explain
            case .storytelling: return .storytelling
            case .socialContent: return .entertainment
            case .other: return .corporate
            }
        }
    }
    
    private enum TargetDuration: CaseIterable, Hashable {
        case s30
        case s60
        case s90
        case m2
        case m3plus
        
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
    }
    
    private enum ToneOption: CaseIterable, Hashable {
        case professional
        case casual
        case energetic
        case friendly
        case serious
        
        var displayTitle: String {
            switch self {
            case .professional: return "💼 Professional"
            case .casual: return "😊 Casual"
            case .energetic: return "⚡ Energetic"
            case .friendly: return "🤝 Friendly"
            case .serious: return "🎯 Serious"
            }
        }
        
        var mappedToneMood: ScriptToneMood? {
            switch self {
            case .professional: return .professional
            case .casual: return .calm
            case .energetic: return .energetic
            case .friendly: return .fun
            case .serious: return .serious
            }
        }
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
                        .fill(isSelected ? AppTheme.Colors.cta.opacity(0.15) : AppTheme.Colors.background)
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
                        .fill(isSelected ? AppTheme.Colors.cta.opacity(0.15) : AppTheme.Colors.background)
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
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
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
