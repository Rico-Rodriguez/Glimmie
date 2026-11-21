import SceneKit
import UIKit
import simd

struct PonyLock {
    let root: SIMD3<Float>
    let end: SIMD3<Float>
    let width: Float
    let curl: Float
    let side: Float
    let isTail: Bool

    static let all: [PonyLock] = [-1 as Float, 1].flatMap { side in
        let mane = (0..<16).map { i in
            let u = Float(i) / 15
            let variance = sin(Float(i) * 8.57)
            let x = 0.96 - u * 0.6
            let y = 2.43 - u * 0.58
            let root = SIMD3<Float>(x, y, side * (0.074 + Float(i % 3) * 0.024))
            let length = 0.77 - u * 0.30 + variance * 0.07
            let end = SIMD3<Float>(x - 0.27 + variance * 0.07, y - length,
                                    side * (0.34 + u * 0.17 + variance * 0.025))
            return PonyLock(root: root, end: end, width: 0.063 - u * 0.016,
                            curl: variance, side: side, isTail: false)
        }
        let tail = (0..<6).map { i in
            let u = Float(i) / 5
            let root = SIMD3<Float>(-1.17 - u * 0.07, 1.57 - u * 0.12, side * (0.06 + u * 0.08))
            let end = SIMD3<Float>(-1.66 - u * 0.18, 0.20 + u * 0.17, side * (0.085 + u * 0.11))
            return PonyLock(root: root, end: end, width: 0.071 - u * 0.022,
                            curl: sin(u * 8.4), side: side, isTail: true)
        }
        return mane + tail
    }

    func point(_ t: Float, groomed: Float, tangled: Bool, motion: PonyLockMotion) -> SIMD3<Float> {
        let a = 1 - t
        let peak = 3 * a * a * t
        let fall = 3 * a * t * t
        let control1 = root + SIMD3<Float>(-0.23, -0.06, side * (isTail ? 0.03 : 0.31))
        let control2 = end + SIMD3<Float>(0.17, 0.21, side * (isTail ? 0.17 : 0.085))
        var center = root * (a * a * a)
        center += control1 * peak
        center += control2 * fall
        center += end * (t * t * t)
        let wave: Float = (1 - groomed) * 0.08 + 0.016
        let wobble = sin(t * 11.5 + curl * 2.8) * wave * t
        center.x += wobble
        center.z += wobble * side * 0.26
        if tangled {
            let snarl = exp(-pow(t - 0.66, 2) * 34) * (1 - groomed)
            center.x += sin(t * 25 + curl * 2) * 0.065 * snarl
            center.z += side * 0.04 * snarl
        }
        center += motion.offset(at: t)
        if !isTail { center.z = side * max(abs(center.z), abs(root.z) + max(0, t - 0.27) * 0.32) }
        return center
    }
}

final class PonyHairMesh {
    let node = SCNNode()
    let lock: PonyLock
    private let origin: SIMD3<Float>
    private let material: SCNMaterial
    private static let segments = 26
    private static let sides = 9

    private static let topology: SCNGeometryElement = {
        var faces: [UInt16] = []
        for row in 0..<segments {
            for side in 0..<sides {
                let next = (side + 1) % sides
                let a = UInt16(row * sides + side), b = UInt16(row * sides + next)
                let c = UInt16((row + 1) * sides + side), d = UInt16((row + 1) * sides + next)
                faces += [a, c, b, b, c, d]
            }
        }
        return SCNGeometryElement(data: faces.withUnsafeBytes { Data($0) }, primitiveType: .triangles,
                                  primitiveCount: faces.count / 3, bytesPerIndex: MemoryLayout<UInt16>.stride)
    }()

    init(lock: PonyLock, index: Int, origin: SIMD3<Float>) {
        self.lock = lock
        self.origin = origin
        material = SCNMaterial()
        material.lightingModel = .blinn
        material.diffuse.contents = UIColor(red: 0.62 + CGFloat(index % 3) * 0.055,
                                           green: 0.30 + CGFloat(index % 4) * 0.022,
                                           blue: 0.16 + CGFloat(index % 4) * 0.019, alpha: 1)
        material.specular.contents = UIColor(red: 0.46, green: 0.29, blue: 0.19, alpha: 1)
        material.shininess = 0.35
        material.isDoubleSided = true
        node.name = "lock-\(index)"
        node.categoryBitMask = 2
    }

    /// The mesh is swept along the live curve. Brushing changes the curve and its surface normals.
    func draw(groomed: Float, tangled: Bool, motion: PonyLockMotion) {
        let segments = Self.segments, sides = Self.sides
        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        let centers = (0...segments).map { lock.point(Float($0) / Float(segments), groomed: groomed, tangled: tangled, motion: motion) }
        for row in 0...segments {
            let t = Float(row) / Float(segments)
            let tangent = simd_normalize(centers[min(segments, row + 1)] - centers[max(0, row - 1)])
            let u = simd_normalize(simd_cross(tangent, SIMD3<Float>(0, 0, 1)))
            let v = simd_normalize(simd_cross(tangent, u))
            let width = lock.width * (0.16 + 0.84 * pow(1 - t, 0.48))
            for sector in 0..<sides {
                let angle = Float(sector) / Float(sides) * 2 * .pi
                let radial = u * cos(angle) + v * sin(angle) * 0.46
                let p = centers[row] - origin + radial * width
                let n = simd_normalize(u * cos(angle) + v * sin(angle) / 0.46)
                vertices.append(SCNVector3(p.x, p.y, p.z))
                normals.append(SCNVector3(n.x, n.y, n.z))
            }
        }
        let geometry = SCNGeometry(sources: [SCNGeometrySource(vertices: vertices), SCNGeometrySource(normals: normals)],
                                   elements: [Self.topology])
        geometry.materials = [material]
        node.geometry = geometry
    }

    func fraction(at local: SCNVector3, groomed: Float, tangled: Bool, motion: PonyLockMotion) -> Float {
        let p = origin + SIMD3<Float>(local.x, local.y, local.z)
        return (0...Self.segments).min { a, b in
            let t1 = Float(a) / Float(Self.segments), t2 = Float(b) / Float(Self.segments)
            let d1 = simd_length_squared(lock.point(t1, groomed: groomed, tangled: tangled, motion: motion) - p)
            let d2 = simd_length_squared(lock.point(t2, groomed: groomed, tangled: tangled, motion: motion) - p)
            return d1 < d2
        }.map { Float($0) / Float(Self.segments) } ?? 0.5
    }
}
