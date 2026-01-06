import SwiftUI

struct SettingsView: View {
    @AppStorage("refreshInterval") private var refreshInterval: Int = 30
    @AppStorage("showUnreadOnly") private var showUnreadOnly: Bool = false
    
    var body: some View {
        Form {
            Section("General") {
                Picker("Refresh Interval", selection: $refreshInterval) {
                    Text("15 minutes").tag(15)
                    Text("30 minutes").tag(30)
                    Text("1 hour").tag(60)
                    Text("Manual only").tag(0)
                }
                
                Toggle("Show Unread Only", isOn: $showUnreadOnly)
            }
            
            Section("About") {
                LabeledContent("Version", value: "1.0.0")
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 400, minHeight: 200)
        #if os(macOS)
        .padding()
        #endif
    }
}

#Preview {
    SettingsView()
}
