import SwiftUI
import UniformTypeIdentifiers

public struct AppSecurityView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedAppPath: String = ""
    @State private var isDragging = false
    @State private var isScanning = false
    @State private var scanResult: SecurityScanResult? = nil
    @State private var scanHistory: [String] = []
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 5) {
                    Text("App Security & Integrity")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Verify macOS code signatures, notarization status, sandbox entitlements, and scan for malware threats.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Drag & Drop / Select App zone
                VStack(spacing: 15) {
                    VStack(spacing: 12) {
                        Image(systemName: "square.and.arrow.down.fill")
                            .font(.system(size: 40))
                            .foregroundColor(isDragging ? .accentColor : .secondary)
                        
                        Text(isDragging ? "Drop the App Bundle Here" : "Drag & Drop App Bundle Here")
                            .font(.headline)
                        
                        Text("or click Browse to choose a .app bundle")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
                    .background(isDragging ? Color.accentColor.opacity(0.08) : Color.themeCardBg)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(isDragging ? Color.accentColor : Color.themeBorder, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, miterLimit: 10, dash: [6, 4], dashPhase: 0))
                    )
                    .onDrop(of: [.fileURL], isTargeted: $isDragging) { providers in
                        guard let provider = providers.first else { return false }
                        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (item, error) in
                            var pathURL: URL? = nil
                            if let data = item as? Data {
                                pathURL = URL(dataRepresentation: data, relativeTo: nil)
                            } else if let url = item as? URL {
                                pathURL = url
                            }
                            
                            if let url = pathURL {
                                DispatchQueue.main.async {
                                    self.selectedAppPath = url.path
                                    self.runScan()
                                }
                            }
                        }
                        return true
                    }
                    
                    HStack {
                        if !selectedAppPath.isEmpty {
                            HStack {
                                Image(systemName: "app.dashed")
                                    .font(.title3)
                                    .foregroundColor(.accentColor)
                                Text(URL(fileURLWithPath: selectedAppPath).lastPathComponent)
                                    .fontWeight(.medium)
                                    .textSelection(.enabled)
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                        }
                        
                        Button(action: selectAppBundle) {
                            Label("Browse App...", systemImage: "folder.badge.plus")
                        }
                        .disabled(isScanning)
                        
                        if !selectedAppPath.isEmpty {
                            Button(action: runScan) {
                                if isScanning {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Label("Rescan", systemImage: "arrow.clockwise")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isScanning)
                        }
                    }
                }
                
                // History Section
                if !scanHistory.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("Recently Checked Apps", systemImage: "clock.arrow.circlepath")
                                .font(.headline)
                            Spacer()
                            Button(action: clearHistory) {
                                Text("Clear")
                                    .font(.caption)
                                    .foregroundColor(.themeDanger)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(scanHistory, id: \.self) { path in
                                    Button(action: {
                                        selectedAppPath = path
                                        runScan()
                                    }) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "app")
                                                .foregroundColor(.accentColor)
                                            Text(URL(fileURLWithPath: path).lastPathComponent)
                                                .fontWeight(.medium)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color.themeCardBg)
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(selectedAppPath == path ? Color.accentColor : Color.themeBorder, lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color.themeCardBg.opacity(0.4))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.themeBorder, lineWidth: 1)
                    )
                }
                
                // Scan loading state
                if isScanning {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Analyzing application bundle...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 40)
                } else if let result = scanResult {
                    // Result Content
                    VStack(alignment: .leading, spacing: 20) {
                        
                        // Overview Badge Row
                        HStack(spacing: 15) {
                            StatusIndicatorBadge(
                                title: "Code Signature",
                                icon: result.isSigned ? (result.signatureValid ? "checkmark.seal.fill" : "exclamationmark.shield.fill") : "xmark.shield.fill",
                                status: result.isSigned ? (result.signatureValid ? "Valid" : "Invalid") : "Unsigned",
                                color: result.isSigned ? (result.signatureValid ? .themeSuccess : .themeDanger) : .themeWarning
                            )
                            
                            StatusIndicatorBadge(
                                title: "Notarization",
                                icon: result.notarizationStatus == "Accepted" ? "checkmark.circle.fill" : (result.notarizationStatus == "Rejected" ? "xmark.circle.fill" : "questionmark.circle.fill"),
                                status: result.notarizationStatus,
                                color: result.notarizationStatus == "Accepted" ? .themeSuccess : (result.notarizationStatus == "Rejected" ? .themeDanger : .themeWarning)
                            )
                            
                            StatusIndicatorBadge(
                                title: "Sandbox",
                                icon: result.isSandboxed ? "lock.shield.fill" : "lock.open.fill",
                                status: result.isSandboxed ? "Sandboxed" : "Not Sandboxed",
                                color: result.isSandboxed ? .themeSuccess : .themeWarning
                            )
                            
                            StatusIndicatorBadge(
                                title: "Malware Clean",
                                icon: result.yaraMatches.isEmpty ? "shield.fill" : "exclamationmark.shield.fill",
                                status: result.yaraMatches.isEmpty ? "Clean" : "\(result.yaraMatches.count) threats",
                                color: result.yaraMatches.isEmpty ? .themeSuccess : .themeDanger
                            )
                        }
                        
                        // Detailed Section Cards
                        
                        // A: Code Signing Detailed Card
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Label("Code Signing & Certificates", systemImage: "signature")
                                    .font(.headline)
                                Spacer()
                                Text(result.isSigned ? "Signed" : "Unsigned")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(result.isSigned ? Color.themeSuccess : Color.themeWarning)
                                    .cornerRadius(4)
                            }
                            
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 8) {
                                InfoRow(label: "Signature Valid", value: result.signatureValid ? "Yes" : "No", valueColor: result.signatureValid ? .themeSuccess : .themeDanger)
                                InfoRow(label: "Signing Identifier", value: result.signingIdentifier ?? "N/A")
                                InfoRow(label: "Team ID", value: result.teamID ?? "N/A")
                                InfoRow(label: "Status Code", value: "\(result.signatureStatus)")
                            }
                        }
                        .padding()
                        .background(Color.themeCardBg)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.themeBorder, lineWidth: 1))
                        
                        // B: Notarization Info
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Label("Apple Notarization Status", systemImage: "applelogo")
                                    .font(.headline)
                                Spacer()
                                Text(result.notarizationStatus)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(result.notarizationStatus == "Accepted" ? Color.themeSuccess : (result.notarizationStatus == "Rejected" ? Color.themeDanger : Color.themeWarning))
                                    .cornerRadius(4)
                            }
                            
                            Divider()
                            
                            if let msg = result.notarizationMessage, !msg.isEmpty {
                                Text(msg)
                                    .font(.system(.subheadline, design: .monospaced))
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.secondary.opacity(0.05))
                                    .cornerRadius(6)
                                    .textSelection(.enabled)
                            } else {
                                Text("No notarization details available.")
                                    .foregroundColor(.secondary)
                                    .font(.subheadline)
                            }
                        }
                        .padding()
                        .background(Color.themeCardBg)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.themeBorder, lineWidth: 1))
                        
                        // C: Sandboxing & Entitlements
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Label("Sandbox & Entitlements", systemImage: "lock.shield")
                                    .font(.headline)
                                Spacer()
                                Text(result.isSandboxed ? "Sandboxed" : "Unsandboxed")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(result.isSandboxed ? Color.themeSuccess : Color.themeWarning)
                                    .cornerRadius(4)
                            }
                            
                            Divider()
                            
                            if let entitlements = result.entitlements, !entitlements.isEmpty {
                                Text("Entitlements List:")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(Array(entitlements.keys).sorted(), id: \.self) { key in
                                        HStack(alignment: .top) {
                                            Text(key)
                                                .font(.system(.caption, design: .monospaced))
                                                .foregroundColor(.primary)
                                                .textSelection(.enabled)
                                                .frame(width: 260, alignment: .leading)
                                            
                                            Spacer()
                                            
                                            Text(entitlements[key] ?? "")
                                                .font(.system(.caption, design: .monospaced))
                                                .foregroundColor(.secondary)
                                                .textSelection(.enabled)
                                                .frame(maxWidth: .infinity, alignment: .trailing)
                                        }
                                        .padding(.vertical, 2)
                                        Divider()
                                    }
                                }
                            } else {
                                Text("No entitlements found in signature.")
                                    .foregroundColor(.secondary)
                                    .font(.subheadline)
                            }
                        }
                        .padding()
                        .background(Color.themeCardBg)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.themeBorder, lineWidth: 1))
                        
                        // D: Malware Scanner Details
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Label("Malware Scan (YARA + XProtect Rules)", systemImage: "shield.fill")
                                    .font(.headline)
                                Spacer()
                                Text(result.yaraMatches.isEmpty ? "Pass" : "Threats Detected")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(result.yaraMatches.isEmpty ? Color.themeSuccess : Color.themeDanger)
                                    .cornerRadius(4)
                            }
                            
                            Divider()
                            
                            Text(result.malwareScanMessage)
                                .font(.subheadline)
                                .foregroundColor(result.yaraMatches.isEmpty ? .secondary : .themeDanger)
                            
                            if !result.yaraMatches.isEmpty {
                                Text("Matches:")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(result.yaraMatches.indices, id: \.self) { idx in
                                        let match = result.yaraMatches[idx]
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(match.rule)
                                                .font(.system(.subheadline, design: .monospaced))
                                                .foregroundColor(.themeDanger)
                                                .fontWeight(.bold)
                                            Text(match.path)
                                                .font(.system(.caption, design: .monospaced))
                                                .foregroundColor(.secondary)
                                                .textSelection(.enabled)
                                        }
                                        .padding(.vertical, 4)
                                        if idx < result.yaraMatches.count - 1 {
                                            Divider()
                                        }
                                    }
                                }
                                .padding(10)
                                .background(Color.themeDanger.opacity(0.05))
                                .cornerRadius(8)
                            }
                        }
                        .padding()
                        .background(Color.themeCardBg)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.themeBorder, lineWidth: 1))
                        
                    }
                    .transition(.slide.combined(with: .opacity))
                }
            }
            .padding()
        }
        .onAppear {
            loadHistory()
        }
    }
    
    private func selectAppBundle() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [UTType(filenameExtension: "app")].compactMap { $0 }
        panel.title = "Select a Mac App Bundle"
        panel.message = "Choose a .app bundle to run security and integrity scans."
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                self.selectedAppPath = url.path
                self.runScan()
            }
        }
    }
    
    private func runScan() {
        guard !selectedAppPath.isEmpty else { return }
        isScanning = true
        scanResult = nil
        
        addToHistory(path: selectedAppPath)
        
        // Auto-detect and switch GitHub repo if app is inside a Git repository
        if let gitRepo = findGitRepo(for: selectedAppPath) {
            DispatchQueue.main.async {
                withAnimation {
                    self.appState.selectedRepo = gitRepo
                }
            }
        }
        
        // Auto-detect and load MySQL credentials from a local .env file
        findAndLoadEnv(for: selectedAppPath)
        
        let scanner = AppSecurityScanner()
        Task {
            let res = await scanner.scan(bundlePath: selectedAppPath)
            DispatchQueue.main.async {
                withAnimation {
                    self.scanResult = res
                    self.isScanning = false
                }
            }
        }
    }
    
    private func loadHistory() {
        self.scanHistory = UserDefaults.standard.stringArray(forKey: "com.taytay.AppHealthDashboard.scanHistory") ?? []
    }
    
    private func addToHistory(path: String) {
        var current = self.scanHistory.filter { $0 != path }
        current.insert(path, at: 0)
        if current.count > 10 {
            current = Array(current.prefix(10))
        }
        self.scanHistory = current
        UserDefaults.standard.set(current, forKey: "com.taytay.AppHealthDashboard.scanHistory")
    }
    
    private func clearHistory() {
        withAnimation {
            self.scanHistory = []
            UserDefaults.standard.removeObject(forKey: "com.taytay.AppHealthDashboard.scanHistory")
        }
    }
    
    private func findGitRepo(for path: String) -> String? {
        let fileManager = FileManager.default
        var currentURL = URL(fileURLWithPath: path)
        
        // Traverse up the directory tree to find a .git folder
        for _ in 0..<5 {
            let gitDir = currentURL.appendingPathComponent(".git")
            if fileManager.fileExists(atPath: gitDir.path) {
                return runGitRemoteUrl(in: currentURL.path)
            }
            currentURL = currentURL.deletingLastPathComponent()
            if currentURL.path == "/" || currentURL.path.isEmpty { break }
        }
        return nil
    }
    
    private func runGitRemoteUrl(in directory: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["remote", "get-url", "origin"]
        process.currentDirectoryURL = URL(fileURLWithPath: directory)
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                return parseGitHubRepo(from: output)
            }
        } catch {
            print("Failed to run git remote get-url: \(error)")
        }
        return nil
    }
    
    private func parseGitHubRepo(from urlString: String) -> String? {
        var cleanUrl = urlString
        if cleanUrl.hasSuffix(".git") {
            cleanUrl = String(cleanUrl.dropLast(4))
        }
        
        if cleanUrl.contains("github.com") {
            if let range = cleanUrl.range(of: "github.com/") {
                let suffix = cleanUrl[range.upperBound...]
                return String(suffix)
            } else if let range = cleanUrl.range(of: "github.com:") {
                let suffix = cleanUrl[range.upperBound...]
                return String(suffix)
            }
        }
        return nil
    }
    
    private func findAndLoadEnv(for path: String) {
        let fileManager = FileManager.default
        var currentURL = URL(fileURLWithPath: path)
        
        // Traverse up the directory tree to find a .env file
        for _ in 0..<5 {
            let envFile = currentURL.appendingPathComponent(".env")
            if fileManager.fileExists(atPath: envFile.path) {
                loadEnvFile(at: envFile.path)
                return
            }
            currentURL = currentURL.deletingLastPathComponent()
            if currentURL.path == "/" || currentURL.path.isEmpty { break }
        }
        
        // Fallback: check inside bundle Contents/Resources/.env
        let bundleEnv = URL(fileURLWithPath: path).appendingPathComponent("Contents/Resources/.env")
        if fileManager.fileExists(atPath: bundleEnv.path) {
            loadEnvFile(at: bundleEnv.path)
        }
    }
    
    private func loadEnvFile(at path: String) {
        do {
            let content = try String(contentsOfFile: path, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
            var env: [String: String] = [:]
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
                let parts = trimmed.split(separator: "=", maxSplits: 1).map(String.init)
                if parts.count == 2 {
                    let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    var val = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    if (val.hasPrefix("\"") && val.hasSuffix("\"")) || (val.hasPrefix("'") && val.hasSuffix("'")) {
                        val = String(val.dropFirst().dropLast())
                    }
                    env[key] = val
                }
            }
            
            // Update AppState credentials
            DispatchQueue.main.async {
                withAnimation {
                    if let host = env["DB_HOST"] { self.appState.dbHost = host }
                    if let port = env["DB_PORT"] { self.appState.dbPort = port }
                    if let user = env["DB_USER"] { self.appState.dbUser = user }
                    if let pass = env["DB_PASSWORD"] { self.appState.dbPass = pass }
                    if let name = env["DB_NAME"] { self.appState.dbName = name }
                    
                    // Also reload repository if GITHUB_REPO is specified
                    if let repo = env["GITHUB_REPO"] { self.appState.selectedRepo = repo }
                }
            }
        } catch {
            print("Failed to load env file at \(path): \(error)")
        }
    }
}

fileprivate struct StatusIndicatorBadge: View {
    let title: String
    let icon: String
    let status: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            
            Text(status)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(color)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.themeCardBg)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.themeBorder, lineWidth: 1))
    }
}

fileprivate struct InfoRow: View {
    let label: String
    let value: String
    var valueColor: Color = .primary
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .foregroundColor(valueColor)
                .textSelection(.enabled)
        }
        .font(.subheadline)
    }
}
