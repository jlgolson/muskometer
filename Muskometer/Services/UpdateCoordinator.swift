import Foundation
import Observation
import UserNotifications

protocol UpdateNotificationDelivering: Sendable {
    func add(_ request: UNNotificationRequest) async throws
}

struct SystemUpdateNotificationDeliverer: UpdateNotificationDelivering {
    func add(_ request: UNNotificationRequest) async throws {
        try await UNUserNotificationCenter.current().add(request)
    }
}

@Observable
@MainActor
final class UpdateCoordinator {
    static let notificationCategoryID = "org.muskometer.app.update-available"
    static let schedulerIdentifier = "org.muskometer.app.update-check"
    static let notificationDebounceInterval: TimeInterval = 86_400
    static let checkInterval: TimeInterval = 86_400

    private(set) var isChecking = false
    private(set) var lastCheckDate: Date?
    private(set) var lastCheckError: String?
    private(set) var manualCheckSummary: String?
    private(set) var availableUpdate: UpdateCheckResult?

    private let settings: AppSettings
    private let defaults: UserDefaults
    private let notificationDeliverer: any UpdateNotificationDelivering
    private let githubChecker: any UpdateChecking
    private let sparkleDriver: any UpdateChecking
    private var scheduler: NSBackgroundActivityScheduler?
    private var isSchedulerActive = false
    private var checkTask: Task<Void, Never>?

    private enum Keys {
        static let lastNotifiedAvailableVersion = "lastNotifiedAvailableVersion"
        static let lastNotifiedAt = "lastNotifiedAvailableVersionAt"
    }

    init(
        settings: AppSettings,
        defaults: UserDefaults = .standard,
        notificationDeliverer: any UpdateNotificationDelivering = SystemUpdateNotificationDeliverer(),
        githubChecker: any UpdateChecking = GitHubReleaseUpdateChecker(),
        sparkleDriver: any UpdateChecking = SparkleUpdateDriver()
    ) {
        self.settings = settings
        self.defaults = defaults
        self.notificationDeliverer = notificationDeliverer
        self.githubChecker = githubChecker
        self.sparkleDriver = sparkleDriver
    }

    func start() {
        guard settings.notifyOfAvailableUpdates else {
            stop()
            return
        }

        scheduleBackgroundChecksIfNeeded()

        guard checkTask == nil else { return }
        checkTask = Task { [weak self] in
            await self?.performCheck(userInitiated: false)
            self?.checkTask = nil
        }
    }

    func stop() {
        checkTask?.cancel()
        checkTask = nil
        scheduler?.invalidate()
        scheduler = nil
        isSchedulerActive = false
    }

    static func resetNotificationDebounce(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: Keys.lastNotifiedAvailableVersion)
        defaults.removeObject(forKey: Keys.lastNotifiedAt)
    }

    func checkNow() {
        guard !isChecking else { return }

        checkTask?.cancel()
        checkTask = Task { [weak self] in
            await self?.performCheck(userInitiated: true)
            self?.checkTask = nil
        }
    }

    private func scheduleBackgroundChecksIfNeeded() {
        guard !isSchedulerActive else { return }

        let scheduler = NSBackgroundActivityScheduler(identifier: Self.schedulerIdentifier)
        scheduler.repeats = true
        scheduler.interval = Self.checkInterval
        scheduler.tolerance = 3_600

        scheduler.schedule { [weak self] completion in
            Task { @MainActor [weak self] in
                await self?.performCheck(userInitiated: false)
                completion(.finished)
            }
        }

        self.scheduler = scheduler
        isSchedulerActive = true
    }

    private func checker(for mode: UpdateDeliveryMode) -> any UpdateChecking {
        switch mode {
        case .notifyOnly:
            return githubChecker
        case .automatic:
            return sparkleDriver
        }
    }

    private func performCheck(userInitiated: Bool) async {
        guard !isChecking else { return }

        isChecking = true
        defer { isChecking = false }

        if userInitiated {
            lastCheckError = nil
            manualCheckSummary = nil
        }

        let currentVersion = AppVersion.short

        do {
            let result = try await checker(for: settings.updateDeliveryMode)
                .checkForUpdate(currentVersion: currentVersion)

            lastCheckDate = .now
            availableUpdate = result

            if userInitiated {
                if let result {
                    manualCheckSummary = "Version \(result.availableVersion) is available."
                } else {
                    manualCheckSummary = "You're on the latest version (\(currentVersion))."
                }
            }

            if let result, shouldNotify(for: result) {
                await postUpdateNotification(for: result)
            }
        } catch {
            lastCheckDate = .now
            if userInitiated {
                lastCheckError = error.localizedDescription
                manualCheckSummary = nil
                availableUpdate = nil
            }
        }
    }

    private func shouldNotify(for result: UpdateCheckResult) -> Bool {
        guard settings.notifyOfAvailableUpdates else { return false }
        guard settings.updateDeliveryMode == .notifyOnly else { return false }

        let lastVersion = defaults.string(forKey: Keys.lastNotifiedAvailableVersion)
        let lastNotifiedAt = defaults.double(forKey: Keys.lastNotifiedAt)

        if lastVersion == result.availableVersion,
           lastNotifiedAt > 0,
           Date.now.timeIntervalSince(Date(timeIntervalSince1970: lastNotifiedAt)) < Self.notificationDebounceInterval {
            return false
        }

        return true
    }

    private func postUpdateNotification(for result: UpdateCheckResult) async {
        let content = UNMutableNotificationContent()
        content.title = "Muskometer update available"
        content.body = "Version \(result.availableVersion) is available. Open the release page to download."
        content.userInfo = ["releaseURL": result.releasePageURL.absoluteString]
        content.categoryIdentifier = Self.notificationCategoryID

        let request = UNNotificationRequest(
            identifier: "muskometer-update-\(result.availableVersion)",
            content: content,
            trigger: nil
        )

        do {
            try await notificationDeliverer.add(request)
            defaults.set(result.availableVersion, forKey: Keys.lastNotifiedAvailableVersion)
            defaults.set(Date.now.timeIntervalSince1970, forKey: Keys.lastNotifiedAt)
        } catch {
            // Notification permission denied or delivery failed — ignore.
        }
    }
}