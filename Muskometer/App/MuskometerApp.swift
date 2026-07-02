import SwiftUI

@main
struct MuskometerApp: App {
    private let viewModel: GainsViewModel
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
        LaunchAtLoginManager.reconcile(with: AppSettings.shared)
        let settings = AppSettings.shared
        let updateCoordinator = UpdateCoordinator(settings: settings)
        let viewModel = GainsViewModel(settings: settings, updateCoordinator: updateCoordinator)
        self.viewModel = viewModel
        updateCoordinator.start()
        AppDelegate.onTerminateHandler = { @MainActor in
            viewModel.stop()
            updateCoordinator.stop()
        }
        AppDelegate.shareShortcutHandler = { @MainActor in
            viewModel.copyShareToPasteboard()
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
            CommandGroup(replacing: .appInfo) {
                OpenAboutWindowButton()
            }

            CommandGroup(after: .toolbar) {
                Button(viewModel.settings.shareFormat.buttonTitle) {
                    _ = viewModel.copyShareToPasteboard()
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(viewModel.snapshot == nil)

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
        }

        Window("About Muskometer", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
    }
}