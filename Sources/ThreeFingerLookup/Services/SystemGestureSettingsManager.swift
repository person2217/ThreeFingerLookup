import Foundation

final class SystemGestureSettingsManager {
    private struct Backup: Codable {
        let original: [String: Int]
        let written: [String: Int]
    }
    private let domains = [
        "com.apple.AppleMultitouchTrackpad",
        "com.apple.driver.AppleBluetoothMultitouch.trackpad"
    ]
    private let key = "TrackpadThreeFingerTapGesture"
    private var originalValues: [String: Int] = [:]
    private var writtenValues: [String: Int] = [:]
    private var ownsChanges = false

    func prepareForPlugin() {
        if ownsChanges { return }
        restorePersistedBackupIfNeeded()
        originalValues = Dictionary(uniqueKeysWithValues: domains.map { ($0, read(domain: $0)) })
        writtenValues = Dictionary(uniqueKeysWithValues: domains.map { ($0, 0) })
        ownsChanges = true
        persistBackup()
        domains.forEach { write(value: 0, domain: $0) }
    }

    func restoreIfOwned() {
        guard ownsChanges else {
            restorePersistedBackupIfNeeded()
            return
        }
        for domain in domains {
            guard let original = originalValues[domain], read(domain: domain) == writtenValues[domain] else { continue }
            write(value: original, domain: domain)
        }
        clearBackup()
        ownsChanges = false
    }

    func enforceDisabledIfOwned() {
        guard ownsChanges else { return }
        for domain in domains where read(domain: domain) != 0 {
            write(value: 0, domain: domain)
        }
    }

    private func read(domain: String) -> Int {
        guard let value = CFPreferencesCopyAppValue(key as CFString, domain as CFString) as? NSNumber else {
            return 0
        }
        return value.intValue
    }

    private func write(value: Int, domain: String) {
        CFPreferencesSetAppValue(key as CFString, NSNumber(value: value), domain as CFString)
        CFPreferencesAppSynchronize(domain as CFString)
    }

    private var backupURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/ThreeFingerLookup")
            .appendingPathComponent("gesture-backup.json")
    }

    private func persistBackup() {
        let directory = backupURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(Backup(original: originalValues, written: writtenValues)) {
            try? data.write(to: backupURL, options: .atomic)
        }
    }

    private func restorePersistedBackupIfNeeded() {
        guard let data = try? Data(contentsOf: backupURL),
              let backup = try? JSONDecoder().decode(Backup.self, from: data) else { return }
        for domain in domains {
            guard let oldValue = backup.original[domain], read(domain: domain) == backup.written[domain] else { continue }
            write(value: oldValue, domain: domain)
        }
        clearBackup()
    }

    private func clearBackup() {
        try? FileManager.default.removeItem(at: backupURL)
    }
}
