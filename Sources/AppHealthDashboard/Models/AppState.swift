import SwiftUI
import Combine
import Foundation

@MainActor
public class AppState: ObservableObject {
    @Published public var selectedRepo: String = ""
    
    // MySQL credentials
    @Published public var dbHost: String = ""
    @Published public var dbPort: String = "3306"
    @Published public var dbUser: String = ""
    @Published public var dbPass: String = ""
    @Published public var dbName: String = ""
    
    // Active app bundle path being monitored
    @Published public var activeAppPath: String = "" {
        didSet {
            guard !activeAppPath.isEmpty else { return }
            UserDefaults.standard.set(activeAppPath, forKey: "com.taytay.AppHealthDashboard.activeAppPath")
            addToHistory(path: activeAppPath)
            
            if !loadConfig(for: activeAppPath) {
                autoDetectConfig(for: activeAppPath)
            } else {
                runSecurityScan()
            }
        }
    }
    
    // Shared security scan state and history
    @Published public var securityScanResult: SecurityScanResult? = nil
    @Published public var isScanningSecurity: Bool = false
    @Published public var scanHistory: [String] = []
    
    private var cancellables = Set<AnyCancellable>()
    private var isRestoring = false
    
    public init() {
        self.scanHistory = UserDefaults.standard.stringArray(forKey: "com.taytay.AppHealthDashboard.scanHistory") ?? []
        let savedPath = UserDefaults.standard.string(forKey: "com.taytay.AppHealthDashboard.activeAppPath") ?? ""
        
        // Setup observers to save automatically when credentials change
        Publishers.MergeMany(
            $selectedRepo.map { _ in () }.eraseToAnyPublisher(),
            $dbHost.map { _ in () }.eraseToAnyPublisher(),
            $dbPort.map { _ in () }.eraseToAnyPublisher(),
            $dbUser.map { _ in () }.eraseToAnyPublisher(),
            $dbPass.map { _ in () }.eraseToAnyPublisher(),
            $dbName.map { _ in () }.eraseToAnyPublisher()
        )
        .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
        .sink { [weak self] _ in
            guard let self = self, !self.isRestoring else { return }
            self.saveCurrentConfig()
        }
        .store(in: &cancellables)
        
        if !savedPath.isEmpty {
            self.activeAppPath = savedPath
            _ = loadConfig(for: savedPath)
            runSecurityScan()
        } else {
            // Fallback to local .env
            EnvReader.load()
            self.selectedRepo = EnvReader.get("GITHUB_REPO") ?? ""
            self.dbHost = EnvReader.get("DB_HOST") ?? ""
            self.dbPort = EnvReader.get("DB_PORT") ?? "3306"
            self.dbUser = EnvReader.get("DB_USER") ?? ""
            self.dbPass = EnvReader.get("DB_PASSWORD") ?? ""
            self.dbName = EnvReader.get("DB_NAME") ?? ""
        }
    }
    
    public func saveCurrentConfig() {
        guard !activeAppPath.isEmpty else { return }
        var allConfigs = UserDefaults.standard.dictionary(forKey: "com.taytay.AppHealthDashboard.appConfigs") as? [String: [String: String]] ?? [:]
        let config = [
            "repo": selectedRepo,
            "dbHost": dbHost,
            "dbPort": dbPort,
            "dbUser": dbUser,
            "dbPass": dbPass,
            "dbName": dbName
        ]
        allConfigs[activeAppPath] = config
        UserDefaults.standard.set(allConfigs, forKey: "com.taytay.AppHealthDashboard.appConfigs")
    }
    
    public func loadConfig(for path: String) -> Bool {
        let allConfigs = UserDefaults.standard.dictionary(forKey: "com.taytay.AppHealthDashboard.appConfigs") as? [String: [String: String]] ?? [:]
        if let config = allConfigs[path] {
            self.isRestoring = true
            self.selectedRepo = config["repo"] ?? ""
            self.dbHost = config["dbHost"] ?? ""
            self.dbPort = config["dbPort"] ?? "3306"
            self.dbUser = config["dbUser"] ?? ""
            self.dbPass = config["dbPass"] ?? ""
            self.dbName = config["dbName"] ?? ""
            self.isRestoring = false
            return true
        }
        return false
    }
    
    public func runSecurityScan() {
        guard !activeAppPath.isEmpty else { return }
        isScanningSecurity = true
        securityScanResult = nil
        
        let path = activeAppPath
        let scanner = AppSecurityScanner()
        Task {
            let res = await scanner.scan(bundlePath: path)
            await MainActor.run {
                guard self.activeAppPath == path else { return }
                self.securityScanResult = res
                self.isScanningSecurity = false
            }
        }
    }
    
    public func addToHistory(path: String) {
        var current = self.scanHistory.filter { $0 != path }
        current.insert(path, at: 0)
        if current.count > 10 {
            current = Array(current.prefix(10))
        }
        self.scanHistory = current
        UserDefaults.standard.set(current, forKey: "com.taytay.AppHealthDashboard.scanHistory")
    }
    
    public func clearHistory() {
        self.scanHistory = []
        UserDefaults.standard.removeObject(forKey: "com.taytay.AppHealthDashboard.scanHistory")
    }
    
    private func autoDetectConfig(for path: String) {
        let savedPath = path
        Task {
            let gitRepo = findGitRepo(for: savedPath)
            let envData = findAndLoadEnv(for: savedPath)
            
            await MainActor.run {
                guard self.activeAppPath == savedPath else { return }
                self.isRestoring = true
                
                if let gitRepo = gitRepo {
                    self.selectedRepo = gitRepo
                } else if let repo = envData["GITHUB_REPO"] {
                    self.selectedRepo = repo
                } else {
                    self.selectedRepo = ""
                }
                
                self.dbHost = envData["DB_HOST"] ?? ""
                self.dbPort = envData["DB_PORT"] ?? "3306"
                self.dbUser = envData["DB_USER"] ?? ""
                self.dbPass = envData["DB_PASSWORD"] ?? ""
                self.dbName = envData["DB_NAME"] ?? ""
                
                self.isRestoring = false
                self.saveCurrentConfig()
                self.runSecurityScan()
            }
        }
    }
    
    private func findGitRepo(for path: String) -> String? {
        let fileManager = FileManager.default
        var currentURL = URL(fileURLWithPath: path)
        
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
    
    private func findAndLoadEnv(for path: String) -> [String: String] {
        let fileManager = FileManager.default
        var currentURL = URL(fileURLWithPath: path)
        
        for _ in 0..<5 {
            let envFile = currentURL.appendingPathComponent(".env")
            if fileManager.fileExists(atPath: envFile.path) {
                return parseEnvFile(at: envFile.path)
            }
            currentURL = currentURL.deletingLastPathComponent()
            if currentURL.path == "/" || currentURL.path.isEmpty { break }
        }
        
        let bundleEnv = URL(fileURLWithPath: path).appendingPathComponent("Contents/Resources/.env")
        if fileManager.fileExists(atPath: bundleEnv.path) {
            return parseEnvFile(at: bundleEnv.path)
        }
        
        return [:]
    }
    
    private func parseEnvFile(at path: String) -> [String: String] {
        var env: [String: String] = [:]
        do {
            let content = try String(contentsOfFile: path, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
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
        } catch {
            print("Failed to read env file at \(path): \(error)")
        }
        return env
    }
}
