import Foundation

enum GainSummaryFormatter {
    static func todaysGainLossLabel(for amount: Double) -> String {
        if amount > 0 { return "Today's Gain" }
        if amount < 0 { return "Today's Loss" }
        return "Today's Gain/Loss"
    }

    static func format(_ snapshot: GainsSnapshot) -> String {
        let combined = CurrencyFormatter.formatCurrency(snapshot.combinedPaperGain)
        let percent = CurrencyFormatter.formatPercent(snapshot.combinedPercentChange)
        let breakdown = snapshot.holdings
            .map { "\($0.symbol) \(CurrencyFormatter.formatCurrency($0.paperGain))" }
            .joined(separator: " / ")

        let headline = todaysGainLossLabel(for: snapshot.combinedPaperGain).lowercased()
        return "Muskometer — \(headline): \(combined) (\(percent)) — \(breakdown) (Illustrative. SPCX is SpaceX stock; holdings from SEC. Not financial advice.)"
    }
}