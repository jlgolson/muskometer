import SwiftUI
import AppKit

struct PopoverContentView: View {
    @Bindable var viewModel: GainsViewModel
    @State private var showingSettings = false
    @State private var didShareImage = false
    @State private var settingsContentHeight: CGFloat = 760

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
            width: showingSettings ? 440 : 360,
            height: showingSettings ? settingsContentHeight + 32 : nil,
            alignment: .topLeading
        )
        .onPreferenceChange(SettingsContentHeightKey.self) { height in
            guard height > 0 else { return }
            settingsContentHeight = height
        }
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
        VStack(alignment: .leading, spacing: 4) {
            Text("\(viewModel.settings.selectedProfile.possessiveName) Ownership")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(CurrencyFormatter.formatMarketValue(snapshot.combinedMarketValue))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.smooth(duration: 0.25), value: snapshot.combinedMarketValue)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.55))
        }
    }

    private func combinedCard(_ snapshot: GainsSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
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
                            .fill(snapshot.marketIsOpen ? Color("GainPositive") : .secondary)
                            .frame(width: 6, height: 6)
                        Text(snapshot.marketIsOpen ? "Market open" : "Market closed")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if let detail = viewModel.marketStatusDetail {
                        Text(detail)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button {
                    shareImage(snapshot)
                } label: {
                    Label(didShareImage ? "Copied!" : "Share", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(didShareImage)
                .help("Copy a shareable image to paste in Messages")
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

    private func shareImage(_ snapshot: GainsSnapshot) {
        let copied = ShareImageExporter.copyToPasteboard(
            snapshot: snapshot,
            profile: viewModel.settings.selectedProfile
        )
        guard copied else { return }

        didShareImage = true

        Task {
            try? await Task.sleep(for: .seconds(1.5))
            didShareImage = false
        }
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