import Foundation
import Observation

@Observable
final class AppSettings {
    static let shared = AppSettings()

    private let defaults: UserDefaults

    private enum Keys {
        static let refreshInterval = "refreshIntervalSeconds"
        static let tslaShares = "tslaShareCount"
        static let spcxShares = "spcxShareCount"
        static let menuBarDisplayMode = "menuBarDisplayMode"
        static let lastHoldingsSync = "lastHoldingsSyncDate"
        static let holdingsSyncSource = "holdingsSyncSource"
        static let launchAtLogin = "launchAtLogin"
    }

    private var isSyncingLaunchAtLogin = false

    static let minRefreshInterval: TimeInterval = 60
    static let maxRefreshInterval: TimeInterval = 120
    static let defaultRefreshInterval: TimeInterval = 90
    static let holdingsSyncInterval: TimeInterval = 86_400

    var refreshIntervalSeconds: TimeInterval {
        didSet {
            let clamped = min(max(refreshIntervalSeconds, Self.minRefreshInterval), Self.maxRefreshInterval)
            guard clamped == refreshIntervalSeconds else {
                refreshIntervalSeconds = clamped
                return
            }
            defaults.set(clamped, forKey: Keys.refreshInterval)
        }
    }

    var menuBarDisplayMode: MenuBarDisplayMode {
        didSet {
            defaults.set(menuBarDisplayMode.rawValue, forKey: Keys.menuBarDisplayMode)
        }
    }

    var tslaShareCount: Int64 {
        didSet {
            defaults.set(String(tslaShareCount), forKey: Keys.tslaShares)
        }
    }

    var spcxShareCount: Int64 {
        didSet {
            defaults.set(String(spcxShareCount), forKey: Keys.spcxShares)
        }
    }

    var lastHoldingsSyncDate: Date? {
        didSet {
            if let lastHoldingsSyncDate {
                defaults.set(lastHoldingsSyncDate.timeIntervalSince1970, forKey: Keys.lastHoldingsSync)
            } else {
                defaults.removeObject(forKey: Keys.lastHoldingsSync)
            }
        }
    }

    var holdingsSyncSource: String? {
        didSet {
            if let holdingsSyncSource {
                defaults.set(holdingsSyncSource, forKey: Keys.holdingsSyncSource)
            } else {
                defaults.removeObject(forKey: Keys.holdingsSyncSource)
            }
        }
    }

    var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
            guard !isSyncingLaunchAtLogin else { return }
            try? LaunchAtLoginManager.setEnabled(launchAtLogin)
        }
    }

    var holdings: [PortfolioHolding] {
        [
            PortfolioHolding(
                id: "tsla",
                symbol: "TSLA",
                displayName: "Tesla",
                shareCount: tslaShareCount
            ),
            PortfolioHolding(
                id: "spcx",
                symbol: "SPCX",
                displayName: "SpaceX",
                shareCount: spcxShareCount
            )
        ]
    }

    var needsHoldingsSync: Bool {
        guard let lastHoldingsSyncDate else { return true }
        return Date.now.timeIntervalSince(lastHoldingsSyncDate) >= Self.holdingsSyncInterval
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let storedInterval = defaults.double(forKey: Keys.refreshInterval)
        let initialInterval = storedInterval > 0 ? storedInterval : Self.defaultRefreshInterval
        self.refreshIntervalSeconds = min(max(initialInterval, Self.minRefreshInterval), Self.maxRefreshInterval)

        if let rawMode = defaults.string(forKey: Keys.menuBarDisplayMode),
           let mode = MenuBarDisplayMode(rawValue: rawMode) {
            self.menuBarDisplayMode = mode
        } else {
            self.menuBarDisplayMode = .combinedDollars
        }

        if let storedTSLA = defaults.string(forKey: Keys.tslaShares), let value = Int64(storedTSLA) {
            self.tslaShareCount = value
        } else {
            self.tslaShareCount = 699_580_882
        }

        if let storedSPCX = defaults.string(forKey: Keys.spcxShares), let value = Int64(storedSPCX) {
            let migrated = SPCXHoldings.migrateStoredShareCount(value)
            self.spcxShareCount = migrated
            if migrated != value {
                defaults.set(String(migrated), forKey: Keys.spcxShares)
            }
        } else {
            self.spcxShareCount = SPCXHoldings.defaultShareCount
        }

        let lastSync = defaults.double(forKey: Keys.lastHoldingsSync)
        self.lastHoldingsSyncDate = lastSync > 0 ? Date(timeIntervalSince1970: lastSync) : nil
        self.holdingsSyncSource = defaults.string(forKey: Keys.holdingsSyncSource)
        self.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
    }

    func syncLaunchAtLoginFromService() {
        isSyncingLaunchAtLogin = true
        defer { isSyncingLaunchAtLogin = false }

        let desired = launchAtLogin
        let actual = LaunchAtLoginManager.isEnabled

        if desired != actual {
            try? LaunchAtLoginManager.setEnabled(desired)
        }

        let resolved = LaunchAtLoginManager.isEnabled
        if launchAtLogin != resolved {
            launchAtLogin = resolved
        }
        defaults.set(resolved, forKey: Keys.launchAtLogin)
    }

    func resetToDefaults() {
        refreshIntervalSeconds = Self.defaultRefreshInterval
        menuBarDisplayMode = .combinedDollars
        tslaShareCount = 699_580_882
        spcxShareCount = SPCXHoldings.defaultShareCount
        lastHoldingsSyncDate = nil
        holdingsSyncSource = nil
    }

    @discardableResult
    func applyHoldingsSync(_ result: HoldingsSyncResult) -> Bool {
        if let tsla = result.tslaShares, tsla > 0 {
            tslaShareCount = tsla
        }
        if let spcx = result.spcxShares, spcx > 0 {
            spcxShareCount = spcx
        }

        let isComplete = result.tslaShares.map { $0 > 0 } == true
            && result.spcxShares.map { $0 > 0 } == true

        if isComplete {
            lastHoldingsSyncDate = result.syncedAt
            holdingsSyncSource = result.sourceDescription
        }

        return isComplete
    }
}