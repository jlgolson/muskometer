import Foundation

// Future Sparkle integration — replace GitHubReleaseUpdateChecker in UpdateCoordinator
// when updateDeliveryMode == .automatic and Sparkle SPM is added.
final class SparkleUpdateDriver: UpdateChecking, Sendable {
    func checkForUpdate(currentVersion: String) async throws -> UpdateCheckResult? {
        nil
    }
}