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
    var isForelock = false

    static let all: [PonyLock] = [-1 as Float, 1].flatMap { side in
        let mane = (0..<16).map { i in
            let u = Float(i) / 15
            let variance = sin(Float(i) * 8.57)
            let x = 0.96 - u * 0.6
            let y = 2.415 - u * 0.55
            let root = SIMD3<Float>(x, y, side * (0.064 + Float(i % 3) * 0.026))
            let length = 1.01 - u * 0.23 + variance * 0.106 + side * 0.028
            let end = SIMD3<Float>(x - 0.24 + variance * 0.08, y - length,
                                    side * (0.342 + u * 0.146 + variance * 0.036))
            let width = 0.077 - u * 0.014 + variance * 0.016
            return PonyLock(root: root, end: end, width: width,
                            curl: variance, side: side, isTail: false)
        }
        let tail = (0..<6).map { i in
            let u = Float(i) / 5
            let root = SIMD3<Float>(-1.20 - u * 0.08, 1.62 - u * 0.10, side * (0.059 + u * 0.079))
            let end = SIMD3<Float>(-1.63 - u * 0.27, 0.049 + u * 0.12, side * (0.07 + u * 0.17))
            return PonyLock(root: root, end: end, width: 0.104 - u * 0.032,
                            curl: sin(u * 8.4), side: side, isTail: true)
        }
        let forelock = (0..<5).map { i in
            let u = Float(i) / 4
            let root = SIMD3<Float>(0.984 + u * 0.057, 2.451 - u * 0.001, side * (0.030 + u * 0.026))
            let end = SIMD3<Float>(1.222 + u * 0.087, 2.333 - u * 0.10 - side * 0.015,
                                    side * (0.112 + u * 0.063))
            return PonyLock(root: root, end: end, width: 0.047 - u * 0.013, curl: u * 1.2,
                            side: side, isTail: false, isForelock: true)
        }
        return mane + tail + forelock
    }

    func point(_ t: Float, groomed: Float, tangled: Bool, motion: PonyLockMotion) -> SIMD3<Float> {
        let a = 1 - t
        let peak = 3 * a * a * t
        let fall = 3 * a * t * t
        let control1 = root + SIMD3<Float>(isForelock ? 0.15 : isTail ? -0.37 : -0.25,
                                           isForelock ? 0.033 : isTail ? 0.034 : -0.06,
                                           side * (isTail ? 0.055 : isForelock ? 0.15 : 0.30))
        let control2 = end + SIMD3<Float>(isForelock ? 0.028 : isTail ? 0.18 : 0.28,
                                          isForelock ? 0.08 : isTail ? 0.24 : 0.29,
                                          side * (isTail ? 0.14 : isForelock ? 0.02 : 0.077))
        var center = root * (a * a * a)
        center += control1 * peak
        center += control2 * fall
        center += end * (t * t * t)
        let wave: Float = (0.029 + (1 - groomed) * 0.052) * (isForelock ? 0.34 : 1)
        let wobble = (sin(t * 10.2 + curl * 2.36) + sin(t * 17 + curl) * 0.23) * wave * t
        center.x += wobble
        center.z += wobble * side * 0.26
        if tangled {
            let snarl = exp(-pow(t - 0.66, 2) * 34) * (1 - groomed)
            center.x += sin(t * 25 + curl * 2) * 0.065 * snarl
            center.z += side * 0.04 * snarl
        }
        center += motion.offset(at: t)
        if !isTail && !isForelock { center.z = side * max(abs(center.z), abs(root.z) + max(0, t - 0.27) * 0.32) }
        return center
    }
}

final class PonyHairMesh {
    let node = SCNNode()
    let lock: PonyLock
    private let origin: SIMD3<Float>
    private let material: SCNMaterial
    private static let segments = 30
    private static let strandSides = [12, 5, 5]
    private static let rowWidth = strandSides.reduce(0) { $0 + $1 + 1 }
    private static let colorTextures = (0..<4).map { variant in
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let size = CGSize(width: 128, height: 96)
        return UIGraphicsImageRenderer(size: size, format: format).image { canvas in
            let tone = Double(variant)
            for y in stride(from: 0, to: 96, by: 4) {
                let t = Double(y) / 96
                for i in 0..<128 {
                    let thread = Double(i) * Double.pi / 64
                    let wave = sin(thread * 8 + sin(t * 4 + tone) * 0.7)
                    let filament = sin(thread * 33 + sin(t * 7) * 0.6)
                    let sheen = sin(thread * 3 - t * 1.2 + tone) * 0.04
                    let shade = 0.97 + wave * 0.11 + filament * 0.065 + sheen
                    let root = 0.88 + 0.12 * min(t * 5, 1)
                    let red = (0.48 + tone * 0.033) * shade * root
                    let green = (0.224 + tone * 0.021) * shade * root
                    let blue = (0.103 + tone * 0.013) * shade * root
                    UIColor(red: red, green: green, blue: blue, alpha: 1).setFill()
                    canvas.fill(CGRect(x: i, y: y, width: 1, height: 4))
                }
            }
        }
    }

    private static let topology: SCNGeometryElement = {
        var faces: [UInt16] = []
        for row in 0..<segments {
            var offset = 0
            for sides in strandSides {
                for side in 0..<sides {
                    let a = UInt16(row * rowWidth + offset + side), b = a + 1
                    let c = a + UInt16(rowWidth), d = c + 1
                    faces += [a, c, b, b, c, d]
                }
                offset += sides + 1
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
        material.diffuse.contents = Self.colorTextures[index % Self.colorTextures.count]
        material.specular.contents = UIColor(red: 0.39, green: 0.27, blue: 0.18, alpha: 1)
        material.shininess = 0.24
        material.isDoubleSided = true
        node.name = "lock-\(index)"
        node.categoryBitMask = 2
    }

    /// The mesh is swept along the live curve. Brushing changes the curve and its surface normals.
    func draw(groomed: Float, tangled: Bool, motion: PonyLockMotion) {
        let segments = Self.segments
        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var texture: [CGPoint] = []
        let count = (segments + 1) * Self.rowWidth
        vertices.reserveCapacity(count)
        normals.reserveCapacity(count)
        texture.reserveCapacity(count)
        let centers = (0...segments).map { lock.point(Float($0) / Float(segments), groomed: groomed, tangled: tangled, motion: motion) }
        for row in 0...segments {
            let t = Float(row) / Float(segments)
            let tangent = simd_normalize(centers[min(segments, row + 1)] - centers[max(0, row - 1)])
            let u = simd_normalize(simd_cross(tangent, SIMD3<Float>(0, 0, 1)))
            let v = simd_normalize(simd_cross(tangent, u))
            let width = lock.width * (0.035 + 0.965 * pow(1 - t, 0.65))
            for (strand, sides) in Self.strandSides.enumerated() {
                let main = strand == 0
                let side: Float = strand == 1 ? -1 : 1
                let wave = sin(t * 15 + lock.curl * 2 + side)
                let spread = width * (0.68 + 0.20 * wave) + t * t * 0.025
                let fringe = main ? SIMD3<Float>.zero : u * (side * spread) + v * (width * 0.18)
                let radius = main ? width : width * (0.13 + 0.046 * wave)
                let depth: Float = main ? 0.38 : 0.65
                for sector in 0...sides {
                    let angle = Float(sector) / Float(sides) * 2 * .pi
                    let twist = angle + sin(t * 5 + lock.curl) * 0.20
                    let pleat = 1 + cos(angle * 3 + t * 2) * 0.082
                    let radial = (u * cos(twist) + v * sin(twist) * depth) * pleat
                    let p = centers[row] - origin + fringe + radial * radius
                    let n = simd_normalize(u * cos(twist) + v * sin(twist) / depth)
                    vertices.append(SCNVector3(p.x, p.y, p.z))
                    normals.append(SCNVector3(n.x, n.y, n.z))
                    texture.append(CGPoint(x: CGFloat(sector) / CGFloat(sides), y: CGFloat(t)))
                }
            }
        }
        let geometry = SCNGeometry(sources: [SCNGeometrySource(vertices: vertices), SCNGeometrySource(normals: normals),
                                             SCNGeometrySource(textureCoordinates: texture)],
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
