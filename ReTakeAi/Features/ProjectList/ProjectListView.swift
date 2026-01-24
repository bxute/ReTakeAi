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
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.hasProjects {
                    projectsList
                } else {
                    emptyState
                }
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
        .onAppear {
            // Ensure we never navigate with a stale Project value (draft/empty scenes).
            viewModel.refresh()
        }
    }
    
    private var projectsList: some View {
        List {
            ForEach(viewModel.projects) { project in
                NavigationLink(value: project) {
                    ProjectRowView(project: project)
                }
                .listRowBackground(AppTheme.Colors.surface)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        viewModel.deleteProject(project)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .tint(AppTheme.Colors.destructive)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AppTheme.Colors.background)
        .navigationDestination(for: Project.self) { project in
            ProjectDetailView(project: project)
        }
        .refreshable {
            viewModel.refresh()
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
