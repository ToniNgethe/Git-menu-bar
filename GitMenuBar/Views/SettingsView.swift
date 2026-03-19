import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var viewModel: PRListViewModel
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
            } header: {
                Text("General")
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 280)
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
