//
//  ProjectListView.swift
//  SceneFlow
//

import SwiftUI

struct ProjectListView: View {
    @State private var viewModel = ProjectListViewModel()
    @State private var showingCreateSheet = false
    @State private var newProjectTitle = ""
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.hasProjects {
                    projectsList
                } else {
                    emptyState
                }
            }
            .navigationTitle("Projects")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreateSheet = true
                    } label: {
                        Label("New Project", systemImage: "plus")
                    }
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
    }
    
    private var projectsList: some View {
        List {
            ForEach(viewModel.projects) { project in
                NavigationLink(value: project) {
                    ProjectRowView(project: project)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        viewModel.deleteProject(project)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .navigationDestination(for: Project.self) { project in
            ProjectDetailView(project: project)
        }
        .refreshable {
            viewModel.refresh()
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "video.bubble")
                .font(.system(size: 72))
                .foregroundColor(.secondary)
            
            Text("No Projects Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Create your first video project to get started")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                showingCreateSheet = true
            } label: {
                Label("Create Project", systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
    }
    
    private var createProjectSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Project Title", text: $newProjectTitle)
                }
                
                Section {
                    Button("Create") {
                        viewModel.createProject(title: newProjectTitle)
                        newProjectTitle = ""
                        showingCreateSheet = false
                    }
                    .disabled(newProjectTitle.isEmpty)
                }
            }
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingCreateSheet = false
                        newProjectTitle = ""
                    }
                }
            }
        }
    }
}

struct ProjectRowView: View {
    let project: Project
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(project.title)
                .font(.headline)
            
            HStack {
                StatusBadge(status: project.status)
                
                Spacer()
                
                Text(project.updatedAt.timeAgo)
                    .font(.caption)
                    .foregroundColor(.secondary)
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
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .cornerRadius(6)
    }
    
    private var statusColor: Color {
        switch status {
        case .draft: return .gray
        case .recording: return .blue
        case .completed: return .green
        case .exported: return .purple
        }
    }
}

#Preview {
    ProjectListView()
}
