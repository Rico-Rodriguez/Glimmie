import Foundation

/// Each game's own save folder: Application Support/Games/<game id>/.
enum GameStorage {
    private static let retiredStableID = "unicornstable"
    static let saveQueue = DispatchQueue(label: "glimmie.storage.save", qos: .utility)

    static var root: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Games", isDirectory: true)
    }

    static func folder(_ game: String) -> URL {
        let url = root.appendingPathComponent(game, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func removeRetiredGameSaves(in root: URL = Self.root) {
        // Older versions used different casing for their dedicated save folders.
        for folder in [retiredStableID, "UnicornStable"] {
            try? FileManager.default.removeItem(at: root.appendingPathComponent(folder, isDirectory: true))
        }
    }

    static func isRetiredGameRecord(_ id: String) -> Bool {
        id.hasPrefix(retiredStableID + "/")
    }

    /// Reads a JSON file from a game's folder, or nil if it is missing or unreadable.
    static func load<T: Decodable>(_ type: T.Type, game: String, file: String) -> T? {
        let url = folder(game).appendingPathComponent(file)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private static func writeAtomically<T: Encodable>(_ value: T, game: String, file: String) {
        let url = folder(game).appendingPathComponent(file)
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// Writes a JSON file into a game's folder atomically.
    static func save<T: Encodable>(_ value: T, game: String, file: String) {
        writeAtomically(value, game: game, file: file)
    }

    /// Encodes and writes a JSON file atomically on `saveQueue` so 60fps gameplay never stalls on disk I/O.
    static func saveAsync<T: Encodable>(_ value: T, game: String, file: String) {
        saveQueue.async {
            writeAtomically(value, game: game, file: file)
        }
    }

    /// Waits for all queued background saves to finish.
    static func flushAsyncSaves() {
        saveQueue.sync {}
    }
}

/// Files bundled for one game, from App/Resources/Games/<game>/.
enum GameFiles {
    static func url(_ name: String, _ ext: String, game: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Games/\(game)")
    }

    static func sound(_ name: String, game: String) -> URL? {
        url(name, "caf", game: game) ?? url(name, "wav", game: game)
    }
}
