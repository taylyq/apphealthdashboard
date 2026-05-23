import Foundation

public struct EnvReader {
    private static var envVars: [String: String] = [:]
    
    @discardableResult
    public static func load(from filename: String = ".env") -> [String: String] {
        let fileManager = FileManager.default
        var urls: [URL] = []
        
        // 1. Current directory
        let currentDirURL = URL(fileURLWithPath: fileManager.currentDirectoryPath)
        urls.append(currentDirURL.appendingPathComponent(filename))
        
        // 2. App bundle's parent directory
        let bundleURL = Bundle.main.bundleURL
        urls.append(bundleURL.deletingLastPathComponent().appendingPathComponent(filename))
        
        // Also look at the bundle resources directory itself
        urls.append(bundleURL.appendingPathComponent(filename))
        
        for url in urls {
            if fileManager.fileExists(atPath: url.path) {
                do {
                    let content = try String(contentsOf: url, encoding: .utf8)
                    let parsed = parse(content)
                    for (key, value) in parsed {
                        envVars[key] = value
                        // Set in process environment using C's setenv
                        key.withCString { k in
                            value.withCString { v in
                                _ = setenv(k, v, 1)
                            }
                        }
                    }
                    return envVars
                } catch {
                    print("Error reading environment file at \(url.path): \(error)")
                }
            }
        }
        
        return envVars
    }
    
    public static func get(_ key: String) -> String? {
        if let val = envVars[key] {
            return val
        }
        return ProcessInfo.processInfo.environment[key]
    }
    
    private static func parse(_ content: String) -> [String: String] {
        var result: [String: String] = [:]
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }
            
            guard let equalIndex = trimmed.firstIndex(of: "=") else {
                continue
            }
            
            let key = String(trimmed[..<equalIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            var value = String(trimmed[trimmed.index(after: equalIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Strip quotes if they wrap the value
            if value.count >= 2 {
                if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
                   (value.hasPrefix("'") && value.hasSuffix("'")) {
                    value = String(value.dropFirst().dropLast())
                }
            }
            
            if !key.isEmpty {
                result[key] = value
            }
        }
        return result
    }
}
