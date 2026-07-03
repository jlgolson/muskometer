import SwiftUI
import AppKit

struct PopoverContentView: View {
    @Bindable var viewModel: GainsViewModel
    @State private var showingSettings = false
    @State private var didCopyShare = false
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
        .onDisappear { PopoverVisibility.isVisible = false }
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
        VStack(alignment: .leading, spacing: 12) {
            ownershipCard(snapshot)
            combinedCard(snapshot)
            ComparisonCaptionView(line: viewModel.comparisonLine)

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

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.orange)
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

                if let message = viewModel.trillionEasterEggMessage {
                    Text(message)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color("GainNegative"))
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            MilestoneCelebrationOverlay(milestone: viewModel.activeMilestone) {
                viewModel.clearActiveMilestone()
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.55))
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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

                Text(CurrencyFormatter.formatPercent(snapshot.combinedPercentChange))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(combinedColor(snapshot))
                    .contentTransition(.numericText())
                    .animation(.smooth(duration: 0.25), value: snapshot.combinedPercentChange)

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

            GainSparklineView(samples: viewModel.intradaySamples)

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
                    _ = viewModel.postToX()
                } label: {
                    Label("Post to X", systemImage: "arrow.up.right.square")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Open X with a pre-filled summary of today's gains")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.accentColor.opacity(0.12))
        }
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

                Button("Settings") {
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

        didCopyShare = true

        Task {
            try? await Task.sleep(for: .seconds(1.5))
            didCopyShare = false
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