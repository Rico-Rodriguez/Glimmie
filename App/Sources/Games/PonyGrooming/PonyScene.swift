import SceneKit
import UIKit
import simd

@MainActor
final class PonyScene {
    static let folder = "UnicornStable"
    static let saveFile = "pony-mane.json"

    let scene = SCNScene()
    let camera = SCNNode()
    let neck = SCNNode()
    let head = SCNNode()
    let tail = SCNNode()
    private let skeleton = SCNNode()
    private let tack = SCNNode()
    private var eyes: [SCNNode] = []
    private var locks: [PonyHairMesh] = []
    private var motion: [PonyLockMotion]
    private var changed = Set<Int>()
    private var requestedCamera = PonyCameraPose()
    private var renderedCamera = PonyCameraPose()
    private var response: Float = 0
    private var save: PonyGroomingSave
    private var dirty = false

    private static let neckRest = SIMD3<Float>(0.57, 1.63, 0)
    private static let headRest = SIMD3<Float>(0.86, 2.18, 0)
    private static let tailRest = SIMD3<Float>(-1.15, 1.56, 0)

    static func savedMane() -> PonyGroomingSave {
        let count = PonyLock.all.count
        return GameStorage.load(PonyGroomingSave.self, game: folder, file: saveFile)?.repaired(count: count)
            ?? PonyGroomingSave(count: count)
    }

    init?() {
        motion = Array(repeating: PonyLockMotion(), count: PonyLock.all.count)
        save = Self.savedMane()
        guard let url = GameFiles.url("pony", "mesh", game: "PonyGrooming"),
              let bytes = try? Data(contentsOf: url), let parts = PonyMesh.read(bytes),
              let coat = parts.first(where: { $0.name == "coat" }),
              let hooves = parts.first(where: { $0.name == "hooves" }),
              let horn = parts.first(where: { $0.name == "horn" }) else { return nil }
        buildRoom()
        scene.rootNode.addChildNode(skeleton)
        skeleton.addChildNode(neck)
        neck.simdPosition = Self.neckRest
        neck.addChildNode(head)
        head.simdPosition = Self.headRest - Self.neckRest
        skeleton.addChildNode(tail)
        tail.simdPosition = Self.tailRest
        addCoat(coat)
        let feet = SCNNode(geometry: geometry(hooves))
        skeleton.addChildNode(feet)
        let ornament = SCNNode(geometry: geometry(horn))
        ornament.simdPosition = -Self.headRest
        head.addChildNode(ornament)
        addFace()
        addTack()
        for (i, lock) in PonyLock.all.enumerated() {
            let origin = lock.isTail ? Self.tailRest : lock.isForelock ? Self.headRest : Self.neckRest
            let mesh = PonyHairMesh(lock: lock, index: i, origin: origin)
            locks.append(mesh)
            let joint = lock.isTail ? tail : lock.isForelock ? head : neck
            joint.addChildNode(mesh.node)
            redraw(i)
        }
        camera.camera = SCNCamera()
        camera.camera?.fieldOfView = 38
        camera.camera?.zNear = 0.08
        camera.camera?.zFar = 45
        scene.rootNode.addChildNode(camera)
        updateCamera()
    }

    func setTangled(_ value: Bool) {
        guard save.tangled != value else { return }
        save.tangled = value
        for i in locks.indices { redraw(i) }
        dirty = true
        flush()
    }

    func setTack(_ value: Bool) { tack.isHidden = !value }

    func turn(_ dx: CGFloat) { requestedCamera.turn(points: Float(dx)) }
    func zoom(_ amount: CGFloat) { requestedCamera.pinch(factor: Float(amount)) }
    func detail(_ detail: Bool) { requestedCamera.detail = detail ? 1 : 0 }

    func brush(hit: SCNHitTestResult, index: Int, delta: SIMD3<Float>) {
        guard locks.indices.contains(index) else { return }
        let mesh = locks[index]
        let distance = min(0.14, simd_length(delta))
        let localDelta = mesh.node.simdConvertVector(delta, from: nil)
        let fraction = mesh.fraction(at: hit.localCoordinates, groomed: save.locks[index],
                                     tangled: save.tangled, motion: motion[index])
        let progress = save.brush(index, distance: distance, downward: localDelta.y < -0.003)
        dirty = dirty || progress > 0
        motion[index].stroke(localDelta, at: fraction)
        changed.insert(index)
        // The brush catches the neighboring edges of a lock, without affecting the hidden side.
        let neighbors = [index - 1, index + 1].filter {
            locks.indices.contains($0) && locks[$0].lock.side == mesh.lock.side && locks[$0].lock.isTail == mesh.lock.isTail
                && locks[$0].lock.isForelock == mesh.lock.isForelock
        }
        for neighbor in neighbors {
            motion[neighbor].stroke(localDelta * 0.36, at: fraction)
            changed.insert(neighbor)
        }
        response = min(1, response + distance * 1.25)
    }

    func flush() {
        guard dirty else { return }
        GameStorage.save(save, game: Self.folder, file: Self.saveFile)
        dirty = false
    }

    func frame(time: Double, dt: Float, reducedMotion: Bool) {
        let sample = Float(time.truncatingRemainder(dividingBy: 760))
        response *= exp(-3.1 * dt)
        let quiet: Float = reducedMotion ? 0 : 1
        neck.eulerAngles.z = (sin(sample * 1.8) * 0.014 - response * 0.042) * quiet
        head.eulerAngles.y = (sin(sample * 0.8) * 0.061 + response * 0.11) * quiet
        head.eulerAngles.z = (sin(sample * 1.3) * 0.023 - response * 0.083) * quiet
        tail.eulerAngles.y = sin(sample * 1.65) * 0.10 * quiet
        skeleton.simdScale = SIMD3<Float>(1, 1 + sin(sample * 2.0) * 0.004 * quiet, 1)
        let blink = sample.truncatingRemainder(dividingBy: 4.4)
        let eyelid: Float = blink < 0.14 ? max(0.12, abs(blink - 0.07) / 0.07) : 1
        for eye in eyes { eye.simdScale.y = eyelid }
        if !changed.isEmpty {
            var settled: [Int] = []
            for i in changed {
                motion[i].tick(dt)
                redraw(i)
                if motion[i].settled { settled.append(i) }
            }
            changed.subtract(settled)
        }
        let smoothing = min(1, dt * (reducedMotion ? 17 : 8))
        let raw = requestedCamera.orbit - renderedCamera.orbit
        let wrapped = atan2(sin(raw), cos(raw))
        renderedCamera.orbit += wrapped * smoothing
        renderedCamera.detail += (requestedCamera.detail - renderedCamera.detail) * smoothing
        renderedCamera.zoom += (requestedCamera.zoom - renderedCamera.zoom) * smoothing
        updateCamera()
    }

    private func updateCamera() {
        let detail = renderedCamera.detail
        let angle = renderedCamera.orbit
        let radius = (5.4 - detail * 2.51) / renderedCamera.zoom
        let center = SCNVector3(detail * 0.54, 1.32 + detail * 0.56, 0)
        camera.position = SCNVector3(center.x + sin(angle) * radius, center.y + radius * 0.13, cos(angle) * radius)
        camera.look(at: center)
    }

    private func redraw(_ i: Int) {
        locks[i].draw(groomed: save.locks[i], tangled: save.tangled, motion: motion[i])
    }

    private func geometry(_ part: PonyMeshPart) -> SCNGeometry {
        let features: [SCNGeometrySource.Semantic] = [.vertex, .normal, .color]
        let sources = features.enumerated().map { i, key in
            SCNGeometrySource(data: part.vertices, semantic: key, vectorCount: part.count, usesFloatComponents: true,
                              componentsPerVector: 3, bytesPerComponent: 4, dataOffset: i * 12, dataStride: PonyMesh.vertexStride)
        }
        let faces = SCNGeometryElement(data: part.triangles, primitiveType: .triangles,
                                       primitiveCount: part.triangles.count / 12, bytesPerIndex: 4)
        let mesh = SCNGeometry(sources: sources, elements: [faces])
        mesh.materials = [material(.white)]
        return mesh
    }

    private func addCoat(_ part: PonyMeshPart) {
        let mesh = geometry(part)
        let node = SCNNode(geometry: mesh)
        node.name = "pony-body"
        var weights: [Float] = []
        var ids: [UInt8] = []
        func smooth(_ value: Float) -> Float {
            let t = max(0, min(1, value))
            return t * t * (3 - 2 * t)
        }
        part.vertices.withUnsafeBytes { bytes in
            for i in 0..<part.count {
                let offset = i * PonyMesh.vertexStride
                let x = bytes.loadUnaligned(fromByteOffset: offset, as: Float.self)
                let y = bytes.loadUnaligned(fromByteOffset: offset + 4, as: Float.self)
                let neckWeight = smooth((y - 1.48) / 0.42) * smooth((x - 0.23) / 0.39)
                let headWeight = max(smooth((y - 1.99) / 0.33), smooth((x - 0.9) / 0.32)) * neckWeight
                weights += [1 - neckWeight, neckWeight - headWeight, headWeight, 0]
                ids += [0, 1, 2, 0]
            }
        }
        let weightSource = SCNGeometrySource(data: weights.withUnsafeBytes { Data($0) }, semantic: .boneWeights,
                                            vectorCount: part.count, usesFloatComponents: true, componentsPerVector: 4,
                                            bytesPerComponent: 4, dataOffset: 0, dataStride: 16)
        let indexSource = SCNGeometrySource(data: Data(ids), semantic: .boneIndices, vectorCount: part.count,
                                           usesFloatComponents: false, componentsPerVector: 4,
                                           bytesPerComponent: 1, dataOffset: 0, dataStride: 4)
        let inverse = [SIMD3<Float>.zero, -Self.neckRest, -Self.headRest].map {
            NSValue(scnMatrix4: SCNMatrix4MakeTranslation($0.x, $0.y, $0.z))
        }
        let skin = SCNSkinner(baseGeometry: mesh, bones: [skeleton, neck, head], boneInverseBindTransforms: inverse,
                              boneWeights: weightSource, boneIndices: indexSource)
        skin.skeleton = skeleton
        node.skinner = skin
        scene.rootNode.addChildNode(node)
    }

    private func addFace() {
        for side in [-1 as Float, 1] {
            let blink = SCNNode()
            head.addChildNode(blink)
            blink.simdPosition = SIMD3<Float>(1.036, 2.226, side * 0.232) - Self.headRest
            blink.eulerAngles.y = side * 0.22
            eyes.append(blink)
            oval(at: .zero, scale: SIMD3<Float>(0.080, 0.054, 0.037), color: rgb(0x705046), parent: blink)
            oval(at: SIMD3<Float>(0.010, -0.002, side * 0.022), scale: SIMD3<Float>(0.065, 0.046, 0.039), color: rgb(0x281815), parent: blink)
            oval(at: SIMD3<Float>(0.030, 0.017, side * 0.051), scale: SIMD3<Float>(0.017, 0.014, 0.010), color: rgb(0xFDF2DF), parent: blink)
            let nostril = oval(at: SIMD3<Float>(1.565, 1.934, side * 0.142) - Self.headRest,
                               scale: SIMD3<Float>(0.033, 0.019, 0.017), color: rgb(0x64453D), parent: head)
            nostril.eulerAngles.z = -0.30
            nostril.eulerAngles.y = side * 0.45
        }
    }

    private func addTack() {
        // A first fitted accessory for checking transform attachment during grooming and orbit.
        head.addChildNode(tack)
        tack.simdPosition = -Self.headRest
        let mint = rgb(0x74B5A0)
        let brass = rgb(0xD8A14D)
        var loop: [SIMD3<Float>] = []
        for i in 0...26 {
            let t = Float(i) / 26 * 2 * .pi
            loop.append(SIMD3<Float>(1.405 + cos(t) * 0.088, 1.972 + cos(t) * 0.15, sin(t) * 0.175))
        }
        straps(loop, width: 0.012, color: mint, parent: tack)
        for side in [-1 as Float, 1] {
            let points = [SIMD3<Float>(1.40,1.974,side * 0.178), SIMD3<Float>(1.205,2.028,side * 0.206),
                          SIMD3<Float>(0.973,2.155,side * 0.236), SIMD3<Float>(0.822,2.339,side * 0.197)]
            straps(points, width: 0.013, color: mint, parent: tack)
            let clip = oval(at: points[2], scale: SIMD3<Float>(0.022, 0.025, 0.013), color: brass, parent: tack)
            clip.eulerAngles.z = -0.34
        }
        tack.isHidden = true
    }

    private func straps(_ points: [SIMD3<Float>], width: CGFloat, color: UIColor, parent: SCNNode) {
        for (a, b) in zip(points, points.dropFirst()) {
            let d = b - a
            let g = SCNCapsule(capRadius: width, height: CGFloat(simd_length(d)) + width)
            g.radialSegmentCount = 8
            g.materials = [material(color)]
            let node = SCNNode(geometry: g)
            node.simdPosition = (a + b) * 0.5
            node.simdOrientation = simd_quatf(from: SIMD3<Float>(0,1,0), to: simd_normalize(d))
            parent.addChildNode(node)
        }
    }

    @discardableResult private func oval(at p: SIMD3<Float>, scale: SIMD3<Float>, color: UIColor, parent: SCNNode) -> SCNNode {
        let g = SCNSphere(radius: 1)
        g.segmentCount = 24
        g.materials = [material(color)]
        let node = SCNNode(geometry: g)
        node.simdPosition = p
        node.simdScale = scale
        parent.addChildNode(node)
        return node
    }

    private func buildRoom() {
        scene.background.contents = rgb(0xE0C7E7)
        let floor = SCNFloor()
        floor.reflectivity = 0
        floor.materials = [material(rgb(0xE4C1A0))]
        let ground = SCNNode(geometry: floor)
        ground.categoryBitMask = 4
        scene.rootNode.addChildNode(ground)

        for side in 0..<16 {
            let theta = Float(side) / 16 * 2 * .pi
            let group = SCNNode()
            group.simdPosition = SIMD3<Float>(sin(theta) * 8.5, 0, cos(theta) * 8.5)
            group.eulerAngles.y = theta
            scene.rootNode.addChildNode(group)
            board(width: 3.45, height: 4.8, depth: 0.12, position: SIMD3<Float>(0, 2.4, 0), color: rgb(0xD5B6D9), parent: group)
            board(width: 0.14, height: 4.8, depth: 0.18, position: SIMD3<Float>(-1.62, 2.4, -0.11), color: rgb(0xB991C3), parent: group)
            board(width: 3.48, height: 0.11, depth: 0.21, position: SIMD3<Float>(0, 1.33, -0.10), color: rgb(0xA2C6AD), parent: group)
            for index in 0..<5 {
                board(width: 0.021, height: 3.35, depth: 0.17, position: SIMD3<Float>(-1.14 + Float(index) * 0.57, 1.68, -0.05),
                      color: rgb(0xC4A3CD), parent: group)
            }
            if side % 4 == 0 { window(parent: group) }
            if side % 4 == 1 { gate(parent: group) }
        }
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 580
        ambient.color = rgb(0xF5DDF3)
        let soft = SCNNode()
        soft.light = ambient
        scene.rootNode.addChildNode(soft)
        let sunlight = SCNLight()
        sunlight.type = .directional
        sunlight.intensity = 820
        sunlight.color = rgb(0xFFF0D6)
        sunlight.castsShadow = true
        sunlight.shadowRadius = 4
        sunlight.shadowSampleCount = 8
        sunlight.shadowColor = UIColor.black.withAlphaComponent(0.24)
        let key = SCNNode()
        key.light = sunlight
        key.position = SCNVector3(3, 7, 5)
        key.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(key)
        let fill = SCNLight()
        fill.type = .directional
        fill.intensity = 330
        fill.color = rgb(0xFFF5E6)
        let back = SCNNode()
        back.light = fill
        back.position = SCNVector3(-3, 4, -5)
        back.look(at: SCNVector3(0, 1, 0))
        scene.rootNode.addChildNode(back)
    }

    private func window(parent: SCNNode) {
        func arch(_ width: CGFloat, _ height: CGFloat, z: Float, color: UIColor) {
            let w = width / 2
            let cap = height - w * 0.72
            let path = UIBezierPath()
            path.move(to: CGPoint(x: -w, y: 0))
            path.addLine(to: CGPoint(x: w, y: 0))
            path.addLine(to: CGPoint(x: w, y: cap))
            path.addQuadCurve(to: CGPoint(x: 0, y: height), controlPoint: CGPoint(x: w, y: height))
            path.addQuadCurve(to: CGPoint(x: -w, y: cap), controlPoint: CGPoint(x: -w, y: height))
            path.close()
            let shape = SCNShape(path: path, extrusionDepth: 0.04)
            let m = material(color)
            m.lightingModel = .constant
            shape.materials = [m]
            let node = SCNNode(geometry: shape)
            node.position = SCNVector3(0, 1.65, z)
            node.categoryBitMask = 4
            node.castsShadow = false
            parent.addChildNode(node)
        }
        arch(2.64, 2.18, z: -0.14, color: rgb(0xFFF0DB))
        arch(2.40, 2.0, z: -0.20, color: rgb(0xCCE9ED))
        for (x, y, width) in [(-0.72 as Float, 1.83 as Float, 0.43 as Float), (0.40, 1.92, 0.62), (0.86,1.77,0.30)] {
            let leaf = oval(at: SIMD3<Float>(x, y, -0.23), scale: SIMD3<Float>(width, 0.24, 0.015), color: rgb(0xA9CEA1), parent: parent)
            leaf.categoryBitMask = 4
            leaf.castsShadow = false
        }
        board(width: 2.69, height: 0.12, depth: 0.22, position: SIMD3<Float>(0, 1.65, -0.22), color: rgb(0xCAB297), parent: parent)
        board(width: 0.075, height: 1.97, depth: 0.10, position: SIMD3<Float>(0, 2.63, -0.24), color: rgb(0xFFF0DB), parent: parent)
    }

    private func gate(parent: SCNNode) {
        board(width: 2.58, height: 1.77, depth: 0.19, position: SIMD3<Float>(0, 0.92, -0.19), color: rgb(0xA9CEB2), parent: parent)
        for index in 0..<6 {
            board(width: 0.023, height: 1.72, depth: 0.21, position: SIMD3<Float>(-1.06 + Float(index) * 0.41, 0.91, -0.20),
                  color: rgb(0x83B097), parent: parent)
        }
        let plaster = SCNBox(width: 2.75, height: 0.12, length: 0.08, chamferRadius: 0.025)
        plaster.materials = [material(rgb(0xC6DDC4))]
        let brace = SCNNode(geometry: plaster)
        brace.position = SCNVector3(0, 0.92, -0.31)
        brace.eulerAngles.z = 0.53
        brace.categoryBitMask = 4
        brace.castsShadow = false
        parent.addChildNode(brace)
    }

    private func board(width: CGFloat, height: CGFloat, depth: CGFloat, position: SIMD3<Float>,
                       color: UIColor, parent: SCNNode) {
        let g = SCNBox(width: width, height: height, length: depth, chamferRadius: min(0.025, width / 3))
        g.materials = [material(color)]
        let node = SCNNode(geometry: g)
        node.categoryBitMask = 4
        node.castsShadow = false
        node.simdPosition = position
        parent.addChildNode(node)
    }

    private func material(_ color: UIColor) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .lambert
        m.diffuse.contents = color
        return m
    }

    private func rgb(_ hex: UInt32) -> UIColor {
        UIColor(red: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255,
                blue: CGFloat(hex & 255) / 255, alpha: 1)
    }
}
