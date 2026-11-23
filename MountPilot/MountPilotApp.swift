import SwiftUI

@main
struct MountPilotApp: App {
    @StateObject private var model: AppModel

    init() {
        let appModel = AppModel()
        _model = StateObject(wrappedValue: appModel)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if appModel.configuration.networkShares.isEmpty,
               appModel.configuration.cloneVolumes.isEmpty {
                appModel.openSettings()
            } else {
                appModel.scheduleStartupRun()
            }
            appModel.startPeriodicChecks()
        }
    }

    var body: some Scene {
        MenuBarExtra("MountPilot", systemImage: model.isRunning ? "externaldrive.badge.timemachine" : "externaldrive.connected.to.line.below") {
            MenuContentView()
                .environmentObject(model)
        }
        .menuBarExtraStyle(.window)
    }
}
