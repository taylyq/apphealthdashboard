import SwiftUI

extension Color {
    public static let themeSuccess = Color(red: 0.09, green: 0.69, blue: 0.44) // Emerald Green
    public static let themeWarning = Color(red: 0.96, green: 0.62, blue: 0.15) // Amber Yellow
    public static let themeDanger = Color(red: 0.88, green: 0.26, blue: 0.33)  // Rose Red
    public static let themeInfo = Color(red: 0.12, green: 0.53, blue: 0.90)    // Soft Blue
    
    public static var themeBackground: Color {
        #if os(macOS)
        return Color(NSColor.windowBackgroundColor)
        #else
        return Color(UIColor.systemBackground)
        #endif
    }
    
    public static var themeCardBg: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor).opacity(0.85)
        #else
        return Color(UIColor.secondarySystemBackground).opacity(0.85)
        #endif
    }
    
    public static var themeBorder: Color {
        #if os(macOS)
        return Color(NSColor.separatorColor)
        #else
        return Color(UIColor.separator)
        #endif
    }
}
