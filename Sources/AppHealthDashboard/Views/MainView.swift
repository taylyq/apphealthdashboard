import SwiftUI
import UniformTypeIdentifiers

public struct MainView: View {
    @StateObject private var appState = AppState()
    @State private var selectedTab: Tab? = .mysql
    
    enum Tab: Hashable {
        case mysql
        case github
        case security
    }
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            List {
                if !appState.activeAppPath.isEmpty {
                    Section(header: Text("Active App")) {
                        HStack(spacing: 8) {
                            Image(systemName: "app.dashed")
                                .foregroundColor(.accentColor)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(URL(fileURLWithPath: appState.activeAppPath).lastPathComponent)
                                    .fontWeight(.semibold)
                                    .font(.body)
                                    .lineLimit(1)
                                Text("Currently Monitored")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section(header: Text("Services")) {
                    NavigationLink(
                        destination: MySQLCheckView(),
                        tag: Tab.mysql,
                        selection: $selectedTab
                    ) {
                        Label("Hostinger MySQL", systemImage: "database.fill")
                    }
                    
                    NavigationLink(
                        destination: GitHubCheckView(),
                        tag: Tab.github,
                        selection: $selectedTab
                    ) {
                        Label("GitHub Status & CI", systemImage: "terminal.fill")
                    }
                }
                
                Section(header: Text("Security")) {
                    NavigationLink(
                        destination: AppSecurityView(),
                        tag: Tab.security,
                        selection: $selectedTab
                    ) {
                        Label("Integrity & XProtect", systemImage: "shield.checkered")
                    }
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 220)
            
            // Default view
            MySQLCheckView()
        }
        .environmentObject(appState)
        .frame(minWidth: 960, minHeight: 640)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 8) {
                    // App Selector Dropdown
                    Menu {
                        if appState.scanHistory.isEmpty {
                            Text("No Scan History")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(appState.scanHistory, id: \.self) { path in
                                Button(action: {
                                    appState.activeAppPath = path
                                }) {
                                    HStack {
                                        if appState.activeAppPath == path {
                                            Image(systemName: "checkmark")
                                        }
                                        Text(URL(fileURLWithPath: path).lastPathComponent)
                                    }
                                }
                            }
                            
                            Divider()
                        }
                        
                        Button(action: selectNewAppBundle) {
                            Label("Browse App...", systemImage: "folder.badge.plus")
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "app.dashed")
                                .foregroundColor(.accentColor)
                            Text(appState.activeAppPath.isEmpty ? "Select App..." : URL(fileURLWithPath: appState.activeAppPath).lastPathComponent)
                                .fontWeight(.medium)
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .frame(minWidth: 150, maxWidth: 250)
                    
                    if !appState.activeAppPath.isEmpty {
                        Button(action: {
                            appState.runSecurityScan()
                        }) {
                            if appState.isScanningSecurity {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                        .help("Refresh security scan")
                        .disabled(appState.isScanningSecurity)
                    }
                }
            }
        }
    }
    
    private func selectNewAppBundle() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [UTType(filenameExtension: "app")].compactMap { $0 }
        panel.title = "Select a Mac App Bundle"
        panel.message = "Choose a .app bundle to monitor."
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                appState.activeAppPath = url.path
            }
        }
    }
}
