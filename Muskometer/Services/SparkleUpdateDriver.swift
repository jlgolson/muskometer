import Foundation

// Future Sparkle integration placeholder.
// UpdateCoordinator intentionally does **not** route `.automatic` here yet —
// this driver always returns nil and would falsely report "you're on the latest."
// When Sparkle SPM is added, wire UpdateCoordinator.checker(for: .automatic)
// to this type (and restore install-delivery behavior).
final class SparkleUpdateDriver: UpdateChecking, Sendable {
    func checkForUpdate(currentVersion: String) async throws -> UpdateCheckResult? {
        nil
    }
}