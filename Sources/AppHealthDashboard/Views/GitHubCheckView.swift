import SwiftUI

public struct GitHubCheckView: View {
    @EnvironmentObject var appState: AppState
    @State private var token = ""
    
    @State private var isRefreshing = false
    @State private var overallStatus: GitHubStatus? = nil
    @State private var workflowRuns: [GitHubWorkflowRun] = []
    @State private var errorMessage: String? = nil
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 5) {
                    Text("GitHub Monitor")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Monitor repository workflow runs and check GitHub platform health.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Form Card
                VStack(alignment: .leading, spacing: 15) {
                    Text("Repository & API Configuration")
                        .font(.headline)
                    
                    VStack(spacing: 12) {
                        HStack {
                            Text("Repository")
                                .frame(width: 85, alignment: .leading)
                            TextField("owner/repo (e.g. apple/swift)", text: $appState.selectedRepo)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        HStack {
                            Text("API Token")
                                .frame(width: 85, alignment: .leading)
                            SecureField("Personal Access Token (optional)", text: $token)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    
                    HStack {
                        Button(action: prePopulateSettings) {
                            Label("Load from Environment", systemImage: "arrow.down.doc.fill")
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(.accentColor)
                        
                        Spacer()
                        
                        Button(action: refreshAll) {
                            if isRefreshing {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("Refreshing...")
                                }
                            } else {
                                Label("Refresh Status", systemImage: "arrow.clockwise")
                            }
                        }
                        .disabled(isRefreshing || appState.selectedRepo.isEmpty)
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.top, 5)
                }
                .padding()
                .background(Color.themeCardBg)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.themeBorder, lineWidth: 1)
                )
                
                // Error Alert
                if let error = errorMessage {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.themeWarning)
                            .font(.title3)
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Spacer()
                        Button(action: { errorMessage = nil }) {
                            Image(systemName: "xmark")
                        }
                        .buttonStyle(.plain)
                    }
                    .padding()
                    .background(Color.themeWarning.opacity(0.1))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.themeWarning.opacity(0.3), lineWidth: 1)
                    )
                }
                
                // GitHub Platform Health Widget
                VStack(alignment: .leading, spacing: 10) {
                    Text("GitHub System Status")
                        .font(.headline)
                    
                    if let status = overallStatus {
                        let isGreen = status.indicator == "none"
                        let isYellow = status.indicator == "minor"
                        
                        HStack(spacing: 15) {
                            Circle()
                                .fill(isGreen ? Color.themeSuccess : (isYellow ? Color.themeWarning : Color.themeDanger))
                                .frame(width: 14, height: 14)
                                .shadow(color: (isGreen ? Color.themeSuccess : (isYellow ? Color.themeWarning : Color.themeDanger)).opacity(0.4), radius: 4)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(status.description)
                                    .fontWeight(.semibold)
                                Text("Indicator: \(status.indicator.capitalized)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            
                            Text(isGreen ? "Operational" : (isYellow ? "Warning" : "Outage"))
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(isGreen ? Color.themeSuccess : (isYellow ? Color.themeWarning : Color.themeDanger))
                                .cornerRadius(6)
                        }
                        .padding()
                        .background(Color.themeCardBg)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.themeBorder, lineWidth: 1)
                        )
                    } else {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text("Fetching system status...")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                        }
                        .padding()
                    }
                }
                
                // Workflow Runs Widget
                VStack(alignment: .leading, spacing: 10) {
                    Text("Recent Workflow Runs")
                        .font(.headline)
                    
                    if workflowRuns.isEmpty {
                        if isRefreshing {
                            HStack {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Fetching workflow runs...")
                                    .foregroundColor(.secondary)
                                    .font(.subheadline)
                            }
                            .padding()
                        } else {
                            Text("No workflow runs loaded. Verify the repository path and refresh.")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .center)
                                .background(Color.themeCardBg)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.themeBorder, lineWidth: 1)
                                )
                        }
                    } else {
                        VStack(spacing: 0) {
                            ForEach(workflowRuns) { run in
                                WorkflowRunRow(run: run)
                                
                                if run.id != workflowRuns.last?.id {
                                    Divider()
                                        .padding(.leading, 50)
                                }
                            }
                        }
                        .background(Color.themeCardBg)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.themeBorder, lineWidth: 1)
                        )
                    }
                }
            }
            .padding()
        }
        .onAppear {
            refreshAll()
        }
        .onChange(of: appState.selectedRepo) { oldValue, newValue in
            refreshAll()
        }
    }
    
    private func prePopulateSettings() {
        if let r = EnvReader.get("GITHUB_REPO") { appState.selectedRepo = r }
        if let t = EnvReader.get("GITHUB_TOKEN") { token = t }
    }
    
    private func refreshAll() {
        isRefreshing = true
        errorMessage = nil
        
        let monitor = GitHubMonitor(token: token.isEmpty ? nil : token)
        let repo = appState.selectedRepo
        
        Task {
            do {
                let status = try await monitor.fetchOverallStatus()
                let runs: [GitHubWorkflowRun]
                if !repo.isEmpty {
                    runs = try await monitor.fetchLatestWorkflowRuns(for: repo)
                } else {
                    runs = []
                }
                
                DispatchQueue.main.async {
                    withAnimation {
                        self.overallStatus = status
                        self.workflowRuns = runs
                        self.isRefreshing = false
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    withAnimation {
                        self.errorMessage = error.localizedDescription
                        self.isRefreshing = false
                    }
                }
            }
        }
    }
}

fileprivate struct WorkflowRunRow: View {
    let run: GitHubWorkflowRun
    
    var body: some View {
        HStack(spacing: 15) {
            // Status Icon
            statusIcon
                .font(.title2)
                .frame(width: 30)
            
            // Info
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(run.name ?? "Unnamed Workflow")
                        .fontWeight(.semibold)
                        .font(.body)
                        .lineLimit(1)
                    
                    Text("#\(run.runNumber)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }
                
                HStack(spacing: 12) {
                    // Branch
                    if let branch = run.headBranch {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.triangle.branch")
                            Text(branch)
                        }
                    }
                    
                    // Commit
                    if let sha = run.headSha {
                        HStack(spacing: 3) {
                            Image(systemName: "number")
                            Text(String(sha.prefix(7)))
                        }
                    }
                    
                    // Date
                    if let dateStr = run.createdAt {
                        HStack(spacing: 3) {
                            Image(systemName: "calendar")
                            Text(formatTimestamp(dateStr))
                        }
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // View Details Button
            Button(action: openRunDetails) {
                Image(systemName: "arrow.up.right.square")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Open workflow run in GitHub")
        }
        .padding()
        .contentShape(Rectangle())
        .onTapGesture {
            openRunDetails()
        }
    }
    
    private var statusIcon: some View {
        let conclusion = run.conclusion ?? ""
        let status = run.status
        
        if status == "in_progress" || status == "queued" {
            return AnyView(
                ProgressView()
                    .controlSize(.small)
            )
        } else if conclusion == "success" {
            return AnyView(
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.themeSuccess)
            )
        } else if conclusion == "failure" || conclusion == "startup_failure" {
            return AnyView(
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.themeDanger)
            )
        } else {
            return AnyView(
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.themeWarning)
            )
        }
    }
    
    private func formatTimestamp(_ timestamp: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: timestamp) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return timestamp
    }
    
    private func openRunDetails() {
        if let url = URL(string: run.htmlUrl) {
            #if os(macOS)
            NSWorkspace.shared.open(url)
            #endif
        }
    }
}
