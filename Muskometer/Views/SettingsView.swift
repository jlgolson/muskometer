import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    var viewModel: GainsViewModel?
    @Environment(\.dismiss) private var dismiss

    private let onDone: (() -> Void)?
    private let embeddedInPopover: Bool

    @State private var refreshInterval: Double
    @State private var tslaSharesText: String
    @State private var spcxSharesText: String
    @State private var tslaSharesError: String?
    @State private var spcxSharesError: String?

    init(settings: AppSettings, viewModel: GainsViewModel? = nil, onDone: (() -> Void)? = nil) {
        self.settings = settings
        self.viewModel = viewModel
        self.onDone = onDone
        self.embeddedInPopover = onDone != nil
        _refreshInterval = State(initialValue: settings.refreshIntervalSeconds)
        _tslaSharesText = State(initialValue: String(settings.tslaShareCount))
        _spcxSharesText = State(initialValue: String(settings.spcxShareCount))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            settingsSections

            Text(AppVersion.displayString)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 4)
        }
        .frame(minWidth: embeddedInPopover ? 408 : 500, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: true)
        .background {
            GeometryReader { geometry in
                Color.clear.preference(key: SettingsContentHeightKey.self, value: geometry.size.height)
            }
        }
        .onAppear {
            syncTextFieldsFromSettings()
        }
        .onDisappear {
            applyShareCounts()
        }
    }

    @ViewBuilder
    private var settingsSections: some View {
        let sections = VStack(alignment: .leading, spacing: 16) {
            generalSection
            menuBarSection
            priceRefreshSection
            holdingsSection
            resetSection
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        if embeddedInPopover {
            sections
        } else {
            ScrollView(.vertical, showsIndicators: true) {
                sections
            }
            .frame(maxHeight: 720)
        }
    }

    private var header: some View {
        HStack {
            if embeddedInPopover {
                Button {
                    finish()
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
                .buttonStyle(.plain)
            }

            Text("Settings")
                .font(.headline)

            Spacer()

            if !embeddedInPopover {
                Button("Done") {
                    finish()
                }
                .keyboardShortcut(.cancelAction)
            }
        }
    }

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("General")
                .font(.subheadline.weight(.semibold))

            Toggle("Launch at login", isOn: $settings.launchAtLogin)

            Text("Start Muskometer automatically when you sign in to this Mac.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Paper gains for entertainment only. SPCX is a Yahoo proxy, not SpaceX stock.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Link("Full disclaimer", destination: AppURLs.disclaimer)
                .font(.caption)

            HStack(spacing: 12) {
                Link("muskometer.org", destination: AppURLs.website)
                Link("GitHub", destination: AppURLs.github)
                Link("info@muskometer.org", destination: AppURLs.contact)
            }
            .font(.caption)
        }
        .padding(12)
        .background(sectionBackground)
    }

    private var menuBarSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Menu bar")
                .font(.subheadline.weight(.semibold))

            Picker("Display", selection: $settings.menuBarDisplayMode) {
                ForEach(MenuBarDisplayMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.menu)

            Toggle("Show trend icon", isOn: $settings.showMenuBarIcon)

            Text("Choose gains, percent change, split view, or total worth across TSLA and SPCX. Hide the trend icon for text only.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(sectionBackground)
    }

    private var priceRefreshSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Price refresh")
                .font(.subheadline.weight(.semibold))

            Text("Auto-refresh interval: \(Int(refreshInterval)) seconds")
                .font(.subheadline)

            Slider(value: $refreshInterval, in: 60...120, step: 5) {
                Text("Refresh interval")
            }
            .onChange(of: refreshInterval) { _, newValue in
                settings.refreshIntervalSeconds = newValue
            }

            Text("Stock prices refresh automatically while the US market is open. Share counts are separate.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(sectionBackground)
    }

    private var holdingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Share counts (SEC)")
                .font(.subheadline.weight(.semibold))

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

            VStack(alignment: .leading, spacing: 4) {
                Text("TSLA shares (override)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("TSLA", text: $tslaSharesText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { applyShareCounts() }
                if let tslaSharesError {
                    Text(tslaSharesError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("SPCX shares (override)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("SPCX", text: $spcxSharesText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { applyShareCounts() }
                if let spcxSharesError {
                    Text(spcxSharesError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(12)
        .background(sectionBackground)
    }

    private var resetSection: some View {
        Button("Reset to defaults") {
            settings.resetToDefaults()
            refreshInterval = settings.refreshIntervalSeconds
            syncTextFieldsFromSettings()
            tslaSharesError = nil
            spcxSharesError = nil

            if let viewModel {
                Task { await viewModel.refresh(force: true) }
            }
        }
        .buttonStyle(.bordered)
    }

    private var sectionBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.55))
    }

    private func syncTextFieldsFromSettings() {
        tslaSharesText = String(settings.tslaShareCount)
        spcxSharesText = String(settings.spcxShareCount)
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
        let cleanedTSLA = tslaSharesText.replacingOccurrences(of: ",", with: "")
        let cleanedSPCX = spcxSharesText.replacingOccurrences(of: ",", with: "")
        var countsChanged = false

        if let tsla = Int64(cleanedTSLA), tsla > 0 {
            if settings.tslaShareCount != tsla {
                countsChanged = true
            }
            settings.tslaShareCount = tsla
            tslaSharesText = String(tsla)
            tslaSharesError = nil
        } else if !cleanedTSLA.isEmpty {
            tslaSharesError = "Enter a positive whole number."
            tslaSharesText = String(settings.tslaShareCount)
        }

        if let spcx = Int64(cleanedSPCX), spcx > 0 {
            if settings.spcxShareCount != spcx {
                countsChanged = true
            }
            settings.spcxShareCount = spcx
            spcxSharesText = String(spcx)
            spcxSharesError = nil
        } else if !cleanedSPCX.isEmpty {
            spcxSharesError = "Enter a positive whole number."
            spcxSharesText = String(settings.spcxShareCount)
        }

        if countsChanged, let viewModel {
            Task { await viewModel.refresh(force: true) }
        }
    }
}