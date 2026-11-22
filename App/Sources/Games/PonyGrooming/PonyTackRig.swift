import SceneKit
import UIKit
import simd

@MainActor
final class PonyTackRig {
    private let halter = SCNNode()
    private let saddle = SCNNode()
    private let ribbons = SCNNode()
    private var bows: [SCNNode] = []
    private let pad = SCNMaterial()
    private let binding = SCNMaterial()

    func attach(to body: SCNNode, head: SCNNode, headRest: SIMD3<Float>, tail: SCNNode) {
        halter.name = "pony-halter"
        saddle.name = "pony-saddle"
        ribbons.name = "pony-ribbons"
        head.addChildNode(halter)
        halter.simdPosition = -headRest
        body.addChildNode(saddle)
        tail.addChildNode(ribbons)
        makeHalter()
        makeSaddle()
        makeRibbons()
    }

    func apply(_ outfit: PonyTack) {
        halter.isHidden = !outfit.halter
        saddle.isHidden = outfit.saddle == .bareback
        ribbons.isHidden = !outfit.ribbons
        let lilac = outfit.saddle == .lilac
        pad.diffuse.contents = color(lilac ? 0xAB87C5 : 0x79B59F)
        binding.diffuse.contents = color(lilac ? 0xE0C9EE : 0xCAEDD5)
    }

    var hasRibbons: Bool { !ribbons.isHidden }

    func placeRibbon(_ index: Int, at position: SIMD3<Float>) {
        bows[index].simdPosition = position
    }

    private func makeHalter() {
        let leather = finish(0x5EAA91)
        let stitch = finish(0xC7E2B9)
        let brass = finish(0xCE993D, gloss: 0.75)
        let muzzle = (0...32).map { i -> SIMD3<Float> in
            let t = Float(i) * .pi / 16
            return SIMD3<Float>(1.412 + cos(t) * 0.081, 1.976 + cos(t) * 0.148, sin(t) * 0.18)
        }
        line(muzzle, width: 0.020, material: leather, on: halter)
        for side in [-1 as Float, 1] {
            let cheeks = [SIMD3<Float>(1.401, 1.982, side * 0.183),
                          SIMD3<Float>(1.231, 2.072, side * 0.207),
                          SIMD3<Float>(1.031, 2.145, side * 0.237),
                          SIMD3<Float>(0.884, 2.185, side * 0.225),
                          SIMD3<Float>(0.796, 2.363, side * 0.169),
                          SIMD3<Float>(0.770, 2.433, side * 0.08)]
            line(cheeks, width: 0.018, material: leather, on: halter)
            line(cheeks.map { $0 + SIMD3<Float>(0, 0.008, side * 0.018) },
                 width: 0.0026, material: stitch, on: halter)
            ring(at: cheeks[1], width: 0.027, height: 0.031, material: brass, on: halter)
            ring(at: cheeks[3], width: 0.022, height: 0.028, material: brass, on: halter)
        }
        line([SIMD3<Float>(0.770, 2.433, -0.08), SIMD3<Float>(0.750, 2.451, 0),
              SIMD3<Float>(0.770, 2.433, 0.08)], width: 0.019, material: leather, on: halter)
    }

    private func makeSaddle() {
        let leather = finish(0x794D39, gloss: 0.38)
        let seat = finish(0x5C382C, gloss: 0.42)
        let thread = finish(0xCF9C71)
        let brass = finish(0xD6AA65, gloss: 0.66)
        pad.lightingModel = .blinn
        binding.lightingModel = .lambert

        func drape(_ u: Float, _ v: Float) -> SIMD3<Float> {
            let t = (u - 0.5) * 2.78
            let round = 0.07 * pow(abs(t) / 1.39, 3)
            let x = -0.70 + round + v * (0.99 - 1.7 * round)
            let rise = 0.020 * sin(v * .pi)
            return SIMD3<Float>(x, 1.365 + cos(t) * (0.507 + rise), sin(t) * (0.418 + rise))
        }
        surface(across: 24, along: 20, material: pad, on: saddle, drape)
        for edge: Float in [0, 1] {
            line((0...24).map { drape(Float($0) / 24, edge) }, width: 0.013, material: binding, on: saddle)
            line((0...20).map { drape(edge, Float($0) / 20) }, width: 0.013, material: binding, on: saddle)
        }

        func seatShape(_ u: Float, _ v: Float) -> SIMD3<Float> {
            let across = u * 2 - 1
            let rise = 0.13 * pow(abs(v * 2 - 1), 3) + 0.026 * (1 - across * across)
            let width = 0.145 + 0.073 * sin(v * .pi) - 0.026 * v
            return SIMD3<Float>(-0.60 + 0.70 * v, 1.885 + rise - 0.09 * across * across, across * width)
        }
        surface(across: 16, along: 18, material: seat, on: saddle, seatShape)
        for edge: Float in [0, 1] {
            line((0...16).map { seatShape(Float($0) / 16, edge) }, width: 0.019, material: leather, on: saddle)
            line((0...18).map { seatShape(edge, Float($0) / 18) }, width: 0.014, material: leather, on: saddle)
        }

        for side in [-1 as Float, 1] {
            func flap(_ u: Float, _ v: Float) -> SIMD3<Float> {
                let t = 0.27 + 1.04 * u
                let w = 0.46 - 0.22 * u * u
                return SIMD3<Float>(-0.42 + 0.11 * u + v * w, 1.36 + cos(t) * 0.557,
                                    side * (sin(t) * 0.461 + 0.018))
            }
            surface(across: 14, along: 16, material: leather, on: saddle, flap)
            line((0...16).map { flap(1, Float($0) / 16) }, width: 0.009, material: thread, on: saddle)
            let points = [SIMD3<Float>(-0.04, 1.82, side * 0.254), SIMD3<Float>(-0.09, 1.52, side * 0.474),
                          SIMD3<Float>(-0.12, 1.30, side * 0.494), SIMD3<Float>(-0.135, 1.18, side * 0.49)]
            line(points, width: 0.021, material: seat, on: saddle)
            ring(at: SIMD3<Float>(-0.135, 1.11, side * 0.49), width: 0.071, height: 0.089,
                 material: brass, on: saddle)
        }
        let girth = (0...24).map { i -> SIMD3<Float> in
            let t = Float(i) * .pi / 12
            return SIMD3<Float>(0.07, 1.35 + cos(t) * 0.51, sin(t) * 0.43)
        }
        line(girth, width: 0.028, material: leather, on: saddle)
    }

    private func makeRibbons() {
        let silk = finish(0xB27BCF, gloss: 0.62)
        let seam = finish(0xE3BEE9, gloss: 0.57)
        for side in [-1 as Float, 1] {
            let bow = SCNNode()
            bows.append(bow)
            ribbons.addChildNode(bow)
            let anchor = SIMD3<Float>(0, 0, side * 0.024)
            for direction in [-1 as Float, 1] {
                func loop(_ u: Float, _ v: Float) -> SIMD3<Float> {
                    let t = u * 2 * .pi
                    let flare = (1 - cos(t)) * 0.5
                    return anchor + SIMD3<Float>(direction * flare * 0.14,
                                                  sin(t) * 0.057 + (v - 0.5) * (0.018 + flare * 0.040),
                                                  side * (0.028 + 0.036 * flare + sin(t) * 0.012))
                }
                surface(across: 24, along: 5, material: silk, on: bow, loop)
                line((0...24).map { loop(Float($0) / 24, 1) }, width: 0.003, material: seam, on: bow)
                surface(across: 12, along: 6, material: silk, on: bow) { u, v in
                    anchor + SIMD3<Float>(direction * (0.013 + 0.055 * u) + (v - 0.5) * 0.055,
                                          -0.165 * u + abs(v - 0.5) * 0.029 * u,
                                          side * (0.036 + sin(u * .pi) * 0.029))
                }
            }
            line([anchor + SIMD3<Float>(0, -0.018, side * 0.039),
                  anchor + SIMD3<Float>(0, 0.018, side * 0.039)], width: 0.023, material: seam, on: bow)
        }
    }

    private func ring(at center: SIMD3<Float>, width: Float, height: Float, material: SCNMaterial, on parent: SCNNode) {
        let loop = (0...16).map { i -> SIMD3<Float> in
            let t = Float(i) * .pi / 8
            return center + SIMD3<Float>(width * cos(t), height * sin(t), 0)
        }
        line(loop, width: width * 0.20, material: material, on: parent)
    }

    private func line(_ points: [SIMD3<Float>], width: Float, material: SCNMaterial, on parent: SCNNode) {
        let low = points.reduce(points[0], simd_min)
        let high = points.reduce(points[0], simd_max)
        let span = high - low
        let axis = span.x < min(span.y, span.z) ? SIMD3<Float>(1, 0, 0)
            : span.y < span.z ? SIMD3<Float>(0, 1, 0) : SIMD3<Float>(0, 0, 1)
        let last = points.count - 1
        let closed = simd_distance(points[0], points[last]) < 0.001
        surface(across: 8, along: points.count - 1, material: material, on: parent) { u, v in
            let i = Int((v * Float(last)).rounded())
            let previous = i == 0 && closed ? last - 1 : max(i - 1, 0)
            let next = i == last && closed ? 1 : min(i + 1, last)
            let tangent = simd_normalize(points[next] - points[previous])
            let normal = simd_normalize(simd_cross(tangent, axis))
            let binormal = simd_cross(tangent, normal)
            let theta = 2 * .pi * u
            return points[i] + (cos(theta) * normal + sin(theta) * binormal) * width
        }
    }

    private func surface(across: Int, along: Int, material: SCNMaterial, on parent: SCNNode,
                         _ point: (Float, Float) -> SIMD3<Float>) {
        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var indices: [UInt16] = []
        for j in 0...along {
            for i in 0...across {
                let u = Float(i) / Float(across), v = Float(j) / Float(along)
                let p = point(u, v)
                vertices.append(SCNVector3(p.x, p.y, p.z))
                let du = point(Float(min(i + 1, across)) / Float(across), v)
                    - point(Float(max(i - 1, 0)) / Float(across), v)
                let dv = point(u, Float(min(j + 1, along)) / Float(along))
                    - point(u, Float(max(j - 1, 0)) / Float(along))
                let normal = simd_cross(dv, du)
                let unit = simd_length_squared(normal) > 1e-12 ? simd_normalize(normal) : SIMD3<Float>(0, 1, 0)
                normals.append(SCNVector3(unit.x, unit.y, unit.z))
                if i < across && j < along {
                    let a = UInt16(vertices.count - 1), b = a + 1
                    let c = a + UInt16(across + 1), d = c + 1
                    indices += [a, c, b, b, c, d]
                }
            }
        }
        let faces = SCNGeometryElement(data: indices.withUnsafeBytes { Data($0) }, primitiveType: .triangles,
                                       primitiveCount: indices.count / 3, bytesPerIndex: 2)
        let geometry = SCNGeometry(sources: [SCNGeometrySource(vertices: vertices), SCNGeometrySource(normals: normals)],
                                   elements: [faces])
        material.isDoubleSided = true
        geometry.materials = [material]
        parent.addChildNode(SCNNode(geometry: geometry))
    }

    private func finish(_ hex: UInt32, gloss: CGFloat = 0.20) -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .blinn
        material.diffuse.contents = color(hex)
        material.specular.contents = UIColor(white: gloss, alpha: 1)
        material.shininess = 0.32
        return material
    }

    private func color(_ hex: UInt32) -> UIColor {
        UIColor(red: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255,
                blue: CGFloat(hex & 255) / 255, alpha: 1)
    }
}
