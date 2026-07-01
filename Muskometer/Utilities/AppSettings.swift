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
        static let selectedPersonID = "selectedPersonID"
        static let menuBarDisplayMode = "menuBarDisplayMode"
        static let showMenuBarIcon = "showMenuBarIcon"
        static let lastHoldingsSync = "lastHoldingsSyncDate"
        static let holdingsSyncSource = "holdingsSyncSource"
        static let launchAtLogin = "launchAtLogin"
    }

    private static func shareCountKey(for symbol: String) -> String {
        "shareCount_\(symbol)"
    }

    private static func lastHoldingsSyncKey(for personID: String) -> String {
        "lastHoldingsSyncDate_\(personID)"
    }

    private static func holdingsSyncSourceKey(for personID: String) -> String {
        "holdingsSyncSource_\(personID)"
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

    private(set) var menuBarLabelEpoch = 0

    var menuBarDisplayMode: MenuBarDisplayMode {
        didSet {
            defaults.set(menuBarDisplayMode.rawValue, forKey: Keys.menuBarDisplayMode)
            bumpMenuBarLabelEpoch()
        }
    }

    var showMenuBarIcon: Bool {
        didSet {
            defaults.set(showMenuBarIcon, forKey: Keys.showMenuBarIcon)
            bumpMenuBarLabelEpoch()
        }
    }

    private func bumpMenuBarLabelEpoch() {
        menuBarLabelEpoch += 1
    }

    var selectedPersonID: String {
        didSet {
            defaults.set(selectedPersonID, forKey: Keys.selectedPersonID)
        }
    }

    private(set) var shareCountsBySymbol: [String: Int64] = [:]

    var selectedProfile: TrackedPersonProfile {
        TrackedPersonProfile.profile(for: selectedPersonID)
    }

    func shareCount(for symbol: String) -> Int64 {
        if let stored = shareCountsBySymbol[symbol] {
            return stored
        }
        return selectedProfile.holdingSpecs.first { $0.symbol == symbol }?.defaultShareCount ?? 0
    }

    func setShareCount(_ count: Int64, for symbol: String) {
        shareCountsBySymbol[symbol] = count
        defaults.set(String(count), forKey: Self.shareCountKey(for: symbol))
    }

    var lastHoldingsSyncDate: Date? {
        get { Self.loadLastHoldingsSyncDate(personID: selectedPersonID, defaults: defaults) }
        set { Self.storeLastHoldingsSyncDate(newValue, personID: selectedPersonID, defaults: defaults) }
    }

    var holdingsSyncSource: String? {
        get { Self.loadHoldingsSyncSource(personID: selectedPersonID, defaults: defaults) }
        set { Self.storeHoldingsSyncSource(newValue, personID: selectedPersonID, defaults: defaults) }
    }

    var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
            guard !isSyncingLaunchAtLogin else { return }
            try? LaunchAtLoginManager.setEnabled(launchAtLogin)
        }
    }

    var holdings: [PortfolioHolding] {
        selectedProfile.holdingSpecs.map { spec in
            PortfolioHolding(
                id: spec.id,
                symbol: spec.symbol,
                displayName: spec.displayName,
                shareCount: shareCount(for: spec.symbol)
            )
        }
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

        if defaults.object(forKey: Keys.showMenuBarIcon) != nil {
            self.showMenuBarIcon = defaults.bool(forKey: Keys.showMenuBarIcon)
        } else {
            self.showMenuBarIcon = true
        }

        if let storedPersonID = defaults.string(forKey: Keys.selectedPersonID),
           TrackedPersonProfile.registry.contains(where: { $0.id == storedPersonID }) {
            self.selectedPersonID = storedPersonID
        } else {
            self.selectedPersonID = TrackedPersonProfile.musk.id
        }

        Self.migrateLegacyShareCounts(defaults: defaults)
        Self.migrateLegacyHoldingsSyncMetadata(defaults: defaults)
        self.shareCountsBySymbol = Self.loadShareCounts(defaults: defaults)

        self.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
    }

    private static func loadLastHoldingsSyncDate(personID: String, defaults: UserDefaults) -> Date? {
        let key = lastHoldingsSyncKey(for: personID)
        let interval = defaults.double(forKey: key)
        return interval > 0 ? Date(timeIntervalSince1970: interval) : nil
    }

    private static func storeLastHoldingsSyncDate(_ date: Date?, personID: String, defaults: UserDefaults) {
        let key = lastHoldingsSyncKey(for: personID)
        if let date {
            defaults.set(date.timeIntervalSince1970, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    private static func loadHoldingsSyncSource(personID: String, defaults: UserDefaults) -> String? {
        defaults.string(forKey: holdingsSyncSourceKey(for: personID))
    }

    private static func storeHoldingsSyncSource(_ source: String?, personID: String, defaults: UserDefaults) {
        let key = holdingsSyncSourceKey(for: personID)
        if let source {
            defaults.set(source, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    private static func migrateLegacyHoldingsSyncMetadata(defaults: UserDefaults) {
        let muskID = TrackedPersonProfile.musk.id
        guard loadLastHoldingsSyncDate(personID: muskID, defaults: defaults) == nil else { return }

        let legacySync = defaults.double(forKey: Keys.lastHoldingsSync)
        if legacySync > 0 {
            storeLastHoldingsSyncDate(Date(timeIntervalSince1970: legacySync), personID: muskID, defaults: defaults)
        }

        if let legacySource = defaults.string(forKey: Keys.holdingsSyncSource) {
            storeHoldingsSyncSource(legacySource, personID: muskID, defaults: defaults)
        }
    }

    private static func migrateLegacyShareCounts(defaults: UserDefaults) {
        if defaults.string(forKey: shareCountKey(for: "TSLA")) == nil,
           let storedTSLA = defaults.string(forKey: Keys.tslaShares),
           let value = Int64(storedTSLA) {
            defaults.set(String(value), forKey: shareCountKey(for: "TSLA"))
        }

        if defaults.string(forKey: shareCountKey(for: "SPCX")) == nil,
           let storedSPCX = defaults.string(forKey: Keys.spcxShares),
           let value = Int64(storedSPCX) {
            let migrated = SPCXHoldings.migrateStoredShareCount(value)
            defaults.set(String(migrated), forKey: shareCountKey(for: "SPCX"))
        }
    }

    private static func loadShareCounts(defaults: UserDefaults) -> [String: Int64] {
        var counts: [String: Int64] = [:]

        for profile in TrackedPersonProfile.registry {
            for spec in profile.holdingSpecs {
                let key = shareCountKey(for: spec.symbol)
                if let stored = defaults.string(forKey: key), let value = Int64(stored) {
                    counts[spec.symbol] = value
                }
            }
        }

        return counts
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
        showMenuBarIcon = true
        selectedPersonID = TrackedPersonProfile.musk.id

        for spec in selectedProfile.holdingSpecs {
            setShareCount(spec.defaultShareCount, for: spec.symbol)
        }

        lastHoldingsSyncDate = nil
        holdingsSyncSource = nil
    }

    @discardableResult
    func applyHoldingsSync(_ result: HoldingsSyncResult) -> Bool {
        let expectedSymbols = selectedProfile.expectedSymbols

        for (symbol, shares) in result.sharesBySymbol where shares > 0 {
            if expectedSymbols.contains(symbol) {
                setShareCount(shares, for: symbol)
            }
        }

        let foundSymbols = Set(
            result.sharesBySymbol
                .filter { expectedSymbols.contains($0.key) && $0.value > 0 }
                .map(\.key)
        )
        let isComplete = expectedSymbols.isSubset(of: foundSymbols)

        if isComplete {
            lastHoldingsSyncDate = result.syncedAt
            holdingsSyncSource = result.sourceDescription
        }

        return isComplete
    }
}