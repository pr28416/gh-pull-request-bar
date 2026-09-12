import AppKit
import SwiftUI

@main
struct PRMenuApp: App {
    @State private var appState = AppState()

    init() {
        NSApplication.shared.setActivationPolicy(Self.wantsWindow ? .regular : .accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(state: appState)
        } label: {
            Label {
                Text(menuBarTitle)
            } icon: {
                Image(systemName: "arrow.triangle.pull")
            }
        }
        .menuBarExtraStyle(.window)

        Window("PR Menu", id: "preview") {
            SnapshotHost(state: appState)
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(Self.wantsWindow ? .presented : .suppressed)
    }

    private static var wantsWindow: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("--window") || arguments.contains("--snapshot")
    }

    private var menuBarTitle: String {
        let count = appState.uniqueCount
        return count > 0 ? "\(count)" : ""
    }
}
