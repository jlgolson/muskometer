import SwiftUI

/// Compact best/worst daily gain display for the popover.
struct DailyRecordsCardView: View {
    let bestRecord: DailyGainRecord?
    let worstRecord: DailyGainRecord?
    var animateValues = false

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Intraday records", systemImage: "chart.line.uptrend.xyaxis")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: 12) {
                recordColumn(
                    title: "Best",
                    systemImage: "arrow.up.circle.fill",
                    record: bestRecord,
                    color: Color("GainPositive")
                )

                Divider()
                    .frame(maxHeight: 44)

                recordColumn(
                    title: "Worst",
                    systemImage: "arrow.down.circle.fill",
                    record: worstRecord,
                    color: Color("GainNegative")
                )
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.55))
        }
    }

    @ViewBuilder
    private func recordColumn(
        title: String,
        systemImage: String,
        record: DailyGainRecord?,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: systemImage)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .labelStyle(.titleAndIcon)

            if let record {
                amountText(CurrencyFormatter.formatCurrency(record.amount), record: record)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(color)

                Text(Self.dateFormatter.string(from: record.date))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else {
                Text("—")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func amountText(_ text: String, record: DailyGainRecord) -> some View {
        if animateValues {
            Text(text)
                .contentTransition(.numericText())
                .animation(.smooth(duration: 0.25), value: record.amount)
        } else {
            Text(text)
        }
    }
}

#if DEBUG
struct DailyRecordsCardView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            DailyRecordsCardView(
                bestRecord: DailyGainRecord(amount: 52_300_000_000, date: Date(timeIntervalSince1970: 1_751_222_400)),
                worstRecord: DailyGainRecord(amount: -18_400_000_000, date: Date(timeIntervalSince1970: 1_749_542_400)),
                animateValues: true
            )
            .previewDisplayName("Both records")

            DailyRecordsCardView(
                bestRecord: DailyGainRecord(amount: 12_500_000_000, date: .now),
                worstRecord: nil
            )
            .previewDisplayName("Best only")

            DailyRecordsCardView(bestRecord: nil, worstRecord: nil)
                .previewDisplayName("Empty")
        }
        .padding()
        .frame(width: 328)
    }
}
#endif