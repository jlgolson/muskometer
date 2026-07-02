import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    var viewModel: GainsViewModel?
    @Environment(\.dismiss) private var dismiss

    private let onDone: (() -> Void)?
    private let embeddedInPopover: Bool

    @State private var selectedTab: SettingsTab = .general
    @State private var refreshInterval: Double
    @State private var shareTexts: [String: String] = [:]
    @State private var shareErrors: [String: String] = [:]

    private var panelWidth: CGFloat { embeddedInPopover ? 500 : 560 }
    private var panelHeight: CGFloat { embeddedInPopover ? 440 : 480 }

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

            footer
        }
        .frame(width: panelWidth, height: panelHeight, alignment: .topLeading)
        .onAppear {
            syncTextFieldsFromSettings()
        }
        .onDisappear {
            applyShareCounts()
        }
    }

    private func tabPage<Content: View>(_ tab: SettingsTab, @ViewBuilder content: () -> Content) -> some View {
        ScrollView(.vertical, showsIndicators: true) {
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
                .padding(.bottom, 8)
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
            }

            groupedCard {
                Text("Refresh interval: \(Int(refreshInterval)) seconds")
                    .font(.body)

                Slider(value: $refreshInterval, in: 60...120, step: 5)
                    .accessibilityLabel("Refresh interval")
                    .onChange(of: refreshInterval) { _, newValue in
                        settings.refreshIntervalSeconds = newValue
                    }

                Text("Stock prices refresh automatically while the US market is open.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            groupedCard {
                HStack(spacing: 12) {
                    Link("muskometer.org", destination: AppURLs.website)
                    Link("GitHub", destination: AppURLs.github)
                    Link("info@muskometer.org", destination: AppURLs.contact)
                }
                .font(.caption)
            }

            resetSection
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

            Text("Choose what the Copy button puts on your clipboard — a branded image card for Messages, or a text summary for X.")
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
            } else {
                Text("Open settings from the menu bar popover to configure gain alerts.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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

            Toggle("Bold on big days", isOn: $settings.menuBarMoodEnabled)

            if settings.menuBarMoodEnabled {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Big day threshold: \(CurrencyFormatter.formatCurrency(settings.menuBarMoodBigDayDollarThreshold))")
                        .font(.caption)
                    Slider(
                        value: $settings.menuBarMoodBigDayDollarThreshold,
                        in: 1_000_000_000...50_000_000_000,
                        step: 1_000_000_000
                    )

                    Text("Or percent: \(CurrencyFormatter.formatPercent(settings.menuBarMoodBigDayPercentThreshold))")
                        .font(.caption)
                    Slider(
                        value: $settings.menuBarMoodBigDayPercentThreshold,
                        in: 0.5...10,
                        step: 0.25
                    )
                }
            }

            Text("Choose gains, percent change, split view, or total worth across tracked holdings. Bold styling kicks in on unusually large moves.")
                .font(.caption)
                .foregroundStyle(.secondary)
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
                    Task { await viewModel.syncHoldingsFromSEC() }
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
            let rawText = shareTexts[symbol] ?? String(settings.shareCount(for: symbol))
            let cleaned = rawText.replacingOccurrences(of: ",", with: "")

            if let count = Int64(cleaned), count > 0 {
                if settings.shareCount(for: symbol) != count {
                    countsChanged = true
                }
                settings.setShareCount(count, for: symbol)
                shareTexts[symbol] = String(count)
            } else if !cleaned.isEmpty {
                errors[symbol] = "Enter a positive whole number."
                shareTexts[symbol] = String(settings.shareCount(for: symbol))
            }
        }

        shareErrors = errors

        if countsChanged, let viewModel {
            Task { await viewModel.refresh(force: true) }
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