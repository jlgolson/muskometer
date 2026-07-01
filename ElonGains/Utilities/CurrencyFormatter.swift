import Foundation

enum CurrencyFormatter {
    static func formatCurrency(
        _ value: Double,
        style: CompactStyle = .billions,
        includeSign: Bool = true
    ) -> String {
        let sign: String
        if includeSign {
            if value > 0 {
                sign = "+"
            } else if value < 0 {
                sign = "-"
            } else {
                sign = ""
            }
        } else {
            sign = ""
        }

        let absolute = abs(value)

        switch style {
        case .billions where absolute >= 1_000_000_000:
            let billions = absolute / 1_000_000_000
            return "\(sign)$\(formatNumber(billions, decimals: 1))B"
        case .millions where absolute >= 1_000_000:
            let millions = absolute / 1_000_000
            return "\(sign)$\(formatNumber(millions, decimals: 1))M"
        case .standard:
            return "\(sign)$\(formatNumber(absolute, decimals: 2))"
        default:
            return "\(sign)$\(formatCompactMagnitude(absolute))"
        }
    }

    /// Formats a market value (always unsigned unless `includeSign` is set on `formatCurrency`).
    static func formatMarketValue(_ value: Double) -> String {
        "$\(formatCompactMagnitude(abs(value)))"
    }

    private static func formatCompactMagnitude(_ absolute: Double) -> String {
        if absolute >= 1_000_000_000_000 {
            let trillions = absolute / 1_000_000_000_000
            return "\(formatNumber(trillions, decimals: 2))T"
        }
        if absolute >= 1_000_000_000 {
            let billions = absolute / 1_000_000_000
            return "\(formatNumber(billions, decimals: 1))B"
        }
        if absolute >= 1_000_000 {
            let millions = absolute / 1_000_000
            return "\(formatNumber(millions, decimals: 1))M"
        }
        return formatNumber(absolute, decimals: 0)
    }

    static func formatPercent(_ value: Double, includeSign: Bool = true) -> String {
        let sign: String
        if includeSign {
            if value > 0 {
                sign = "+"
            } else if value < 0 {
                sign = ""
            } else {
                sign = ""
            }
        } else {
            sign = ""
        }

        return "\(sign)\(formatNumber(value, decimals: 2))%"
    }

    static func formatPrice(_ value: Double) -> String {
        "$\(formatNumber(value, decimals: 2))"
    }

    static func formatShareCount(_ value: Int64) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private static func formatNumber(_ value: Double, decimals: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = decimals
        formatter.maximumFractionDigits = decimals
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.\(decimals)f", value)
    }

    enum CompactStyle {
        case billions
        case millions
        case standard
    }
}