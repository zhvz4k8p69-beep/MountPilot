import AppKit
import Foundation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var configuration: AppConfiguration
    @Published private(set) var activity: [ActivityEntry] = []
    @Published private(set) var isRunning = false

    private let store: ConfigurationStore
    private var startupTask: Task<Void, Never>?
    private var settingsWindowController: NSWindowController?

    init(store: ConfigurationStore = ConfigurationStore()) {
        self.store = store
        var loaded = store.load()
        loaded.runAtLogin = LoginItemService.isEnabled
        configuration = loaded
    }

    var summary: String {
        if isRunning { return "Working…" }
        return activity.first?.message ?? "Ready"
    }

    func scheduleStartupRun() {
        startupTask?.cancel()
        let delay = configuration.startupDelaySeconds
        log(.info, "Startup check scheduled in \(delay) seconds")
        startupTask = Task { [weak self] in
            if delay > 0 {
                try? await Task.sleep(for: .seconds(delay))
            }
            guard !Task.isCancelled else { return }
            await self?.runNow()
        }
    }

    func cancelStartupRun() {
        startupTask?.cancel()
        startupTask = nil
    }

    func runNow() async {
        guard !isRunning else { return }
        startupTask?.cancel()
        startupTask = nil
        isRunning = true
        log(.info, "Starting mount check")
        let current = configuration

        for share in current.networkShares {
            let outcome = await Task.detached {
                MountService.mountShare(share)
            }.value
            log(outcome.succeeded ? .success : .failure, outcome.message)
        }

        guard !current.cloneVolumes.isEmpty else {
            log(.info, "No clone volumes are configured")
            isRunning = false
            return
        }

        // Check immediately before touching disks, after network mounts finish.
        let guardCheck = await Task.detached {
            BackupGuard.check(processTerms: current.backupProcessTerms)
        }.value
        guard guardCheck.isSafe else {
            log(.warning, "Clone volumes were left mounted: \(guardCheck.reason ?? "backup status is uncertain")")
            isRunning = false
            return
        }

        for volume in current.cloneVolumes {
            // Check again for every volume to narrow the race with a task that
            // starts while several disks are being processed.
            let freshCheck = await Task.detached {
                BackupGuard.check(processTerms: current.backupProcessTerms)
            }.value
            guard freshCheck.isSafe else {
                log(.warning, "Stopped unmounting: \(freshCheck.reason ?? "backup status is uncertain")")
                break
            }

            let outcome = await Task.detached {
                MountService.unmountVolume(volume)
            }.value
            log(outcome.succeeded ? .success : .failure, outcome.message)
        }
        isRunning = false
    }

    func save(_ updated: AppConfiguration) -> String? {
        do {
            try LoginItemService.setEnabled(updated.runAtLogin)
            var saved = updated
            saved.runAtLogin = LoginItemService.isEnabled
            try store.save(saved)
            configuration = saved
            log(.success, "Settings saved")
            return nil
        } catch {
            return "Could not update the login item: \(error.localizedDescription). Move MountPilot to Applications, reopen it, and try again."
        }
    }

    func openSettings() {
        if settingsWindowController == nil {
            let rootView = SettingsView().environmentObject(self)
            let hostingController = NSHostingController(rootView: rootView)
            let window = NSWindow(contentViewController: hostingController)
            window.title = "MountPilot Settings"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.setContentSize(NSSize(width: 680, height: 720))
            window.minSize = NSSize(width: 620, height: 650)
            window.isReleasedWhenClosed = false
            window.center()
            window.setFrameAutosaveName("MountPilot.settingsWindow")
            settingsWindowController = NSWindowController(window: window)
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
    }

    private func log(_ kind: ActivityEntry.Kind, _ message: String) {
        activity.insert(ActivityEntry(date: Date(), kind: kind, message: message), at: 0)
        if activity.count > 30 {
            activity.removeLast(activity.count - 30)
        }
    }
}
