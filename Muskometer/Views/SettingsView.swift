import AppKit
import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    var viewModel: GainsViewModel?
    @Environment(\.dismiss) private var dismiss

    private let onDone: (() -> Void)?
    private let embeddedInPopover: Bool

    @State private var selectedTab: SettingsTab = .general
    @State private var tabContentHeight: CGFloat = 280
    @State private var refreshInterval: Double
    @State private var shareTexts: [String: String] = [:]
    @State private var shareErrors: [String: String] = [:]

    init(settings: AppSettings, viewModel: GainsViewModel? = nil, onDone: (() -> Void)? = nil) {
        self.settings = settings
        self.viewModel = viewModel
        self.onDone = onDone
        self.embeddedInPopover = onDone != nil
        _refreshInterval = State(initialValue: settings.refreshIntervalSeconds)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            TabView(selection: $selectedTab) {
                tabPage(.general) { generalTab }
                tabPage(.sharing) { sharingTab }
                tabPage(.alerts) { alertsTab }
                tabPage(.menuBar) { menuBarTab }
                tabPage(.holdings) { holdingsTab }
            }
            .tabViewStyle(.automatic)
            .frame(minHeight: tabContentHeight)

            footer
        }
        .frame(minWidth: 560)
        .fixedSize(horizontal: false, vertical: true)
        .background {
            GeometryReader { geometry in
                Color.clear.preference(key: SettingsPanelSizeKey.self, value: geometry.size)
            }
        }
        .onPreferenceChange(SettingsContentHeightKey.self) { height in
            if height > 0 {
                tabContentHeight = height
            }
        }
        .onAppear {
            syncTextFieldsFromSettings()
            // Re-check Login Items after user may have approved in System Settings
            // (launch reconcile only runs at app start, so pending can otherwise stick).
            settings.syncLaunchAtLoginFromService()
        }
        .onDisappear {
            applyShareCounts()
        }
        // After approving Login Items in System Settings, returning to the app
        // should clear "pending approval" without reopening Settings.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            settings.syncLaunchAtLoginFromService()
        }
        // Background SEC sync while Settings is open can update AppSettings without
        // touching local shareTexts; keep fields in sync when a sync finishes.
        .onChange(of: viewModel?.isSyncingHoldings ?? false) { wasSyncing, isSyncing in
            if wasSyncing && !isSyncing {
                syncTextFieldsFromSettings()
            }
        }
    }

    private func tabPage<Content: View>(_ tab: SettingsTab, @ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
            .background {
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: SettingsContentHeightKey.self,
                        value: selectedTab == tab ? geometry.size.height : 0
                    )
                }
            }
            .tabItem {
                Label(tab.title, systemImage: tab.systemImage)
            }
            .tag(tab)
    }

    private var header: some View {
        ZStack {
            Text("Settings")
                .font(.system(.title3, design: .rounded, weight: .bold))

            HStack {
                if embeddedInPopover {
                    backButton
                }

                Spacer()

                if !embeddedInPopover {
                    Button("Done") {
                        finish()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .keyboardShortcut(.cancelAction)
                }
            }
        }
        .padding(.bottom, 2)
    }

    private var footer: some View {
        VStack(spacing: 4) {
            Link("Disclaimer", destination: AppURLs.disclaimer)
                .font(.caption2)

            Text(AppVersion.displayString)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var backButton: some View {
        Button {
            finish()
        } label: {
            Label("Back", systemImage: "chevron.left")
                .font(.subheadline)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    // MARK: - Tabs

    private var generalTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            groupedCard {
                Toggle("Launch at login", isOn: $settings.launchAtLogin)

                Text("Start Muskometer automatically when you sign in to this Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let error = settings.launchAtLoginError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            groupedCard {
                Text("Refresh interval: \(Int(refreshInterval)) seconds")
                    .font(.body)

                Slider(value: $refreshInterval, in: 60...120, step: 5)
                    .accessibilityLabel("Refresh interval")
                    .onChange(of: refreshInterval) { _, newValue in
                        settings.refreshIntervalSeconds = newValue
                    }

                Text("Stock prices refresh automatically during US trading hours (pre-market, regular, and post-market).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            updatesSection

            groupedCard {
                HStack(spacing: 12) {
                    Link("muskometer.org", destination: AppURLs.website)
                    Link("GitHub", destination: AppURLs.github)
                    Link("info@muskometer.org", destination: AppURLs.contact)
                }
                .font(.caption)
            }
        }
    }

    @ViewBuilder
    private var updatesSection: some View {
        if let viewModel {
            groupedCard {
                UpdatesSettingsContent(
                    settings: settings,
                    coordinator: viewModel.updateCoordinator
                )
            }
        }
    }

    private var sharingTab: some View {
        groupedCard {
            Picker("Copy format", selection: $settings.shareFormat) {
                ForEach(ShareFormat.allCases) { format in
                    Text(format.label).tag(format)
                }
            }
            .pickerStyle(.menu)

            Text("Choose what the Copy button puts on your clipboard — a branded image card, or a plain text summary.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Use ⌘⇧C to copy from anywhere. Global copy requires Accessibility permission in System Settings → Privacy & Security → Accessibility.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var alertsTab: some View {
        groupedCard {
            Text("macOS notification permission is required (System Settings → Notifications → Muskometer).")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let viewModel {
                Text("Alert when combined paper gain crosses a threshold during market hours.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Gains")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(GainNotificationThreshold.presets.filter(\.isGainThreshold)) { threshold in
                        notificationToggle(threshold, viewModel: viewModel)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Losses")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)

                    ForEach(GainNotificationThreshold.presets.filter { !$0.isGainThreshold }) { threshold in
                        notificationToggle(threshold, viewModel: viewModel)
                    }
                }

                if let message = viewModel.notificationAuthorizationMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } else {
                Text("Open settings from the menu bar popover to configure gain alerts.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            // Re-show denied hint when opening Alerts with thresholds already enabled.
            viewModel?.refreshNotificationAuthorizationMessageIfNeeded()
        }
    }

    private var menuBarTab: some View {
        groupedCard {
            Picker("Display", selection: $settings.menuBarDisplayMode) {
                ForEach(MenuBarDisplayMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.menu)

            Toggle("Show trend icon", isOn: $settings.showMenuBarIcon)
        }
    }

    private var holdingsTab: some View {
        groupedCard {
            if let lastSync = settings.lastHoldingsSyncDate {
                Text("Last SEC sync: \(lastSync.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Not yet synced from SEC.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let source = settings.holdingsSyncSource {
                Text(source)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let viewModel {
                Button {
                    Task {
                        await viewModel.syncHoldingsFromSEC()
                        // SEC updates AppSettings share counts, not local @State.
                        // Refresh fields so finish/disappear cannot rewrite pre-sync values.
                        syncTextFieldsFromSettings()
                    }
                } label: {
                    HStack(spacing: 6) {
                        if viewModel.isSyncingHoldings {
                            ProgressView().controlSize(.small)
                        }
                        Text("Sync from SEC now")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isSyncingHoldings)

                if let message = viewModel.holdingsSyncMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("Holdings check SEC Form 4 filings once per day. Prices refresh separately.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(settings.selectedProfile.holdingSpecs) { spec in
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(spec.symbol) shares (override)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField(spec.symbol, text: shareTextBinding(for: spec.symbol))
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { applyShareCounts() }
                    if let error = shareErrors[spec.symbol] {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }

            resetSection
                .padding(.top, 4)
        }
    }

    private func notificationToggle(_ threshold: GainNotificationThreshold, viewModel: GainsViewModel) -> some View {
        let enabled = viewModel.enabledNotificationThresholdIDs.contains(threshold.id)

        return Toggle(threshold.label, isOn: Binding(
            get: { viewModel.enabledNotificationThresholdIDs.contains(threshold.id) },
            set: { viewModel.setNotificationThresholdEnabled(threshold.id, enabled: $0) }
        ))
        .font(.body)
        .accessibilityValue(enabled ? "On" : "Off")
    }

    private var resetSection: some View {
        Button("Reset to defaults") {
            settings.resetToDefaults()
            refreshInterval = settings.refreshIntervalSeconds
            syncTextFieldsFromSettings()
            shareErrors = [:]

            if let viewModel {
                viewModel.reloadPersistedDisplayState()
                UpdateCoordinator.resetNotificationDebounce()
                viewModel.updateCoordinator.stop()
                Task { await viewModel.refresh(force: true) }
            }
        }
        .buttonStyle(.bordered)
    }

    private func groupedCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(sectionBackground)
    }

    private var sectionBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.55))
    }

    private func shareTextBinding(for symbol: String) -> Binding<String> {
        Binding(
            get: { shareTexts[symbol] ?? String(settings.shareCount(for: symbol)) },
            set: { shareTexts[symbol] = $0 }
        )
    }

    private func syncTextFieldsFromSettings() {
        var texts: [String: String] = [:]
        for spec in settings.selectedProfile.holdingSpecs {
            texts[spec.symbol] = String(settings.shareCount(for: spec.symbol))
        }
        shareTexts = texts
    }

    private func finish() {
        applyShareCounts()
        if let onDone {
            onDone()
        } else {
            dismiss()
        }
    }

    private func applyShareCounts() {
        var countsChanged = false
        var errors: [String: String] = [:]

        for spec in settings.selectedProfile.holdingSpecs {
            let symbol = spec.symbol
            let stored = settings.shareCount(for: symbol)
            let rawText = shareTexts[symbol] ?? String(stored)

            // Field already shows the stored value — no write (avoids clobbering a
            // concurrent SEC update when text was refreshed to match).
            if rawText == String(stored) {
                continue
            }

            switch ShareCountTextInput.resolve(rawText: rawText, storedCount: stored) {
            case .accepted(let count):
                if stored != count {
                    settings.setShareCount(count, for: symbol)
                    countsChanged = true
                }
                shareTexts[symbol] = String(count)
            case .restore(let storedCount, let errorMessage):
                // Empty or invalid: keep stored holdings and force field text to match.
                shareTexts[symbol] = String(storedCount)
                if let errorMessage {
                    errors[symbol] = errorMessage
                }
            }
        }

        shareErrors = errors

        if countsChanged, let viewModel {
            Task { await viewModel.refresh(force: true) }
        }
    }
}

private struct UpdatesSettingsContent: View {
    @Bindable var settings: AppSettings
    @Bindable var coordinator: UpdateCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Notify of available updates", isOn: $settings.notifyOfAvailableUpdates)
                .onChange(of: settings.notifyOfAvailableUpdates) { _, enabled in
                    if enabled {
                        coordinator.start()
                    } else {
                        coordinator.stop()
                    }
                }

            if let message = coordinator.notificationAuthorizationMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Text("Checks GitHub once per day when enabled. When an update is available, you get a notification and a link to download from the release page.")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Automatic install (Sparkle) is not wired yet. Hide the delivery
            // mode control so users cannot select a path that cannot install.
            // Keep UpdateDeliveryMode.automatic in the model for future use;
            // checks fall back to the GitHub notify path if that value is stored.
            Text("Automatic install requires a signed build (coming soon). Download stays manual for now.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                coordinator.checkNow()
            } label: {
                HStack(spacing: 6) {
                    if coordinator.isChecking {
                        ProgressView().controlSize(.small)
                    }
                    Text(coordinator.isChecking ? "Checking…" : "Check for Updates Now")
                }
            }
            .buttonStyle(.bordered)
            .disabled(coordinator.isChecking)

            if let summary = coordinator.manualCheckSummary {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let update = coordinator.availableUpdate {
                Link("Download update", destination: update.releasePageURL)
                    .font(.caption)
            }

            if let error = coordinator.lastCheckError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            } else if let lastCheck = coordinator.lastCheckDate, coordinator.manualCheckSummary != nil {
                Text("Last checked \(lastCheck.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

private enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case sharing
    case alerts
    case menuBar
    case holdings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .sharing: return "Sharing"
        case .alerts: return "Alerts"
        case .menuBar: return "Menu Bar"
        case .holdings: return "Holdings"
        }
    }

    var systemImage: String {
        switch self {
        case .general: return "gearshape"
        case .sharing: return "square.and.arrow.up"
        case .alerts: return "bell"
        case .menuBar: return "menubar.rectangle"
        case .holdings: return "chart.pie"
        }
    }
}

/// Command/menu button that opens Settings via the public `openSettings` environment action
/// (works for `.accessory` / MenuBarExtra apps where private `showSettingsWindow:` can fail).
struct OpenSettingsButton: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("Settings…") {
            NSApp.activate(ignoringOtherApps: true)
            if PopoverVisibility.isVisible {
                NotificationCenter.default.post(name: .openMuskometerSettings, object: nil)
            } else {
                openSettings()
            }
        }
        .keyboardShortcut(",", modifiers: .command)
    }
}