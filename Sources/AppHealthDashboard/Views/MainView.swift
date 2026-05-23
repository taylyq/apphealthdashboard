import SwiftUI

public struct MainView: View {
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
        .frame(minWidth: 960, minHeight: 640)
    }
}
