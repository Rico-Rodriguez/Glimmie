import Foundation
import simd

struct PonyCameraPose: Equatable {
    var orbit: Float = 0.34
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

    init(count: Int) { locks = Array(repeating: 0.15, count: count) }

    func repaired(count: Int) -> Self {
        var save = Self(count: count)
        save.tangled = tangled
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
