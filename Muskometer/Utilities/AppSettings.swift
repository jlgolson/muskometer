import Foundation
import Observation

@Observable
final class AppSettings {
    static let shared = AppSettings()

    private let defaults: UserDefaults
    private let launchAtLoginManager: any LaunchAtLoginManaging

    private enum Keys {
        static let refreshInterval = "refreshIntervalSeconds"
        static let tslaShares = "tslaShareCount"
        static let spcxShares = "spcxShareCount"
        static let selectedPersonID = "selectedPersonID"
        static let menuBarDisplayMode = "menuBarDisplayMode"
        static let showMenuBarIcon = "showMenuBarIcon"
        static let showMergerParityCard = "showMergerParityCard"
        static let lastHoldingsSync = "lastHoldingsSyncDate"
        static let holdingsSyncSource = "holdingsSyncSource"
        static let launchAtLogin = "launchAtLogin"
        static let shareFormat = "shareFormat"
        static let notifyOfAvailableUpdates = "notifyOfAvailableUpdates"
        static let notifyDayCloseSummary = "notifyDayCloseSummary"
    }

    private static func shareCountKey(for symbol: String) -> String {
        "shareCount_\(symbol)"
    }

    private static func lastHoldingsSyncKey(for personID: String) -> String {
        "lastHoldingsSyncDate_\(personID)"
    }

    private static func lastHoldingsSyncAttemptKey(for personID: String) -> String {
        "lastHoldingsSyncAttemptAt_\(personID)"
    }

    private static func holdingsSyncSourceKey(for personID: String) -> String {
        "holdingsSyncSource_\(personID)"
    }

    /// Guards against re-entrant `launchAtLogin` didSet while adopting resolved service state.
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

    /// Advances `menuBarDisplayMode` to the next case (⌥-click on the menu bar label).
    func cycleMenuBarDisplayMode() {
        menuBarDisplayMode = menuBarDisplayMode.next
    }

    var showMenuBarIcon: Bool {
        didSet {
            defaults.set(showMenuBarIcon, forKey: Keys.showMenuBarIcon)
            bumpMenuBarLabelEpoch()
        }
    }

    /// When true, the main popover shows the TSLA↔SPCX market-cap parity card (if data allows).
    var showMergerParityCard: Bool {
        didSet {
            defaults.set(showMergerParityCard, forKey: Keys.showMergerParityCard)
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
    /// Issuer shares outstanding (company totals), independent of Musk Form 4 ownership.
    private(set) var sharesOutstandingBySymbol: [String: Int64] = [:]

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

    /// Issuer outstanding for market-cap parity. Prefers stored positive values, then bundled defaults.
    func sharesOutstanding(for symbol: String) -> Int64 {
        let normalized = symbol.uppercased()
        if let stored = sharesOutstandingBySymbol[normalized], stored > 0 {
            return stored
        }
        return IssuerSharesOutstanding.defaultOutstanding(for: normalized) ?? 0
    }

    /// Persists issuer outstanding when `count > 0`. Keys are independent of ownership `shareCount_*`.
    func setSharesOutstanding(
        _ count: Int64,
        for symbol: String,
        provenance: OutstandingSharesProvenance = .companyfacts(periodEnd: nil, filed: nil)
    ) {
        guard count > 0 else { return }
        let normalized = symbol.uppercased()
        sharesOutstandingBySymbol[normalized] = count
        defaults.set(String(count), forKey: IssuerSharesOutstanding.userDefaultsKey(for: normalized))
        persistOutstandingProvenance(provenance, for: normalized)
    }

    /// Provenance caption for parity / holdings UI (“bundled default · as of …” vs companyfacts).
    func outstandingProvenanceCaption(for symbol: String) -> String {
        let provenance = outstandingProvenance(for: symbol)
        return provenance.caption(defaultAsOf: IssuerSharesOutstanding.defaultAsOfLabel(for: symbol))
    }

    func outstandingProvenance(for symbol: String) -> OutstandingSharesProvenance {
        let normalized = symbol.uppercased()
        let stored = sharesOutstandingBySymbol[normalized]
        return OutstandingSharesProvenance.fromStorage(
            raw: defaults.string(forKey: IssuerSharesOutstanding.provenanceKey(for: normalized)),
            periodEnd: defaults.string(forKey: IssuerSharesOutstanding.periodEndKey(for: normalized)),
            filed: defaults.string(forKey: IssuerSharesOutstanding.filedKey(for: normalized)),
            storedShares: stored,
            defaultShares: IssuerSharesOutstanding.defaultOutstanding(for: normalized)
        )
    }

    private func persistOutstandingProvenance(_ provenance: OutstandingSharesProvenance, for symbol: String) {
        let normalized = symbol.uppercased()
        defaults.set(provenance.storageRawValue, forKey: IssuerSharesOutstanding.provenanceKey(for: normalized))
        switch provenance {
        case .bundledDefault:
            defaults.removeObject(forKey: IssuerSharesOutstanding.periodEndKey(for: normalized))
            defaults.removeObject(forKey: IssuerSharesOutstanding.filedKey(for: normalized))
        case .companyfacts(let periodEnd, let filed):
            if let periodEnd, !periodEnd.isEmpty {
                defaults.set(periodEnd, forKey: IssuerSharesOutstanding.periodEndKey(for: normalized))
            } else {
                defaults.removeObject(forKey: IssuerSharesOutstanding.periodEndKey(for: normalized))
            }
            if let filed, !filed.isEmpty {
                defaults.set(filed, forKey: IssuerSharesOutstanding.filedKey(for: normalized))
            } else {
                defaults.removeObject(forKey: IssuerSharesOutstanding.filedKey(for: normalized))
            }
        }
    }

    var lastHoldingsSyncDate: Date? {
        get { Self.loadLastHoldingsSyncDate(personID: selectedPersonID, defaults: defaults) }
        set { Self.storeLastHoldingsSyncDate(newValue, personID: selectedPersonID, defaults: defaults) }
    }

    /// Last time a holdings sync was *attempted* (complete, partial, or failed).
    /// Used for daily backoff so partial/network failures do not re-crawl every quote cycle.
    var lastHoldingsSyncAttemptAt: Date? {
        get { Self.loadLastHoldingsSyncAttemptAt(personID: selectedPersonID, defaults: defaults) }
        set { Self.storeLastHoldingsSyncAttemptAt(newValue, personID: selectedPersonID, defaults: defaults) }
    }

    var holdingsSyncSource: String? {
        get { Self.loadHoldingsSyncSource(personID: selectedPersonID, defaults: defaults) }
        set { Self.storeHoldingsSyncSource(newValue, personID: selectedPersonID, defaults: defaults) }
    }

    var launchAtLogin: Bool {
        didSet {
            guard !isSyncingLaunchAtLogin else {
                defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
                return
            }
            applyLaunchAtLoginPreference(desired: launchAtLogin)
        }
    }

    /// User-visible message when enabling/disabling launch-at-login fails.
    /// Cleared on a successful apply that matches the system service.
    private(set) var launchAtLoginError: String?

    var shareFormat: ShareFormat {
        didSet {
            defaults.set(shareFormat.rawValue, forKey: Keys.shareFormat)
        }
    }

    var notifyOfAvailableUpdates: Bool {
        didSet {
            defaults.set(notifyOfAvailableUpdates, forKey: Keys.notifyOfAvailableUpdates)
        }
    }

    /// Opt-in local notification summarizing combined paper P&L when a trading day finalizes.
    var notifyDayCloseSummary: Bool {
        didSet {
            defaults.set(notifyDayCloseSummary, forKey: Keys.notifyDayCloseSummary)
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

    /// True when auto-sync should run. Backs off for `holdingsSyncInterval` after any attempt
    /// (complete, partial, or failure). Falls back to last successful complete for upgrades.
    var needsHoldingsSync: Bool {
        let reference = lastHoldingsSyncAttemptAt ?? lastHoldingsSyncDate
        guard let reference else { return true }
        return Date.now.timeIntervalSince(reference) >= Self.holdingsSyncInterval
    }

    /// Records that a holdings sync attempt finished (success, partial, or failure).
    func recordHoldingsSyncAttempt(at date: Date = .now) {
        lastHoldingsSyncAttemptAt = date
    }

    init(
        defaults: UserDefaults = .standard,
        launchAtLoginManager: any LaunchAtLoginManaging = LaunchAtLoginManager.shared
    ) {
        self.defaults = defaults
        self.launchAtLoginManager = launchAtLoginManager

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

        if defaults.object(forKey: Keys.showMergerParityCard) != nil {
            self.showMergerParityCard = defaults.bool(forKey: Keys.showMergerParityCard)
        } else {
            self.showMergerParityCard = true
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
        self.sharesOutstandingBySymbol = Self.loadSharesOutstanding(defaults: defaults)

        self.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)

        if let rawFormat = defaults.string(forKey: Keys.shareFormat),
           let format = ShareFormat(rawValue: rawFormat) {
            self.shareFormat = format
        } else {
            self.shareFormat = .image
        }

        if defaults.object(forKey: Keys.notifyOfAvailableUpdates) != nil {
            self.notifyOfAvailableUpdates = defaults.bool(forKey: Keys.notifyOfAvailableUpdates)
        } else {
            self.notifyOfAvailableUpdates = false
        }

        if defaults.object(forKey: Keys.notifyDayCloseSummary) != nil {
            self.notifyDayCloseSummary = defaults.bool(forKey: Keys.notifyDayCloseSummary)
        } else {
            self.notifyDayCloseSummary = false
        }

        // One-shot cleanup of removed features / unscoped legacy keys.
        Self.purgeObsoleteDefaults(defaults: defaults)
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

    private static func loadLastHoldingsSyncAttemptAt(personID: String, defaults: UserDefaults) -> Date? {
        let key = lastHoldingsSyncAttemptKey(for: personID)
        let interval = defaults.double(forKey: key)
        return interval > 0 ? Date(timeIntervalSince1970: interval) : nil
    }

    private static func storeLastHoldingsSyncAttemptAt(_ date: Date?, personID: String, defaults: UserDefaults) {
        let key = lastHoldingsSyncAttemptKey(for: personID)
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
        guard loadLastHoldingsSyncDate(personID: muskID, defaults: defaults) == nil else {
            // Person-scoped key already exists — still drop unscoped leftovers.
            defaults.removeObject(forKey: Keys.lastHoldingsSync)
            defaults.removeObject(forKey: Keys.holdingsSyncSource)
            return
        }

        let legacySync = defaults.double(forKey: Keys.lastHoldingsSync)
        if legacySync > 0 {
            storeLastHoldingsSyncDate(Date(timeIntervalSince1970: legacySync), personID: muskID, defaults: defaults)
        }

        if let legacySource = defaults.string(forKey: Keys.holdingsSyncSource) {
            storeHoldingsSyncSource(legacySource, personID: muskID, defaults: defaults)
        }

        defaults.removeObject(forKey: Keys.lastHoldingsSync)
        defaults.removeObject(forKey: Keys.holdingsSyncSource)
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

        defaults.removeObject(forKey: Keys.tslaShares)
        defaults.removeObject(forKey: Keys.spcxShares)
    }

    private static func loadShareCounts(defaults: UserDefaults) -> [String: Int64] {
        var counts: [String: Int64] = [:]

        for profile in TrackedPersonProfile.registry {
            for spec in profile.holdingSpecs {
                let key = shareCountKey(for: spec.symbol)
                if let stored = defaults.string(forKey: key), let value = Int64(stored) {
                    if spec.symbol == "SPCX" {
                        // Re-migrate legacy fingerprints already under shareCount_SPCX
                        // (migrateLegacyShareCounts only runs when the new key is missing).
                        let migrated = SPCXHoldings.migrateStoredShareCount(value)
                        if migrated != value {
                            defaults.set(String(migrated), forKey: key)
                        }
                        counts[spec.symbol] = migrated
                    } else if spec.symbol == "TSLA" {
                        // Old bundled TSLA default → current Form 4 last direct common.
                        let legacyTSLADefault: Int64 = 699_580_882
                        let migrated = value == legacyTSLADefault ? spec.defaultShareCount : value
                        if migrated != value {
                            defaults.set(String(migrated), forKey: key)
                        }
                        counts[spec.symbol] = migrated
                    } else {
                        counts[spec.symbol] = value
                    }
                }
            }
        }

        return counts
    }

    private static func loadSharesOutstanding(defaults: UserDefaults) -> [String: Int64] {
        var counts: [String: Int64] = [:]

        for profile in TrackedPersonProfile.registry {
            for spec in profile.holdingSpecs {
                let normalized = spec.symbol.uppercased()
                let key = IssuerSharesOutstanding.userDefaultsKey(for: normalized)
                if let stored = defaults.string(forKey: key),
                   let value = Int64(stored),
                   value > 0 {
                    let migrated = IssuerSharesOutstanding.migrateStoredOutstanding(value, symbol: normalized)
                    if migrated != value {
                        defaults.set(String(migrated), forKey: key)
                    }
                    counts[normalized] = migrated
                }
            }
        }

        return counts
    }

    func syncLaunchAtLoginFromService() {
        let desired = launchAtLogin
        let actual = launchAtLoginManager.isEnabled

        if desired != actual {
            // Re-apply desired preference. Soft enable (pending Login Items approval)
            // keeps desired=true rather than adopting the still-disabled service state.
            applyLaunchAtLoginPreference(desired: desired)
        } else {
            launchAtLoginError = nil
            persistLaunchAtLoginPreference(desired)
        }
    }

    /// Registers/unregisters with the system service, then reconciles local state.
    ///
    /// - Thrown failures: surface error and adopt service reality.
    /// - Non-throwing enable that leaves the service disabled (common when
    ///   `SMAppService` is `.requiresApproval`): keep desired `true`, persist it,
    ///   and show a pending-approval message — do not adopt false.
    /// - Non-throwing disable that leaves the service enabled: surface mismatch
    ///   and adopt service reality.
    /// - Full match: clear error and persist desired.
    private func applyLaunchAtLoginPreference(desired: Bool) {
        do {
            try launchAtLoginManager.setEnabled(desired)
            let actual = launchAtLoginManager.isEnabled

            if actual == desired {
                launchAtLoginError = nil
                persistLaunchAtLoginPreference(desired)
                return
            }

            if desired {
                // Soft enable: registration did not throw but the service is not yet
                // enabled (typically awaiting Login Items approval). Preserve intent.
                launchAtLoginError = Self.launchAtLoginPendingApprovalMessage
                persistLaunchAtLoginPreference(true)
                ensureLaunchAtLoginToggle(true)
                return
            }

            // Soft disable mismatch: service still enabled — adopt reality.
            launchAtLoginError = Self.launchAtLoginMismatchMessage(desired: false)
            adoptResolvedLaunchAtLoginState()
        } catch {
            launchAtLoginError = Self.launchAtLoginFailureMessage(desired: desired, error: error)
            adoptResolvedLaunchAtLoginState()
        }
    }

    private func persistLaunchAtLoginPreference(_ value: Bool) {
        defaults.set(value, forKey: Keys.launchAtLogin)
    }

    /// Updates the in-memory toggle without re-entering `applyLaunchAtLoginPreference`.
    private func ensureLaunchAtLoginToggle(_ value: Bool) {
        guard launchAtLogin != value else { return }
        isSyncingLaunchAtLogin = true
        launchAtLogin = value
        isSyncingLaunchAtLogin = false
    }

    /// Reads `isEnabled` and forces `launchAtLogin` + UserDefaults to match, without re-applying.
    private func adoptResolvedLaunchAtLoginState() {
        let resolved = launchAtLoginManager.isEnabled
        persistLaunchAtLoginPreference(resolved)
        ensureLaunchAtLoginToggle(resolved)
    }

    private static func launchAtLoginFailureMessage(desired: Bool, error: Error) -> String {
        let action = desired ? "enable" : "disable"
        return "Couldn't \(action) launch at login: \(error.localizedDescription)"
    }

    private static func launchAtLoginMismatchMessage(desired: Bool) -> String {
        let action = desired ? "enable" : "disable"
        return "Couldn't \(action) launch at login. Check System Settings → General → Login Items."
    }

    private static let launchAtLoginPendingApprovalMessage =
        "Launch at login is waiting for approval in System Settings → General → Login Items."

    func resetToDefaults() {
        refreshIntervalSeconds = Self.defaultRefreshInterval
        menuBarDisplayMode = .combinedDollars
        showMenuBarIcon = true
        showMergerParityCard = true
        shareFormat = .image
        notifyOfAvailableUpdates = false
        notifyDayCloseSummary = false
        selectedPersonID = TrackedPersonProfile.musk.id

        for spec in selectedProfile.holdingSpecs {
            setShareCount(spec.defaultShareCount, for: spec.symbol)
            if let defaultOutstanding = IssuerSharesOutstanding.defaultOutstanding(for: spec.symbol) {
                setSharesOutstanding(defaultOutstanding, for: spec.symbol, provenance: .bundledDefault)
            }
        }

        lastHoldingsSyncDate = nil
        lastHoldingsSyncAttemptAt = nil
        holdingsSyncSource = nil

        // Product default: launch at login is off. Prefer the property path so
        // didSet routes through LaunchAtLoginManager; if already false, re-apply
        // so any stale error is cleared and the service stays in sync.
        if launchAtLogin {
            launchAtLogin = false
        } else {
            applyLaunchAtLoginPreference(desired: false)
        }

        Self.resetPersistedState(for: selectedPersonID, defaults: defaults)
    }

    private static func resetPersistedState(for personID: String, defaults: UserDefaults) {
        GainThresholdNotificationService.resetPersistedState(for: personID, defaults: defaults)
        DayCloseSummaryNotificationService.resetPersistedState(for: personID, defaults: defaults)
        NetWorthMilestoneTracker.resetPersistedState(for: personID, defaults: defaults)
        IntradayGainSampleStore.resetPersistedState(for: personID, defaults: defaults)
        DailyRecordTracker.resetPersistedState(for: personID, defaults: defaults)
        purgeObsoleteDefaults(defaults: defaults)
    }

    /// Deletes leftovers from removed features and unscoped legacy keys.
    private static func purgeObsoleteDefaults(defaults: UserDefaults) {
        defaults.removeObject(forKey: "updateDeliveryMode")
        defaults.removeObject(forKey: "comparisonHistoryEntries")
        defaults.removeObject(forKey: Keys.tslaShares)
        defaults.removeObject(forKey: Keys.spcxShares)
        defaults.removeObject(forKey: Keys.lastHoldingsSync)
        defaults.removeObject(forKey: Keys.holdingsSyncSource)
        var personIDs = Set(TrackedPersonProfile.registry.map(\.id))
        personIDs.insert(TrackedPersonProfile.musk.id)
        for personID in personIDs {
            defaults.removeObject(forKey: "comparisonHistoryEntries_\(personID)")
        }
    }

    @discardableResult
    func applyHoldingsSync(_ result: HoldingsSyncResult) -> Bool {
        let expectedSymbols = selectedProfile.expectedSymbols

        // Presence (including 0 for full disposal) counts as found; negatives are ignored.
        let foundSymbols = Set(
            result.sharesBySymbol
                .filter { expectedSymbols.contains($0.key) && $0.value >= 0 }
                .map(\.key)
        )
        let isComplete = expectedSymbols.isSubset(of: foundSymbols)

        // Always record the attempt so auto-retry backs off for 24h even on partial results.
        // Partial results keep prior counts and leave lastHoldingsSyncDate unset.
        recordHoldingsSyncAttempt(at: result.syncedAt)

        guard isComplete else {
            return false
        }

        for (symbol, shares) in result.sharesBySymbol where shares >= 0 {
            if expectedSymbols.contains(symbol) {
                setShareCount(shares, for: symbol)
            }
        }

        lastHoldingsSyncDate = result.syncedAt
        holdingsSyncSource = result.sourceDescription

        return true
    }
}