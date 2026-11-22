import Foundation
import simd

struct PonyCameraPose: Equatable {
    var orbit: Float = .pi - 0.31
    var detail: Float = 0
    var zoom: Float = 1

    mutating func turn(points: Float) {
        guard points.isFinite else { return }
        orbit += points * 0.008
        orbit.formTruncatingRemainder(dividingBy: .pi * 2)
    }

    mutating func pinch(factor: Float) {
        guard factor.isFinite, factor > 0 else { return }
        zoom = min(1.55, max(0.72, zoom * factor))
    }
}

struct PonyGroomingSave: Codable, Equatable {
    var locks: [Float]
    var tangled = false
    var dust: [Float]?
    var tack: PonyTack?

    init(count: Int) { locks = Array(repeating: 0.15, count: count) }

    private static let dustyCoat = Array(repeating: Float(1), count: PonyDustSite.all.count)

    var coat: [Float] { dust ?? Self.dustyCoat }
    var outfit: PonyTack { tack ?? PonyTack() }
    var spotsLeft: Int { coat.filter { $0 > 0 }.count }

    func repaired(count: Int) -> Self {
        var save = Self(count: count)
        save.tangled = tangled
        save.tack = tack
        if let dust {
            save.dust = PonyDustSite.all.indices.map { i in
                guard dust.indices.contains(i), dust[i].isFinite else { return 1 }
                return min(1, max(0, dust[i]))
            }
        }
        for i in 0..<min(locks.count, count) where locks[i].isFinite {
            save.locks[i] = min(1, max(0, locks[i]))
        }
        return save
    }

    @discardableResult
    mutating func brush(_ index: Int, distance: Float, downward: Bool) -> Float {
        guard locks.indices.contains(index), distance.isFinite, distance > 0 else { return 0 }
        let before = locks[index]
        let scale: Float = tangled ? 2.15 : 3.7
        locks[index] = min(1, before + min(0.34, distance * scale) * (downward ? 1 : 0.32))
        return locks[index] - before
    }

    @discardableResult
    mutating func brushCoat(at point: SIMD3<Float>, distance: Float) -> Bool {
        guard distance.isFinite, distance > 0 else { return false }
        var values = coat
        var changed = false
        for (i, site) in PonyDustSite.all.enumerated() where values[i] > 0 {
            let reach = site.distance(to: point)
            guard reach < 1 else { continue }
            let remaining = values[i] - min(distance, 0.12) * (1.8 - reach * 1.15)
            values[i] = remaining > 0.035 ? remaining : 0
            changed = true
        }
        if changed { dust = values }
        return changed
    }
}

struct PonyTack: Codable, Equatable {
    enum Saddle: String, Codable, CaseIterable {
        case bareback, mint, lilac

        var label: String {
            switch self {
            case .bareback: "No saddle"
            case .mint: "Mint saddle pad"
            case .lilac: "Lilac saddle pad"
            }
        }
    }

    var halter = false
    var saddle = Saddle.bareback
    var ribbons = false
}

struct PonyDustSite {
    let center: SIMD3<Float>
    let radius: SIMD3<Float>

    func distance(to point: SIMD3<Float>) -> Float {
        simd_length((point - center) / radius)
    }

    // Rest-pose coordinates. Each patch stays on one flank and clears independently.
    static let all: [Self] = [-1 as Float, 1].flatMap { side in
        [
            Self(center: SIMD3<Float>(-1.05, 1.43, side * 0.34), radius: SIMD3<Float>(0.22, 0.19, 0.22)),
            Self(center: SIMD3<Float>(-0.74, 1.62, side * 0.33), radius: SIMD3<Float>(0.23, 0.16, 0.23)),
            Self(center: SIMD3<Float>(-0.55, 1.33, side * 0.38), radius: SIMD3<Float>(0.24, 0.20, 0.23)),
            Self(center: SIMD3<Float>(-0.15, 1.16, side * 0.36), radius: SIMD3<Float>(0.26, 0.19, 0.23)),
            Self(center: SIMD3<Float>(0.15, 1.52, side * 0.36), radius: SIMD3<Float>(0.24, 0.19, 0.23)),
            Self(center: SIMD3<Float>(0.59, 1.15, side * 0.33), radius: SIMD3<Float>(0.22, 0.23, 0.24))
        ]
    }
}

struct PonyLockMotion {
    private(set) var displacement = SIMD3<Float>.zero
    private var velocity = SIMD3<Float>.zero
    private(set) var contact: Float = 0.6
    var settled: Bool { displacement == .zero && velocity == .zero }

    mutating func stroke(_ direction: SIMD3<Float>, at fraction: Float) {
        let length = simd_length(direction)
        guard length.isFinite, length > 0.001 else { return }
        contact = min(1, max(0, fraction))
        velocity += direction / length * min(length * 13, 1.05)
        let speed = simd_length(velocity)
        if speed > 1.9 { velocity *= 1.9 / speed }
    }

    mutating func tick(_ dt: Float) {
        let delta = min(1 / 30, max(0, dt))
        velocity -= displacement * (39 * delta)
        velocity *= exp(-7.8 * delta)
        displacement += velocity * delta
        if simd_length_squared(displacement) + simd_length_squared(velocity) < 0.0000005 {
            displacement = .zero
            velocity = .zero
        }
    }

    func offset(at t: Float) -> SIMD3<Float> {
        let d = t - contact
        let influence = 0.38 + 0.62 * exp(-d * d * 9)
        return displacement * (t * t * influence)
    }
}

struct PonyMeshPart {
    let name: String
    let count: Int
    let vertices: Data
    let triangles: Data
}

enum PonyMesh {
    static let vertexStride = 9 * MemoryLayout<Float>.stride

    static func read(_ data: Data) -> [PonyMeshPart]? {
        guard data.count >= 8, data.prefix(4) == Data("PNY1".utf8) else { return nil }
        func integer(_ offset: Int) -> Int {
            Int(data.withUnsafeBytes { UInt32(littleEndian: $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self)) })
        }
        let partCount = integer(4)
        guard (1...16).contains(partCount) else { return nil }
        var offset = 8
        var parts: [PonyMeshPart] = []
        for _ in 0..<partCount {
            guard offset + 24 <= data.count else { return nil }
            let nameField = data[offset..<(offset + 16)].prefix { $0 != 0 }
            guard let name = String(bytes: nameField, encoding: .ascii), !name.isEmpty else { return nil }
            let vertices = integer(offset + 16), indices = integer(offset + 20)
            guard (1...250_000).contains(vertices), (3...1_500_000).contains(indices), indices.isMultiple(of: 3) else { return nil }
            let start = offset + 24
            let split = start + vertices * vertexStride
            let end = split + indices * MemoryLayout<UInt32>.stride
            guard end <= data.count else { return nil }
            parts.append(PonyMeshPart(name: name, count: vertices, vertices: data.subdata(in: start..<split),
                                      triangles: data.subdata(in: split..<end)))
            offset = end
        }
        guard offset == data.count else { return nil }
        return parts
    }
}
