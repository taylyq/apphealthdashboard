import Foundation

public struct GitHubWorkflowRun: Identifiable, Codable {
    public let id: Int
    public let name: String?
    public let runNumber: Int
    public let status: String
    public let conclusion: String?
    public let htmlUrl: String
    public let headBranch: String?
    public let headSha: String?
    public let createdAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case runNumber = "run_number"
        case status
        case conclusion
        case htmlUrl = "html_url"
        case headBranch = "head_branch"
        case headSha = "head_sha"
        case createdAt = "created_at"
    }
    
    public var displayStatus: String {
        if status == "completed" {
            if let conclusion = conclusion {
                return conclusion.replacingOccurrences(of: "_", with: " ").capitalized
            }
            return "Completed"
        }
        return status.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

public struct GitHubStatus: Codable {
    public let indicator: String
    public let description: String
}

public struct GitHubStatusResponse: Codable {
    public let status: GitHubStatus
}

public class GitHubMonitor {
    private let token: String?
    
    public init(token: String? = nil) {
        self.token = token ?? EnvReader.get("GITHUB_TOKEN")
    }
    
    /// Retrieve the latest workflow runs of a specified repository.
    /// - Parameter repo: The target repository in 'owner/repo' format (e.g. apple/swift).
    public func fetchLatestWorkflowRuns(for repo: String) async throws -> [GitHubWorkflowRun] {
        let repoString = repo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !repoString.isEmpty else {
            throw NSError(domain: "GitHubMonitor", code: 400, userInfo: [NSLocalizedDescriptionKey: "Repository path is empty."])
        }
        
        let urlString = "https://api.github.com/repos/\(repoString)/actions/runs?per_page=10"
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "GitHubMonitor", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid repository URL."])
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("AppHealthDashboard/1.0", forHTTPHeaderField: "User-Agent")
        
        if let token = self.token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "GitHubMonitor", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response from GitHub API."])
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw NSError(domain: "GitHubMonitor", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "GitHub API error: \(errorMsg)"])
        }
        
        let decoder = JSONDecoder()
        let result = try decoder.decode(GitHubWorkflowRunsResponse.self, from: data)
        return result.workflowRuns
    }
    
    /// Query the public GitHub status endpoint to get the current overall service status.
    public func fetchOverallStatus() async throws -> GitHubStatus {
        guard let url = URL(string: "https://www.githubstatus.com/api/v2/status.json") else {
            throw NSError(domain: "GitHubMonitor", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid GitHub Status URL."])
        }
        
        var request = URLRequest(url: url)
        request.setValue("AppHealthDashboard/1.0", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "GitHubMonitor", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response from GitHub Status API."])
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NSError(domain: "GitHubMonitor", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "GitHub Status API returned HTTP \(httpResponse.statusCode)."])
        }
        
        let decoder = JSONDecoder()
        let result = try decoder.decode(GitHubStatusResponse.self, from: data)
        return result.status
    }
}

fileprivate struct GitHubWorkflowRunsResponse: Codable {
    let totalCount: Int
    let workflowRuns: [GitHubWorkflowRun]
    
    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case workflowRuns = "workflow_runs"
    }
}
