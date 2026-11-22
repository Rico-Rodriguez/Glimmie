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
            let length = 0.92 - u * 0.22 + variance * 0.085 + side * 0.025
            let end = SIMD3<Float>(x - 0.24 + variance * 0.08, y - length,
                                    side * (0.342 + u * 0.146 + variance * 0.036))
            let width = 0.077 - u * 0.014 + variance * 0.016
            return PonyLock(root: root, end: end, width: width,
                            curl: variance, side: side, isTail: false)
        }
        let tail = (0..<6).map { i in
            let u = Float(i) / 5
            let root = SIMD3<Float>(-1.20 - u * 0.08, 1.62 - u * 0.10, side * (0.059 + u * 0.079))
            let end = SIMD3<Float>(-1.70 - u * 0.22, 0.085 + u * 0.155, side * (0.07 + u * 0.17))
            return PonyLock(root: root, end: end, width: 0.104 - u * 0.032,
                            curl: sin(u * 8.4), side: side, isTail: true)
        }
        let forelock = (0..<5).map { i in
            let u = Float(i) / 4
            let root = SIMD3<Float>(0.971 + u * 0.06, 2.426 + u * 0.01, side * (0.026 + u * 0.025))
            let end = SIMD3<Float>(1.158 + u * 0.145, 2.306 - u * 0.081 - side * 0.014,
                                    side * (0.106 + u * 0.049))
            return PonyLock(root: root, end: end, width: 0.047 - u * 0.013, curl: u * 1.2,
                            side: side, isTail: false, isForelock: true)
        }
        return mane + tail + forelock
    }

    func point(_ t: Float, groomed: Float, tangled: Bool, motion: PonyLockMotion) -> SIMD3<Float> {
        let a = 1 - t
        let peak = 3 * a * a * t
        let fall = 3 * a * t * t
        let control1 = root + SIMD3<Float>(isForelock ? 0.11 : -0.23, isForelock ? 0.022 : -0.06,
                                           side * (isTail ? 0.055 : isForelock ? 0.15 : 0.30))
        let control2 = end + SIMD3<Float>(isForelock ? -0.06 : isTail ? 0.11 : 0.20,
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
    private static let sides = 12
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
            for side in 0..<sides {
                let count = sides + 1
                let a = UInt16(row * count + side), b = a + 1
                let c = UInt16((row + 1) * count + side), d = c + 1
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
        material.diffuse.contents = Self.colorTextures[index % Self.colorTextures.count]
        material.specular.contents = UIColor(red: 0.39, green: 0.27, blue: 0.18, alpha: 1)
        material.shininess = 0.24
        material.isDoubleSided = true
        node.name = "lock-\(index)"
        node.categoryBitMask = 2
    }

    /// The mesh is swept along the live curve. Brushing changes the curve and its surface normals.
    func draw(groomed: Float, tangled: Bool, motion: PonyLockMotion) {
        let segments = Self.segments, sides = Self.sides
        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var texture: [CGPoint] = []
        let centers = (0...segments).map { lock.point(Float($0) / Float(segments), groomed: groomed, tangled: tangled, motion: motion) }
        for row in 0...segments {
            let t = Float(row) / Float(segments)
            let tangent = simd_normalize(centers[min(segments, row + 1)] - centers[max(0, row - 1)])
            let u = simd_normalize(simd_cross(tangent, SIMD3<Float>(0, 0, 1)))
            let v = simd_normalize(simd_cross(tangent, u))
            let width = lock.width * (0.035 + 0.965 * pow(1 - t, 0.65))
            for sector in 0...sides {
                let angle = Float(sector) / Float(sides) * 2 * .pi
                let twist = angle + sin(t * 5 + lock.curl) * 0.20
                let pleat = 1 + cos(angle * 3 + t * 2) * 0.082
                let radial = (u * cos(twist) + v * sin(twist) * 0.38) * pleat
                let p = centers[row] - origin + radial * width
                let n = simd_normalize(u * cos(twist) + v * sin(twist) / 0.38)
                vertices.append(SCNVector3(p.x, p.y, p.z))
                normals.append(SCNVector3(n.x, n.y, n.z))
                texture.append(CGPoint(x: CGFloat(sector) / CGFloat(sides), y: CGFloat(t)))
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
