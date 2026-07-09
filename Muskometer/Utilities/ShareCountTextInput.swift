import Foundation

/// Pure resolver for holdings share-count text fields (Settings → Holdings).
///
/// On apply, empty fields restore the stored count (no error) so the UI never
/// shows a blank field while math still uses the previous holdings value.
/// Invalid non-empty input also restores the stored count and surfaces an error.
enum ShareCountTextInput {
    enum Resolution: Equatable {
        /// Parsed positive whole number — apply and show canonical text.
        case accepted(Int64)
        /// Empty or invalid — keep stored count; restore field text; optional error.
        case restore(storedCount: Int64, errorMessage: String?)
    }

    static let invalidInputMessage = "Enter a positive whole number."

    static func resolve(rawText: String, storedCount: Int64) -> Resolution {
        let cleaned = rawText.replacingOccurrences(of: ",", with: "")

        if cleaned.isEmpty {
            return .restore(storedCount: storedCount, errorMessage: nil)
        }

        if let count = Int64(cleaned), count > 0 {
            return .accepted(count)
        }

        return .restore(storedCount: storedCount, errorMessage: invalidInputMessage)
    }
}
