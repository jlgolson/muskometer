import SwiftUI

struct MenuBarLabelView: View {
    @Bindable var viewModel: GainsViewModel
    @Bindable var settings: AppSettings

    init(viewModel: GainsViewModel) {
        self._viewModel = Bindable(wrappedValue: viewModel)
        self._settings = Bindable(wrappedValue: viewModel.settings)
    }

    var body: some View {
        HStack(spacing: 4) {
            if settings.showMenuBarIcon {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }

            if viewModel.isLoading, viewModel.snapshot == nil {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 12, height: 12)
            } else {
                Text(displayText)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(labelColor)
                    .contentTransition(.numericText())
                    .animation(
                        viewModel.snapshot != nil ? .smooth(duration: 0.25) : nil,
                        value: displayText
                    )
            }
        }
        .opacity(labelOpacity)
        .help(viewModel.menuBarTooltip)
        .accessibilityLabel("Muskometer daily gain or loss")
        .accessibilityValue(displayText)
        .id(settings.menuBarLabelEpoch)
        .onAppear { viewModel.start() }
    }

    private var labelOpacity: Double {
        if viewModel.hasStaleData { return 0.7 }
        if viewModel.shouldDimMenuBarLabel { return 0.65 }
        return 1
    }

    private var displayText: String {
        viewModel.menuBarTitle
    }

    private var labelColor: Color {
        switch viewModel.gainColor {
        case .positive:
            return Color("GainPositive")
        case .negative:
            return Color("GainNegative")
        case .neutral:
            return .primary
        }
    }
}