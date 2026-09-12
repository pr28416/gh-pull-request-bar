import AppKit
import SwiftUI

struct SnapshotHost: View {
    @Bindable var state: AppState

    var body: some View {
        MenuBarView(state: state)
            .task {
                guard ProcessInfo.processInfo.arguments.contains("--snapshot") else { return }
                await state.refresh()
                try? await Task.sleep(for: .milliseconds(700))
                SnapshotHost.writePNG()
                NSApplication.shared.terminate(nil)
            }
    }

    @MainActor
    private static func writePNG() {
        let path = ProcessInfo.processInfo.environment["PRMENU_SNAPSHOT"]
            ?? "/tmp/prmenu-window.png"
        let url = URL(fileURLWithPath: path)

        guard let window = NSApplication.shared.windows.first(where: { $0.title == "PR Menu" })
            ?? NSApplication.shared.windows.first
        else {
            return
        }

        guard let content = window.contentView else { return }
        content.layoutSubtreeIfNeeded()
        let bounds = content.bounds
        guard let rep = content.bitmapImageRepForCachingDisplay(in: bounds) else { return }
        content.cacheDisplay(in: bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: url)
    }
}
