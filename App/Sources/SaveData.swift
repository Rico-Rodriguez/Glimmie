import Foundation

// MARK: - Save data
//
// Everything in this file is stored on her iPad, and every update must still load it.
// Before you change it:
//
// 1. Adding a field: give it a default value, read it in `init(from:)` with `c.value(.name, default:)`,
//    wire it into GameState (init and save), and give it a non-default value in
//    `SaveDataTests.everyField`. The tests fail if a field is missed.
// 2. Never rename a field or change its type: old saves would lose it. Add a new field instead,
//    convert the old one in `GameState.sanitized`, and bump `SaveData.currentVersion`.
// 3. A new feature's data goes in its own top-level field (or its own key, like Glimmie House),
//    so an older build installed over a newer one leaves it untouched.
// 4. Never change `SaveStore.key`.

extension KeyedDecodingContainer {
    /// The value for `key`, or `fallback` when it is missing or unreadable.
    /// One bad field never fails the whole save.
    func value<T: Decodable>(_ key: Key, default fallback: T) -> T {
        (try? decodeIfPresent(T.self, forKey: key)) ?? fallback
    }

    /// An array that skips unreadable elements instead of failing.
    func lenientArray<T: Decodable>(_ key: Key, default fallback: [T]) -> [T] {
        guard let raw = try? decodeIfPresent([Lenient<T>].self, forKey: key) else { return fallback }
        return raw.compactMap { $0.value }
    }

    /// A dictionary that skips unreadable values instead of failing.
    func lenientDictionary<T: Decodable>(_ key: Key, default fallback: [String: T]) -> [String: T] {
        guard let raw = try? decodeIfPresent([String: Lenient<T>].self, forKey: key) else { return fallback }
        return raw.compactMapValues { $0.value }
    }
}

/// Decodes a value if it can, and nil otherwise, without failing its container.
private struct Lenient<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) throws { value = try? T(from: decoder) }
}

struct Avatar: Codable, Equatable {
    var skin = 1
    var hairStyle = 1
    var hairColor = 0
    var eyes = 0
}

extension Avatar {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Avatar()
        skin = c.value(.skin, default: d.skin)
        hairStyle = c.value(.hairStyle, default: d.hairStyle)
        hairColor = c.value(.hairColor, default: d.hairColor)
        eyes = c.value(.eyes, default: d.eyes)
    }
}

struct Worn: Codable, Equatable {
    var item: String
    var color: Int
}

extension Worn {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        item = try c.decode(String.self, forKey: .item)   // no item, nothing to wear: the entry is skipped
        color = c.value(.color, default: 0)
    }
}

struct SaveData: Codable, Equatable {
    /// Bump only together with a conversion in `GameState.sanitized`. Saves from before versioning are 1.
    static let currentVersion = 2

    var version = SaveData.currentVersion
    var madeAvatar = false
    var avatar = Avatar()
    var outfit: [String: Worn] = ["dress": Worn(item: "dress_aline", color: 0),
                                  "shoes": Worn(item: "shoes_mary", color: 1)]
    var stars = 0
    var wishesDone = 0
    var owned: [Int] = [0]
    var secrets: [String] = []
    var eggWaiting = false
    /// The Sparkle Path: how far she has got, and the treasures found on it.
    var adventure = AdventureSave()

    /// The stored property names, which are also the JSON keys.
    static let fieldNames = Set(Mirror(reflecting: SaveData()).children.compactMap { $0.label })
}

extension SaveData {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = SaveData()
        version = c.value(.version, default: 1)
        madeAvatar = c.value(.madeAvatar, default: d.madeAvatar)
        avatar = c.value(.avatar, default: d.avatar)
        outfit = c.lenientDictionary(.outfit, default: d.outfit)
        stars = c.value(.stars, default: d.stars)
        wishesDone = c.value(.wishesDone, default: d.wishesDone)
        owned = c.lenientArray(.owned, default: d.owned)
        secrets = c.lenientArray(.secrets, default: d.secrets)
        eggWaiting = c.value(.eggWaiting, default: d.eggWaiting)
        adventure = c.value(.adventure, default: d.adventure)
    }
}

/// Progress on the Sparkle Path (Adventure.swift).
struct AdventureSave: Codable, Equatable {
    /// Stops finished. The path never ends: worlds repeat, a little harder each time.
    var stop = 0
    /// Stage backdrops found in treasure chests (Backdrops.all ids), in the order found.
    var backdrops: [String] = []
    /// The backdrop on the boutique stage. "" = the classic pink stage.
    var backdrop = ""
    /// The Glimmie who plays the mini-games with her.
    var buddy = 0
    /// Best score per mini-game (StopKind raw value).
    var best: [String: Int] = [:]
}

extension AdventureSave {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AdventureSave()
        stop = c.value(.stop, default: d.stop)
        backdrops = c.lenientArray(.backdrops, default: d.backdrops)
        backdrop = c.value(.backdrop, default: d.backdrop)
        buddy = c.value(.buddy, default: d.buddy)
        best = c.lenientDictionary(.best, default: d.best)
    }
}

// MARK: - Store

/// Reads and writes SaveData without losing anything:
/// - fields missing from an older save get their defaults,
/// - a save from an older version, an unreadable save, and the save before a reset are copied to backup keys,
/// - fields written by a newer build are kept when this build saves.
struct SaveStore {
    static let key = "glimmie.save.v1"
    static let backupKey = key + ".backup"

    let defaults: UserDefaults

    func load() -> SaveData {
        guard let data = defaults.data(forKey: Self.key) else { return SaveData() }
        guard let save = try? JSONDecoder().decode(SaveData.self, from: data) else {
            defaults.set(data, forKey: Self.backupKey + ".unreadable")
            return SaveData()
        }
        if save.version < SaveData.currentVersion {
            defaults.set(data, forKey: Self.backupKey + ".v\(save.version)")
        }
        return save
    }

    func save(_ save: SaveData) {
        guard let data = try? JSONEncoder().encode(save) else { return }
        defaults.set(Self.merge(data, over: defaults.data(forKey: Self.key)), forKey: Self.key)
    }

    /// Starts over, keeping a copy of the old save.
    func reset() {
        if let data = defaults.data(forKey: Self.key) { defaults.set(data, forKey: Self.backupKey + ".before-reset") }
        defaults.removeObject(forKey: Self.key)
    }

    /// `new`, plus any top-level fields of `old` that this build doesn't know (written by a newer build).
    static func merge(_ new: Data, over old: Data?, known: Set<String> = SaveData.fieldNames) -> Data {
        guard let old,
              let oldObject = (try? JSONSerialization.jsonObject(with: old)) as? [String: Any],
              var newObject = (try? JSONSerialization.jsonObject(with: new)) as? [String: Any] else { return new }
        for (k, v) in oldObject where !known.contains(k) && newObject[k] == nil { newObject[k] = v }
        return (try? JSONSerialization.data(withJSONObject: newObject, options: [.sortedKeys])) ?? new
    }
}
