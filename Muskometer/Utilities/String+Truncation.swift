import Foundation

extension String {
    /// Truncates long strings with a middle ellipsis, preserving prefix and suffix.
    func truncatedMiddle(maxLength: Int, ellipsis: String = "…") -> String {
        guard maxLength > 0 else { return "" }
        guard count > maxLength else { return self }
        guard maxLength > ellipsis.count else {
            return String(prefix(maxLength))
        }

        let keepCount = maxLength - ellipsis.count
        let prefixCount = keepCount / 2
        let suffixCount = keepCount - prefixCount
        return String(prefix(prefixCount)) + ellipsis + String(suffix(suffixCount))
    }
}