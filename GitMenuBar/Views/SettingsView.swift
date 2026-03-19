import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var viewModel: PRListViewModel
    @EnvironmentObject var appSettings: AppSettings
    @State private var tokenInput = ""
    @State private var isSaving = false
    @State private var showToken = false
    @State private var statusMessage: String?

    var body: some View {
        Form {
            Section {
                if viewModel.isAuthenticated {
                    authenticatedView
                } else {
                    tokenInputView
                }
            } header: {
                Text("GitHub Account")
            }

            Section {
                LaunchAtLoginToggle()

                Picker("Refresh interval", selection: $appSettings.refreshInterval) {
                    Text("30 seconds").tag(TimeInterval(30))
                    Text("1 minute").tag(TimeInterval(60))
                    Text("2 minutes").tag(TimeInterval(120))
                    Text("5 minutes").tag(TimeInterval(300))
                }

                Picker("Max PR age", selection: $appSettings.maxAgeDays) {
                    Text("1 week").tag(7)
                    Text("2 weeks").tag(14)
                    Text("1 month").tag(30)
                    Text("2 months").tag(60)
                    Text("3 months").tag(90)
                    Text("No limit").tag(0)
                }

                Toggle("Notifications", isOn: $appSettings.notificationsEnabled)
            } header: {
                Text("General")
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 420)
    }

    private var authenticatedView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Connected as \(viewModel.username ?? "unknown")")
                    .font(.body)
            }

            Button("Sign Out", role: .destructive) {
                viewModel.signOut()
            }
            .controlSize(.small)
        }
    }

    private var tokenInputView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Enter a GitHub Personal Access Token with `repo` scope.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                if showToken {
                    TextField("ghp_...", text: $tokenInput)
                        .textFieldStyle(.roundedBorder)
                } else {
                    SecureField("ghp_...", text: $tokenInput)
                        .textFieldStyle(.roundedBorder)
                }

                Button {
                    showToken.toggle()
                } label: {
                    Image(systemName: showToken ? "eye.slash" : "eye")
                }
                .buttonStyle(.borderless)
            }

            HStack {
                Button("Save Token") {
                    Task {
                        isSaving = true
                        let success = await viewModel.saveToken(tokenInput)
                        isSaving = false
                        if success {
                            tokenInput = ""
                            statusMessage = nil
                        } else {
                            statusMessage = viewModel.errorMessage
                        }
                    }
                }
                .disabled(tokenInput.isEmpty || isSaving)
                .controlSize(.small)

                if isSaving {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if let statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }
}

struct LaunchAtLoginToggle: View {
    @State private var launchAtLogin = false

    var body: some View {
        Toggle("Launch at login", isOn: $launchAtLogin)
            .onChange(of: launchAtLogin) { _, newValue in
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    launchAtLogin = !newValue
                }
            }
            .onAppear {
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
    }
}
