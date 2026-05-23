import SwiftUI
import Combine

public class AppState: ObservableObject {
    @Published public var selectedRepo: String = ""
    
    // MySQL credentials
    @Published public var dbHost: String = ""
    @Published public var dbPort: String = "3306"
    @Published public var dbUser: String = ""
    @Published public var dbPass: String = ""
    @Published public var dbName: String = ""
    
    public init() {
        EnvReader.load()
        self.selectedRepo = EnvReader.get("GITHUB_REPO") ?? ""
        self.dbHost = EnvReader.get("DB_HOST") ?? ""
        self.dbPort = EnvReader.get("DB_PORT") ?? "3306"
        self.dbUser = EnvReader.get("DB_USER") ?? ""
        self.dbPass = EnvReader.get("DB_PASSWORD") ?? ""
        self.dbName = EnvReader.get("DB_NAME") ?? ""
    }
}
