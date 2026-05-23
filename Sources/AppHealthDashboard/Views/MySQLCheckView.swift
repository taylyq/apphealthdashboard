import SwiftUI

public struct MySQLCheckView: View {
    @EnvironmentObject var appState: AppState
    @State private var isTesting = false
    @State private var connectionResult: MySQLConnector.ConnectionResult? = nil
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 5) {
                    Text("MySQL Connection Tester")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Test and verify connections to your Hostinger MySQL database.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Form Card
                VStack(alignment: .leading, spacing: 15) {
                    Text("Database Credentials")
                        .font(.headline)
                    
                    VStack(spacing: 12) {
                        HStack {
                            Text("Host")
                                .frame(width: 80, alignment: .leading)
                            TextField("e.g. sql123.hostinger.com", text: $appState.dbHost)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        HStack {
                            Text("Port")
                                .frame(width: 80, alignment: .leading)
                            TextField("3306", text: $appState.dbPort)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        HStack {
                            Text("User")
                                .frame(width: 80, alignment: .leading)
                            TextField("Database user name", text: $appState.dbUser)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        HStack {
                            Text("Password")
                                .frame(width: 80, alignment: .leading)
                            SecureField("Database password", text: $appState.dbPass)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        HStack {
                            Text("Database")
                                .frame(width: 80, alignment: .leading)
                            TextField("Database name", text: $appState.dbName)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    
                    HStack {
                        Button(action: prePopulateCredentials) {
                            Label("Load from Environment", systemImage: "arrow.down.doc.fill")
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(.accentColor)
                        
                        Spacer()
                        
                        Button(action: testConnection) {
                            if isTesting {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("Testing...")
                                }
                            } else {
                                Label("Test Connection", systemImage: "play.fill")
                            }
                        }
                        .keyboardShortcut(.defaultAction)
                        .disabled(isTesting || appState.dbHost.isEmpty || appState.dbUser.isEmpty || appState.dbName.isEmpty)
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
                
                // Results Card
                if let result = connectionResult {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.title)
                                .foregroundColor(result.success ? .themeSuccess : .themeDanger)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.success ? "Connection Successful" : "Connection Failed")
                                    .font(.headline)
                                    .foregroundColor(result.success ? .themeSuccess : .themeDanger)
                                Text(result.success ? "Successfully connected to Hostinger MySQL." : "Unable to establish connection.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        
                        Divider()
                        
                        Text(result.message)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.primary)
                            .textSelection(.enabled)
                            .padding(.top, 4)
                    }
                    .padding()
                    .background(
                        (result.success ? Color.themeSuccess : Color.themeDanger)
                            .opacity(0.08)
                    )
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(result.success ? Color.themeSuccess.opacity(0.3) : Color.themeDanger.opacity(0.3), lineWidth: 1.5)
                    )
                    .transition(.slide.combined(with: .opacity))
                }
            }
            .padding()
        }
    }
    
    private func prePopulateCredentials() {
        if let h = EnvReader.get("DB_HOST") { appState.dbHost = h }
        if let p = EnvReader.get("DB_PORT") { appState.dbPort = p }
        if let u = EnvReader.get("DB_USER") { appState.dbUser = u }
        if let pwd = EnvReader.get("DB_PASSWORD") { appState.dbPass = pwd }
        if let db = EnvReader.get("DB_NAME") { appState.dbName = db }
    }
    
    private func testConnection() {
        let portVal = Int(appState.dbPort) ?? 3306
        isTesting = true
        connectionResult = nil
        
        Task {
            let res = await MySQLConnector.testConnection(
                host: appState.dbHost,
                port: portVal,
                username: appState.dbUser,
                password: appState.dbPass,
                database: appState.dbName
            )
            DispatchQueue.main.async {
                withAnimation {
                    self.connectionResult = res
                    self.isTesting = false
                }
            }
        }
    }
}
