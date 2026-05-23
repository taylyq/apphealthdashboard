import Foundation
import Security

public struct YaraMatch: Codable {
    public let rule: String
    public let path: String
}

public struct SecurityScanResult: Codable {
    public let path: String
    public let isSigned: Bool
    public let signatureValid: Bool
    public let signatureStatus: Int32
    public let teamID: String?
    public let signingIdentifier: String?
    public let entitlements: [String: String]?
    public let isSandboxed: Bool
    public let notarizationStatus: String // "Accepted", "Rejected", "Unknown"
    public let notarizationMessage: String?
    public let malwareScanMessage: String
    public let yaraMatches: [YaraMatch]
}

public class AppSecurityScanner {
    
    public init() {}
    
    /// Scans a macOS app bundle at the given path.
    public func scan(bundlePath: String) async -> SecurityScanResult {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: bundlePath) else {
            return SecurityScanResult(
                path: bundlePath,
                isSigned: false,
                signatureValid: false,
                signatureStatus: -1,
                teamID: nil,
                signingIdentifier: nil,
                entitlements: nil,
                isSandboxed: false,
                notarizationStatus: "Unknown",
                notarizationMessage: "Bundle path does not exist on disk.",
                malwareScanMessage: "Scan not executed.",
                yaraMatches: []
            )
        }
        
        // 1. Signature and entitlements via Security Framework
        let (isSigned, signatureValid, signatureStatus, teamID, signingIdentifier, entitlements, isSandboxed) = checkSignatureAndEntitlements(bundlePath: bundlePath)
        
        // 2. Notarization status via spctl
        let (notarizationStatus, notarizationMessage) = await checkNotarization(bundlePath: bundlePath)
        
        // 3. Malware check via XProtect YARA rules
        let (malwareMessage, yaraMatches) = await runYaraMalwareScan(bundlePath: bundlePath)
        
        return SecurityScanResult(
            path: bundlePath,
            isSigned: isSigned,
            signatureValid: signatureValid,
            signatureStatus: signatureStatus,
            teamID: teamID,
            signingIdentifier: signingIdentifier,
            entitlements: entitlements,
            isSandboxed: isSandboxed,
            notarizationStatus: notarizationStatus,
            notarizationMessage: notarizationMessage,
            malwareScanMessage: malwareMessage,
            yaraMatches: yaraMatches
        )
    }
    
    private func checkSignatureAndEntitlements(bundlePath: String) -> (
        isSigned: Bool,
        signatureValid: Bool,
        signatureStatus: Int32,
        teamID: String?,
        signingIdentifier: String?,
        entitlements: [String: String]?,
        isSandboxed: Bool
    ) {
        let url = URL(fileURLWithPath: bundlePath) as CFURL
        var staticCode: SecStaticCode?
        
        let createStatus = SecStaticCodeCreateWithPath(url, [], &staticCode)
        guard createStatus == errSecSuccess, let code = staticCode else {
            return (false, false, createStatus, nil, nil, nil, false)
        }
        
        // Check signing validity
        let validityStatus = SecStaticCodeCheckValidity(code, SecCSFlags(rawValue: 0), nil)
        let signatureValid = (validityStatus == errSecSuccess)
        
        var infoCF: CFDictionary?
        let infoStatus = SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &infoCF)
        
        guard infoStatus == errSecSuccess, let info = infoCF as? [String: Any] else {
            // Unsigned or unable to retrieve signing info
            return (false, signatureValid, infoStatus, nil, nil, nil, false)
        }
        
        let signingIdentifier = info[kSecCodeInfoIdentifier as String] as? String
        let teamID = info[kSecCodeInfoTeamIdentifier as String] as? String
        
        var entitlementsMap: [String: String]? = nil
        var isSandboxed = false
        
        if let entitlements = info[kSecCodeInfoEntitlementsDict as String] as? [String: Any] {
            var tempMap: [String: String] = [:]
            for (key, value) in entitlements {
                tempMap[key] = "\(value)"
            }
            entitlementsMap = tempMap
            isSandboxed = entitlements["com.apple.security.app-sandbox"] as? Bool ?? false
        }
        
        // A signingIdentifier is present if the app is signed
        let isSigned = (signingIdentifier != nil)
        
        return (isSigned, signatureValid, validityStatus, teamID, signingIdentifier, entitlementsMap, isSandboxed)
    }
    
    private func checkNotarization(bundlePath: String) async -> (status: String, message: String?) {
        let spctlPath = "/usr/sbin/spctl"
        guard FileManager.default.fileExists(atPath: spctlPath) else {
            return ("Unknown", "spctl utility not found at /usr/sbin/spctl")
        }
        
        do {
            let result = try await runProcess(executable: spctlPath, arguments: ["-a", "-vvv", "-t", "install", bundlePath])
            let combinedOutput = result.stdout + "\n" + result.stderr
            
            if combinedOutput.contains("accepted") {
                return ("Accepted", combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines))
            } else if combinedOutput.contains("rejected") {
                return ("Rejected", combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines))
            } else {
                return ("Unknown", combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        } catch {
            return ("Unknown", "Failed to run spctl: \(error.localizedDescription)")
        }
    }
    
    private func runYaraMalwareScan(bundlePath: String) async -> (message: String, matches: [YaraMatch]) {
        // Find yara tool path
        let yaraPaths = ["/opt/homebrew/bin/yara", "/usr/local/bin/yara"]
        var selectedYaraPath: String? = nil
        for path in yaraPaths {
            if FileManager.default.fileExists(atPath: path) {
                selectedYaraPath = path
                break
            }
        }
        
        guard let yaraPath = selectedYaraPath else {
            return ("Warning: yara command-line tool is not installed.", [])
        }
        
        // Find XProtect.yara path
        let xprotectYaraPaths = [
            "/var/protected/xprotect/XProtect.bundle/Contents/Resources/XProtect.yara",
            "/Library/Apple/System/Library/CoreServices/XProtect.yara"
        ]
        var selectedXProtectYaraPath: String? = nil
        for path in xprotectYaraPaths {
            if FileManager.default.fileExists(atPath: path) {
                selectedXProtectYaraPath = path
                break
            }
        }
        
        guard let rulesPath = selectedXProtectYaraPath else {
            return ("Warning: XProtect.yara database file not found.", [])
        }
        
        do {
            // Run recursive yara scan: yara -r <rules_file> <target_bundle>
            let result = try await runProcess(executable: yaraPath, arguments: ["-r", rulesPath, bundlePath])
            
            let output = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if output.isEmpty {
                return ("No threats found. Malware scan completed successfully.", [])
            }
            
            // Parse rules output line-by-line: <rule_name> <file_path>
            let lines = output.components(separatedBy: .newlines)
            var matches: [YaraMatch] = []
            for line in lines {
                let parts = line.split(separator: " ", maxSplits: 1).map(String.init)
                if parts.count == 2 {
                    matches.append(YaraMatch(rule: parts[0], path: parts[1]))
                } else if !line.trimmingCharacters(in: .whitespaces).isEmpty {
                    matches.append(YaraMatch(rule: "UnknownRule", path: line))
                }
            }
            
            return ("Threats detected: \(matches.count) matches found.", matches)
            
        } catch {
            return ("Failed to run yara malware scan: \(error.localizedDescription)", [])
        }
    }
    
    private func runProcess(executable: String, arguments: [String]) async throws -> (status: Int32, stdout: String, stderr: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        
        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { proc in
                let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                
                let stdout = String(data: outData, encoding: .utf8) ?? ""
                let stderr = String(data: errData, encoding: .utf8) ?? ""
                
                continuation.resume(returning: (proc.terminationStatus, stdout, stderr))
            }
            
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
