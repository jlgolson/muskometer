import SwiftUI
import AppKit

struct PopoverContentView: View {
    @Bindable var viewModel: GainsViewModel
    @State private var showingSettings = false
    @State private var didCopyShare = false
    @State private var copyFeedbackTask: Task<Void, Never>?
    @State private var settingsPanelSize = CGSize(width: 560, height: 420)

    var body: some View {
        Group {
            if showingSettings {
                settingsPanel
            } else {
                mainPanel
            }
        }
        .padding(16)
        .frame(
            width: showingSettings ? settingsPanelSize.width + 32 : 360,
            height: showingSettings ? settingsPanelSize.height + 32 : nil,
            alignment: .topLeading
        )
        .onAppear {
            PopoverVisibility.isVisible = true
            showingSettings = false
        }
        .onDisappear {
            PopoverVisibility.isVisible = false
            copyFeedbackTask?.cancel()
            copyFeedbackTask = nil
            didCopyShare = false
        }
        .onReceive(NotificationCenter.default.publisher(for: .openMuskometerSettings)) { _ in
            showingSettings = true
        }
    }

    private var mainPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            content
            footer
        }
    }

    private var settingsPanel: some View {
        SettingsView(settings: viewModel.settings, viewModel: viewModel) {
            showingSettings = false
        }
        .onPreferenceChange(SettingsPanelSizeKey.self) { size in
            if size.width > 0, size.height > 0 {
                settingsPanelSize = size
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Muskometer")
                .font(.system(.title3, design: .rounded, weight: .bold))

            Text(viewModel.settings.selectedProfile.tagline)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading, viewModel.snapshot == nil {
            loadingView
        } else if let error = viewModel.errorMessage, viewModel.snapshot == nil {
            errorView(error)
        } else if let snapshot = viewModel.snapshot {
            dataView(snapshot)
        } else {
            loadingView
        }
    }

    private var loadingView: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text("Fetching live prices…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
    }

    private func errorView(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Unable to load quotes", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Try Again") {
                performRefresh()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
    }

    private func dataView(_ snapshot: GainsSnapshot) -> some View {
        GlassEffectContainer(spacing: MuskometerGlass.containerSpacing) {
            VStack(alignment: .leading, spacing: 12) {
                ownershipCard(snapshot)
                combinedCard(snapshot)

                if hasDailyRecords {
                    DailyRecordsCardView(
                        bestRecord: viewModel.dailyRecordsSnapshot.bestRecord,
                        worstRecord: viewModel.dailyRecordsSnapshot.worstRecord,
                        animateValues: true
                    )
                }

                ForEach(snapshot.holdings) { holding in
                    StockRowView(
                        holding: holding,
                        possessiveName: viewModel.settings.selectedProfile.possessiveName,
                        animateValues: true
                    )
                }

                if viewModel.settings.showMergerParityCard,
                   let presentation = viewModel.mergerParityPresentation {
                    MergerParityCardView(
                        presentation: presentation,
                        outstandingCaption: viewModel.mergerParityOutstandingCaption,
                        animateValues: true
                    )
                }

                if viewModel.hasStaleData {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Showing last good quotes")
                                .font(.caption.weight(.semibold))
                            Text("Updated \(snapshot.lastUpdated.formatted(date: .omitted, time: .shortened)). Refresh to retry.")
                                .font(.caption2)
                        }
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                    }
                    .foregroundStyle(.orange)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Stale data")
                    .accessibilityValue("Showing last good quotes from \(snapshot.lastUpdated.formatted(date: .omitted, time: .shortened))")
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private func ownershipCard(_ snapshot: GainsSnapshot) -> some View {
        ZStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(viewModel.settings.selectedProfile.possessiveName) Ownership")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(CurrencyFormatter.formatMarketValue(snapshot.combinedMarketValue))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.smooth(duration: 0.25), value: snapshot.combinedMarketValue)
                    .accessibilityLabel("\(viewModel.settings.selectedProfile.possessiveName) ownership market value")
                    .accessibilityValue(CurrencyFormatter.formatMarketValue(snapshot.combinedMarketValue))

                if let message = viewModel.trillionEasterEggMessage {
                    Text(message)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color("GainNegative"))
                        .padding(.top, 2)
                }

                if let ownershipToast = viewModel.holdingsOwnershipChangeMessage {
                    Text(ownershipToast)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                        .accessibilityLabel("Ownership change")
                        .accessibilityValue(ownershipToast)
                }

                Text("Form 4 common stock and vested options only; performance RSUs excluded until milestones.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            MilestoneCelebrationOverlay(milestone: viewModel.activeMilestone) {
                viewModel.clearActiveMilestone()
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .muskometerGlassCard()
    }

    private func combinedCard(_ snapshot: GainsSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Combined today")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(CurrencyFormatter.formatCurrency(snapshot.combinedPaperGain))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(combinedColor(snapshot))
                    .contentTransition(.numericText())
                    .animation(.smooth(duration: 0.25), value: snapshot.combinedPaperGain)
                    .accessibilityLabel("Combined paper gain or loss today")
                    .accessibilityValue(CurrencyFormatter.formatCurrency(snapshot.combinedPaperGain))

                Text(CurrencyFormatter.formatPercent(snapshot.combinedPercentChange))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(combinedColor(snapshot))
                    .contentTransition(.numericText())
                    .animation(.smooth(duration: 0.25), value: snapshot.combinedPercentChange)
                    .accessibilityLabel("Combined percent change today")
                    .accessibilityValue(CurrencyFormatter.formatPercent(snapshot.combinedPercentChange))

                HStack(spacing: 6) {
                    Circle()
                        .fill(snapshot.isQuotable ? Color("GainPositive") : .secondary)
                        .frame(width: 6, height: 6)
                    Text(viewModel.marketStatusLabel ?? "Market closed")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let detail = viewModel.marketStatusDetail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if !viewModel.intradaySamples.isEmpty {
                GainSparklineView(samples: viewModel.intradaySamples)
            }

            HStack(spacing: 8) {
                Button {
                    copyShare()
                } label: {
                    Label(
                        didCopyShare ? "Copied!" : viewModel.settings.shareFormat.buttonTitle,
                        systemImage: viewModel.settings.shareFormat.buttonIcon
                    )
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(didCopyShare)
                .help(viewModel.settings.shareFormat.helpText)

                Button {
                    _ = viewModel.presentSystemShare()
                } label: {
                    Label("Share…", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(viewModel.snapshot == nil)
                .help("Open the system share sheet")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Untinted glass — full AccentColor tint washes the card solid blue in MenuBarExtra.
        .muskometerGlassCard()
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Spacer()

                Button(action: performRefresh) {
                    HStack(spacing: 4) {
                        if viewModel.isLoading {
                            ProgressView()
                                .controlSize(.small)
                                .frame(width: 12, height: 12)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text("Refresh")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .keyboardShortcut("r", modifiers: .command)

                Button("Settings…") {
                    NSApp.activate(ignoringOtherApps: true)
                    NotificationCenter.default.post(name: .openMuskometerSettings, object: nil)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .keyboardShortcut(",", modifiers: .command)

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            HStack(spacing: 12) {
                if let updated = viewModel.snapshot?.lastUpdated {
                    Text("Updated \(updated.formatted(date: .omitted, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text("Not yet updated")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Link("muskometer.org", destination: AppURLs.website)
                    .font(.caption2)

                Link("Disclaimer", destination: AppURLs.disclaimer)
                    .font(.caption2)

                Spacer(minLength: 0)
            }

            Text("Quotes: Yahoo Finance · Holdings: SEC EDGAR")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private func performRefresh() {
        NSApp.activate(ignoringOtherApps: true)
        Task { await viewModel.refresh(force: true) }
    }

    private func copyShare() {
        guard viewModel.copyShareToPasteboard() else { return }

        copyFeedbackTask?.cancel()
        didCopyShare = true

        copyFeedbackTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            didCopyShare = false
            copyFeedbackTask = nil
        }
    }

    private var hasDailyRecords: Bool {
        viewModel.dailyRecordsSnapshot.bestRecord != nil
            || viewModel.dailyRecordsSnapshot.worstRecord != nil
    }

    private func combinedColor(_ snapshot: GainsSnapshot) -> Color {
        if snapshot.combinedPaperGain > 0 {
            return Color("GainPositive")
        }
        if snapshot.combinedPaperGain < 0 {
            return Color("GainNegative")
        }
        return .primary
    }
}