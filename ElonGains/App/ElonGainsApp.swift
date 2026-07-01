import SwiftUI

@main
struct ElonGainsApp: App {
    private let viewModel: GainsViewModel
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
        LaunchAtLoginManager.reconcile(with: AppSettings.shared)
        let viewModel = GainsViewModel()
        self.viewModel = viewModel
        AppDelegate.onTerminateHandler = { @MainActor in
            viewModel.stop()
        }
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverContentView(viewModel: viewModel)
        } label: {
            MenuBarLabelView(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)
        .commands {
            CommandGroup(after: .toolbar) {
                Button("Refresh") {
                    Task { await viewModel.refresh(force: true) }
                }
                .keyboardShortcut("r", modifiers: .command)
            }

            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    NSApp.activate(ignoringOtherApps: true)
                    if PopoverVisibility.isVisible {
                        NotificationCenter.default.post(name: .openMuskometerSettings, object: nil)
                    } else {
                        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                    }
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }

        Settings {
            SettingsView(settings: viewModel.settings, viewModel: viewModel)
                .frame(minWidth: 500, minHeight: 720)
        }
    }
}