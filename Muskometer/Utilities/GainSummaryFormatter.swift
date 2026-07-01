import Foundation

enum GainSummaryFormatter {
    static func format(_ snapshot: GainsSnapshot) -> String {
        let combined = CurrencyFormatter.formatCurrency(snapshot.combinedPaperGain)
        let percent = CurrencyFormatter.formatPercent(snapshot.combinedPercentChange)
        let breakdown = snapshot.holdings
            .map { "\($0.symbol) \(CurrencyFormatter.formatCurrency($0.paperGain))" }
            .joined(separator: " / ")

        return "Muskometer — paper gains today: \(combined) (\(percent)) — \(breakdown)"
    }
}