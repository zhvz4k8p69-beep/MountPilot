import SwiftUI

struct MenuContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(maxWidth: 280, alignment: .leading)

            Divider()

            Button(model.isRunning ? "Running…" : "Run Now") {
                Task { await model.runNow() }
            }
            .disabled(model.isRunning)

            Button("Settings…") {
                model.openSettings()
            }
            .keyboardShortcut(",")

            Divider()

            Button("Quit MountPilot") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(10)
        .frame(width: 300)
    }
}

