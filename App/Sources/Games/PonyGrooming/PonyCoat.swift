import SceneKit
import UIKit
import simd

@MainActor
enum PonyCoat {
    static func patches(on part: PonyMeshPart) -> [SCNNode] {
        let positions = vectors(in: part, offset: 0)
        let normals = vectors(in: part, offset: 12)
        let faces = part.triangles.withUnsafeBytes { Array($0.bindMemory(to: UInt32.self)) }
        return PonyDustSite.all.enumerated().map { index, site in
            var lookup: [Int: UInt32] = [:]
            var vertices: [SCNVector3] = []
            var uv: [CGPoint] = []
            var triangles: [UInt32] = []
            let nearby = positions.map { site.distance(to: $0) < 1.2 }
            for face in stride(from: 0, to: faces.count, by: 3) {
                let corners = faces[face..<(face + 3)]
                guard corners.allSatisfy({ nearby[Int($0)] }) else { continue }
                for corner in corners {
                    let i = Int(corner)
                    if let known = lookup[i] {
                        triangles.append(known)
                        continue
                    }
                    let new = UInt32(vertices.count)
                    lookup[i] = new
                    triangles.append(new)
                    let lifted = positions[i] + normals[i] * 0.003
                    let projected = (positions[i] - site.center) / site.radius
                    vertices.append(SCNVector3(lifted.x, lifted.y, lifted.z))
                    uv.append(CGPoint(x: CGFloat(0.5 + projected.x * 0.5), y: CGFloat(0.5 - projected.y * 0.5)))
                }
            }
            let element = SCNGeometryElement(data: triangles.withUnsafeBytes { Data($0) }, primitiveType: .triangles,
                                             primitiveCount: triangles.count / 3, bytesPerIndex: 4)
            let geometry = SCNGeometry(sources: [SCNGeometrySource(vertices: vertices),
                                                 SCNGeometrySource(textureCoordinates: uv)], elements: [element])
            let material = SCNMaterial()
            material.lightingModel = .constant
            material.diffuse.contents = textures[index % textures.count]
            material.diffuse.wrapS = .clamp
            material.diffuse.wrapT = .clamp
            material.writesToDepthBuffer = false
            geometry.materials = [material]
            let patch = SCNNode(geometry: geometry)
            patch.name = "coat-dust-\(index)"
            patch.categoryBitMask = 4
            patch.castsShadow = false
            patch.renderingOrder = 2
            return patch
        }
    }

    static func vectors(in part: PonyMeshPart, offset: Int) -> [SIMD3<Float>] {
        part.vertices.withUnsafeBytes { bytes in
            (0..<part.count).map { i in
                let start = i * PonyMesh.vertexStride + offset
                return SIMD3<Float>(bytes.loadUnaligned(fromByteOffset: start, as: Float.self),
                                    bytes.loadUnaligned(fromByteOffset: start + 4, as: Float.self),
                                    bytes.loadUnaligned(fromByteOffset: start + 8, as: Float.self))
            }
        }
    }

    private static let textures: [UIImage] = (0..<4).map { variant in
        let size = CGSize(width: 128, height: 128)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { canvas in
            let context = canvas.cgContext
            let color = UIColor(red: 0.38, green: 0.26, blue: 0.18, alpha: 1)
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: [color.withAlphaComponent(0.47).cgColor,
                                               color.withAlphaComponent(0).cgColor] as CFArray,
                                      locations: [0, 1])!
            for i in 0..<17 {
                let theta = Double(i) * 2.399 + Double(variant)
                let reach = Double(i % 7) * 5.0
                let center = CGPoint(x: 64 + cos(theta) * reach, y: 64 + sin(theta) * reach * 0.71)
                let radius = CGFloat(13 + (i * 17 + variant * 7) % 16)
                context.drawRadialGradient(gradient, startCenter: center, startRadius: 0,
                                           endCenter: center, endRadius: radius, options: [])
            }
            for i in 0..<130 {
                let theta = Double(i) * 2.399 + Double(variant)
                let reach = Double((i * 11) % 49)
                let x = 64 + cos(theta) * reach, y = 64 + sin(theta) * reach * 0.77
                context.setFillColor(color.withAlphaComponent(0.18).cgColor)
                context.fillEllipse(in: CGRect(x: x, y: y, width: 1.3, height: 1.1))
            }
        }
    }
}

@MainActor
struct PonyCoatSurface {
    // Check each cell's bounds before testing its triangles. A brush stroke can
    // sample several points per frame, so it should only visit cells in its path.
    private struct Cell: Hashable {
        let x: Int
        let y: Int
        let z: Int

        init(_ point: SIMD3<Float>) {
            x = Int(floor(point.x / 0.35))
            y = Int(floor(point.y / 0.35))
            z = Int(floor(point.z / 0.35))
        }
    }

    private struct Face {
        let origin: SIMD3<Float>
        let edgeA: SIMD3<Float>
        let edgeB: SIMD3<Float>

        func distance(from start: SIMD3<Float>, along ray: SIMD3<Float>) -> Float? {
            let across = simd_cross(ray, edgeB)
            let determinant = simd_dot(edgeA, across)
            guard determinant > 1e-9 else { return nil }
            let relative = start - origin
            let inverse = 1 / determinant
            let u = simd_dot(relative, across) * inverse
            guard (0...1).contains(u) else { return nil }
            let normal = simd_cross(relative, edgeA)
            let v = simd_dot(ray, normal) * inverse
            guard v >= 0, u + v <= 1 else { return nil }
            let t = simd_dot(edgeB, normal) * inverse
            return t >= 0 ? t : nil
        }
    }

    private struct Bucket {
        var low = SIMD3<Float>(repeating: .infinity)
        var high = SIMD3<Float>(repeating: -.infinity)
        var faces: [Face] = []

        mutating func add(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>) {
            low = simd_min(low, simd_min(a, simd_min(b, c)))
            high = simd_max(high, simd_max(a, simd_max(b, c)))
            faces.append(Face(origin: a, edgeA: b - a, edgeB: c - a))
        }

        func intersects(from start: SIMD3<Float>, along ray: SIMD3<Float>, limit: Float) -> Bool {
            var near: Float = 0
            var far = limit
            for axis in 0..<3 {
                if abs(ray[axis]) < 1e-7 {
                    guard start[axis] >= low[axis], start[axis] <= high[axis] else { return false }
                } else {
                    let a = (low[axis] - start[axis]) / ray[axis]
                    let b = (high[axis] - start[axis]) / ray[axis]
                    near = max(near, min(a, b))
                    far = min(far, max(a, b))
                    guard far >= near else { return false }
                }
            }
            return true
        }
    }

    private let buckets: [Bucket]

    init(_ part: PonyMeshPart) {
        let points = PonyCoat.vectors(in: part, offset: 0)
        var cells: [Cell: Bucket] = [:]
        part.triangles.withUnsafeBytes { bytes in
            let indices = bytes.bindMemory(to: UInt32.self)
            for i in stride(from: 0, to: indices.count, by: 3) {
                let a = points[Int(indices[i])]
                let b = points[Int(indices[i + 1])]
                let c = points[Int(indices[i + 2])]
                let cell = Cell((a + b + c) / 3)
                cells[cell, default: Bucket()].add(a, b, c)
            }
        }
        buckets = Array(cells.values)
    }

    func hit(from start: SIMD3<Float>, to end: SIMD3<Float>) -> SIMD3<Float>? {
        let ray = end - start
        var nearest: Float = 1
        for bucket in buckets where bucket.intersects(from: start, along: ray, limit: nearest) {
            for face in bucket.faces {
                if let distance = face.distance(from: start, along: ray), distance < nearest {
                    nearest = distance
                }
            }
        }
        return nearest < 1 ? start + ray * nearest : nil
    }
}
