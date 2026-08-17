import Foundation

/// Presentation values for the “TSLA at SPCX market-cap parity” card.
struct MergerParityPresentation: Equatable, Sendable {
    let impliedTSLAPrice: Double
    let tslaMarketCap: Double
    let spcxMarketCap: Double
}

/// Pure market-cap parity math: what TSLA’s share price would be if TSLA’s
/// market cap matched SPCX’s.
///
/// SPCX market cap uses Class A Yahoo price × total Class A+B outstanding.
enum MergerMarketCapParity {
    /// Returns `nil` if any input is non-finite or ≤ 0, or if the implied
    /// price is non-finite or ≤ 0.
    static func presentation(
        tslaPrice: Double,
        spcxPrice: Double,
        tslaOutstanding: Int64,
        spcxOutstanding: Int64
    ) -> MergerParityPresentation? {
        guard tslaPrice.isFinite, tslaPrice > 0,
              spcxPrice.isFinite, spcxPrice > 0,
              tslaOutstanding > 0,
              spcxOutstanding > 0
        else {
            return nil
        }

        let tslaShares = Double(tslaOutstanding)
        let spcxShares = Double(spcxOutstanding)
        let tslaMarketCap = tslaPrice * tslaShares
        let spcxMarketCap = spcxPrice * spcxShares
        let impliedTSLAPrice = spcxMarketCap / tslaShares

        guard tslaMarketCap.isFinite, tslaMarketCap > 0,
              spcxMarketCap.isFinite, spcxMarketCap > 0,
              impliedTSLAPrice.isFinite, impliedTSLAPrice > 0
        else {
            return nil
        }

        return MergerParityPresentation(
            impliedTSLAPrice: impliedTSLAPrice,
            tslaMarketCap: tslaMarketCap,
            spcxMarketCap: spcxMarketCap
        )
    }
}
