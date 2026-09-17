import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var sharesText = ""
    @State private var volumesText = ""
    @State private var processText = ""
    @State private var delay = 20
    @State private var runAtLogin = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                inputSection(
                    title: "Network shares",
                    help: "One smb://, afp://, or nfs:// address per line. Shares connect in the background with the password saved in Keychain; if none is saved yet, Finder asks once.",
                    text: $sharesText,
                    prompt: "smb://server/share"
                )
                inputSection(
                    title: "Clone backup volumes",
                    help: "One exact volume name or /Volumes path per line. MountPilot never force-unmounts.",
                    text: $volumesText,
                    prompt: "Clone Backup"
                )
                inputSection(
                    title: "Additional backup-process guards",
                    help: "Optional. One process-name fragment per line for backup software other than Time Machine or Carbon Copy Cloner.",
                    text: $processText,
                    prompt: "backup-worker"
                )

                HStack {
                    Stepper("Startup delay: \(delay) seconds", value: $delay, in: 0...120, step: 5)
                    Spacer()
                    Toggle("Launch at login", isOn: $runAtLogin)
                        .toggleStyle(.switch)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.callout)
                }

                HStack {
                    Text("Time Machine and Carbon Copy Cloner are detected automatically.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Run Now") {
                        save()
                        if errorMessage == nil {
                            Task { await model.runNow() }
                        }
                    }
                    Button("Save") { save() }
                        .keyboardShortcut(.defaultAction)
                }

                activity
            }
            .padding(24)
        }
        .frame(minWidth: 620, idealWidth: 680, minHeight: 650, idealHeight: 720)
        .onAppear {
            model.cancelStartupRun()
            load()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("MountPilot")
                .font(.largeTitle.bold())
            Text("Connect network shares and safely put clone drives away after login.")
                .foregroundStyle(.secondary)
        }
    }

    private func inputSection(title: String, help: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            Text(help).font(.caption).foregroundStyle(.secondary)
            TextEditor(text: text)
                .font(.system(.body, design: .monospaced))
                .frame(height: 76)
                .padding(4)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                .overlay(alignment: .topLeading) {
                    if text.wrappedValue.isEmpty {
                        Text(prompt)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .padding(9)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    private var activity: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent activity").font(.headline)
            if model.activity.isEmpty {
                Text("No activity yet.").foregroundStyle(.secondary)
            } else {
                ForEach(model.activity.prefix(8)) { entry in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: symbol(for: entry.kind))
                            .foregroundStyle(color(for: entry.kind))
                        Text(entry.message)
                            .textSelection(.enabled)
                        Spacer()
                        Text(entry.date, style: .time)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .font(.callout)
                }
            }
        }
    }

    private func load() {
        let value = model.configuration
        sharesText = value.networkShares.joined(separator: "\n")
        volumesText = value.cloneVolumes.joined(separator: "\n")
        processText = value.backupProcessTerms.joined(separator: "\n")
        delay = value.startupDelaySeconds
        runAtLogin = value.runAtLogin
    }

    private func save() {
        errorMessage = nil
        let shares = AppConfiguration.normalizedLines(sharesText)
        if let invalid = shares.first(where: { !AppConfiguration.validShare($0) }) {
            errorMessage = "Invalid network share: \(invalid)"
            return
        }
        let volumes = AppConfiguration.normalizedLines(volumesText)
        if let invalid = volumes.first(where: { AppConfiguration.volumePath(for: $0) == nil }) {
            errorMessage = "Invalid clone volume: \(invalid)"
            return
        }
        let updated = AppConfiguration(
            networkShares: shares,
            cloneVolumes: volumes,
            backupProcessTerms: AppConfiguration.normalizedLines(processText),
            startupDelaySeconds: delay,
            runAtLogin: runAtLogin
        )
        errorMessage = model.save(updated)
    }

    private func symbol(for kind: ActivityEntry.Kind) -> String {
        switch kind {
        case .info: return "info.circle"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .failure: return "xmark.circle.fill"
        }
    }

    private func color(for kind: ActivityEntry.Kind) -> Color {
        switch kind {
        case .info: return .secondary
        case .success: return .green
        case .warning: return .orange
        case .failure: return .red
        }
    }
}
