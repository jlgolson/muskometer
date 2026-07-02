import Foundation

enum SemanticVersion {
    static func isNewer(_ remote: String, than current: String) -> Bool {
        compare(remote, current) > 0
    }

    static func compare(_ lhs: String, _ rhs: String) -> Int {
        let left = lhs.split(separator: ".").compactMap { Int($0) }
        let right = rhs.split(separator: ".").compactMap { Int($0) }
        let count = max(left.count, right.count)

        for index in 0..<count {
            let leftComponent = index < left.count ? left[index] : 0
            let rightComponent = index < right.count ? right[index] : 0
            if leftComponent != rightComponent {
                return leftComponent < rightComponent ? -1 : 1
            }
        }

        return 0
    }
}