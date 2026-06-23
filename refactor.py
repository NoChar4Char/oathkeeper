import re
import sys

filepath = '/Users/charlie/oathkeeper/Sources/Views/MainView.swift'

with open(filepath, 'r') as f:
    content = f.read()

# Replace State vars
content = re.sub(r'@State private var hostsResetMessage: String\? = nil\n\s*@State private var hostsResetSuccess = false',
                 r'', content)
content = re.sub(r'@State private var updateMessage: String\? = nil\n\s*@State private var updateMessageToken: UUID = UUID\(\)\n\s*@State private var hostsResetMessageToken: UUID = UUID\(\)\n\s*@State private var updateSuccess = false',
                 r'@State private var globalBannerMessage: String? = nil\n    @State private var globalBannerToken: UUID = UUID()\n    @State private var globalBannerSuccess = false', content)

# Remove the display of both messages and replace with one
display_logic = """            // Visual Banner for Recovery Status
            if let msg = hostsResetMessage {
                Text(msg)
                    .font(.caption2)
                    .foregroundColor(hostsResetSuccess ? .green : .red)
                    .fontWeight(.semibold)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 12)
                    .background(hostsResetSuccess ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                    .cornerRadius(6)
                    .transition(.opacity)
            }
            
            // Visual Banner for Update Status
            if let msg = updateMessage {
                Text(msg)
                    .font(.caption2)
                    .foregroundColor(updateSuccess ? .green : .red)
                    .fontWeight(.semibold)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 12)
                    .background(updateSuccess ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                    .cornerRadius(6)
                    .transition(.opacity)
            }"""

new_display_logic = """            // Global Visual Banner
            if let msg = globalBannerMessage {
                Text(msg)
                    .font(.caption2)
                    .foregroundColor(globalBannerSuccess ? .green : .red)
                    .fontWeight(.semibold)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 12)
                    .background(globalBannerSuccess ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                    .cornerRadius(6)
                    .transition(.opacity)
            }"""
content = content.replace(display_logic, new_display_logic)

# Make helper function
helper_func = """    private func showBanner(msg: String?, success: Bool) {
        let token = UUID()
        self.globalBannerToken = token
        self.globalBannerMessage = msg
        self.globalBannerSuccess = success
        if msg != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                if self.globalBannerToken == token {
                    self.globalBannerMessage = nil
                }
            }
        }
    }"""

content = content.replace('// MARK: - Helper Methods', '// MARK: - Helper Methods\n\n' + helper_func)

# Replace all explicit clears
content = re.sub(r'self\.hostsResetMessage = nil\n\s*', '', content)
content = re.sub(r'self\.updateMessage = nil\n\s*', '', content)
content = re.sub(r'hostsResetMessage = nil\n\s*', '', content)
content = re.sub(r'updateMessage = nil\n\s*', '', content)
content = re.sub(r'self\.updateMessageToken = token\n\s*', '', content)
content = re.sub(r'self\.hostsResetMessageToken = token\n\s*', '', content)
content = re.sub(r'let token = UUID\(\)\n\s*', '', content)

# Now manually replace the set messages
content = re.sub(r'hostsResetMessage = "Failed to obtain write permission. App blocking active."\s*hostsResetSuccess = false', r'showBanner(msg: "Failed to obtain write permission. App blocking active.", success: false)', content)
content = re.sub(r'hostsResetMessage = "Website blocking enabled successfully!"\s*hostsResetSuccess = true', r'showBanner(msg: "Website blocking enabled successfully!", success: true)', content)
content = re.sub(r'hostsResetMessage = "Failed to obtain permission."\s*hostsResetSuccess = false', r'showBanner(msg: "Failed to obtain permission.", success: false)', content)
content = re.sub(r'hostsResetMessage = "Cannot block Oathkeeper itself."\s*hostsResetSuccess = false', r'showBanner(msg: "Cannot block Oathkeeper itself.", success: false)', content)
content = re.sub(r'updateMessage = "Checking for updates..."\s*updateSuccess = false', r'showBanner(msg: "Checking for updates...", success: false)', content)
content = re.sub(r'updateMessage = "Invalid update URL."\s*updateSuccess = false', r'showBanner(msg: "Invalid update URL.", success: false)', content)

# URLSession block replacements
content = re.sub(r'self\.updateMessage = "Error: \\\(error\.localizedDescription\)"\n\s*self\.updateSuccess = false\n\s*DispatchQueue\.main\.asyncAfter\(deadline: \.now\(\) \+ 4\.0\) \{\n\s*if self\.updateMessageToken == token \{ self\.updateMessage = nil \}\n\s*\}', r'self.showBanner(msg: "Error: \\(error.localizedDescription)", success: false)', content)

content = re.sub(r'self\.updateMessage = "No response data\."\n\s*self\.updateSuccess = false\n\s*DispatchQueue\.main\.asyncAfter\(deadline: \.now\(\) \+ 4\.0\) \{\n\s*if self\.updateMessageToken == token \{ self\.updateMessage = nil \}\n\s*\}', r'self.showBanner(msg: "No response data.", success: false)', content)

content = re.sub(r'self\.updateMessage = "New version \\\(remoteTag\) is available!"\n\s*self\.updateSuccess = true\n\s*self\.updateAlertPresented = true', r'self.showBanner(msg: "New version \\(remoteTag) is available!", success: true)\n                        self.updateAlertPresented = true', content)

content = re.sub(r'self\.updateMessage = "Oathkeeper is up to date \(Version \\\(localVersion\)\)\."\n\s*self\.updateSuccess = true\n\s*DispatchQueue\.main\.asyncAfter\(deadline: \.now\(\) \+ 4\.0\) \{\n\s*if self\.updateMessageToken == token && self\.updateMessage == "Oathkeeper is up to date \(Version \\\(localVersion\)\)\." \{\n\s*self\.updateMessage = nil\n\s*\}\n\s*\}', r'self.showBanner(msg: "Oathkeeper is up to date (Version \\(localVersion)).", success: true)', content)

content = re.sub(r'self\.updateMessage = "Failed to parse update info\."\n\s*self\.updateSuccess = false\n\s*DispatchQueue\.main\.asyncAfter\(deadline: \.now\(\) \+ 4\.0\) \{\n\s*if self\.updateMessageToken == token \{ self\.updateMessage = nil \}\n\s*\}', r'self.showBanner(msg: "Failed to parse update info.", success: false)', content)

content = re.sub(r'updateMessage = "Downloading update..."\s*updateSuccess = false', r'showBanner(msg: "Downloading update...", success: false)', content)
content = re.sub(r'updateMessage = "Invalid download URL."\s*updateSuccess = false', r'showBanner(msg: "Invalid download URL.", success: false)', content)

content = re.sub(r'self\.updateMessage = "Download failed: \\\(error\.localizedDescription\)"\n\s*self\.updateSuccess = false', r'self.showBanner(msg: "Download failed: \\(error.localizedDescription)", success: false)', content)

content = re.sub(r'self\.updateMessage = "Temp download file not found\."\n\s*self\.updateSuccess = false', r'self.showBanner(msg: "Temp download file not found.", success: false)', content)

content = re.sub(r'self\.updateMessage = "Installing update..."', r'self.showBanner(msg: "Installing update...", success: true)', content)

content = re.sub(r'self\.updateMessage = "Failed to copy installer: \\\(error\.localizedDescription\)"\n\s*self\.updateSuccess = false', r'self.showBanner(msg: "Failed to copy installer: \\(error.localizedDescription)", success: false)', content)

content = re.sub(r'self\.updateMessage = "Failed to start installer script\."\n\s*self\.updateSuccess = false', r'self.showBanner(msg: "Failed to start installer script.", success: false)', content)

content = re.sub(r'hostsResetMessage = "Failed to obtain write permission\."\n\s*hostsResetSuccess = false', r'showBanner(msg: "Failed to obtain write permission.", success: false)', content)

content = re.sub(r'hostsResetMessage = "Hosts file manually unblocked successfully!"\n\s*hostsResetSuccess = true', r'showBanner(msg: "Hosts file manually unblocked successfully!", success: true)', content)

content = re.sub(r'hostsResetMessage = "Error: \\\(error\.localizedDescription\)"\n\s*hostsResetSuccess = false', r'showBanner(msg: "Error: \\(error.localizedDescription)", success: false)', content)

content = re.sub(r'// Clear recovery notification after 4 seconds\n\s*DispatchQueue\.main\.asyncAfter\(deadline: \.now\(\) \+ 4\.0\) \{\n\s*if self\.hostsResetMessageToken == token \{\n\s*self\.hostsResetMessage = nil\n\s*\}\n\s*\}', r'', content)


with open(filepath, 'w') as f:
    f.write(content)
print("Done refactoring MainView.swift")
