import SwiftUI

struct SettingsView: View {
    @Bindable var state: AppState
    @State private var token = ""
    @State private var saveError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("GitHub access")
                .font(.system(size: 13, weight: .semibold))

            Text(statusText)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                Text("Personal access token")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                SecureField("ghp_… or github_pat_…", text: $token)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
            }

            Text("Needs `repo` access so private pull requests and check status can load. If GitHub CLI is already signed in, you can skip this.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)

            if let saveError {
                Text(saveError)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            }

            HStack {
                Button("Save token") {
                    saveToken()
                }
                .disabled(token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if state.tokenSource == .keychain {
                    Button("Remove saved token") {
                        state.clearSavedToken()
                        token = ""
                    }
                }

                Spacer()

                Button("Done") {
                    state.showsSettings = false
                    Task { await state.refresh() }
                }
            }
            .font(.system(size: 12))

            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            token = TokenStore.loadSavedToken() ?? ""
        }
    }

    private var statusText: String {
        switch state.tokenSource {
        case .keychain:
            return "Using a token saved in your Keychain."
        case .githubCLI:
            let login = state.snapshot.viewerLogin
            if login.isEmpty {
                return "Using your GitHub CLI login."
            }
            return "Using GitHub CLI as @\(login)."
        case .missing:
            return "No GitHub credentials found. Paste a token below, or run `gh auth login` in a terminal."
        }
    }

    private func saveToken() {
        do {
            try state.saveToken(token)
            saveError = nil
            Task { await state.refresh() }
        } catch {
            saveError = error.localizedDescription
        }
    }
}
