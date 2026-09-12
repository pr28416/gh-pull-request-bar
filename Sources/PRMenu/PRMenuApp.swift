import AppKit
import SwiftUI

@main
struct PRMenuApp: App {
    @State private var appState = AppState.shared

    init() {
        NSApplication.shared.setActivationPolicy(Self.wantsWindow ? .regular : .accessory)
        AppState.shared.start()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(state: appState)
        } label: {
            MenuBarLabelView(state: appState)
        }
        .menuBarExtraStyle(.window)
        .windowResizability(.contentSize)

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
}

private struct MenuBarLabelView: View {
    var state: AppState

    var body: some View {
        HStack(spacing: 4) {
            Image(nsImage: Self.icon)
                .resizable()
                .renderingMode(.template)
                .frame(width: 18, height: 18)
            if state.openAuthoredCount > 0 {
                Text("\(state.openAuthoredCount)")
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            state.openAuthoredCount == 0
                ? "Pull Requests"
                : "\(state.openAuthoredCount) open pull requests"
        )
    }

    private static let icon: NSImage = {
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">
          <path fill="black" d="M16 19.25a3.25 3.25 0 1 1 6.5 0 3.25 3.25 0 0 1-6.5 0Zm-14.5 0a3.25 3.25 0 1 1 6.5 0 3.25 3.25 0 0 1-6.5 0Zm0-14.5a3.25 3.25 0 1 1 6.5 0 3.25 3.25 0 0 1-6.5 0ZM4.75 3a1.75 1.75 0 1 0 .001 3.501A1.75 1.75 0 0 0 4.75 3Zm0 14.5a1.75 1.75 0 1 0 .001 3.501A1.75 1.75 0 0 0 4.75 17.5Zm14.5 0a1.75 1.75 0 1 0 .001 3.501 1.75 1.75 0 0 0-.001-3.501Z"/>
          <path fill="black" d="M13.405 1.72a.75.75 0 0 1 0 1.06L12.185 4h4.065A3.75 3.75 0 0 1 20 7.75v8.75a.75.75 0 0 1-1.5 0V7.75a2.25 2.25 0 0 0-2.25-2.25h-4.064l1.22 1.22a.75.75 0 0 1-1.061 1.06l-2.5-2.5a.75.75 0 0 1 0-1.06l2.5-2.5a.75.75 0 0 1 1.06 0ZM4.75 7.25A.75.75 0 0 1 5.5 8v8A.75.75 0 0 1 4 16V8a.75.75 0 0 1 .75-.75Z"/>
        </svg>
        """
        let source = NSImage(data: Data(svg.utf8)) ?? NSImage(size: NSSize(width: 24, height: 24))
        let size = NSSize(width: 18, height: 18)
        let icon = NSImage(size: size, flipped: false) { rect in
            source.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
            return true
        }
        icon.isTemplate = true
        return icon
    }()
}
