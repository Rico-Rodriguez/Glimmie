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
    private let tack = PonyTackRig()
    private var dust: [SCNNode] = []
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
    private static let ribbonLocks = [-1 as Float, 1].compactMap { side in
        PonyLock.all.lastIndex { $0.isTail && $0.side == side }
    }

    static func savedGrooming() -> PonyGroomingSave {
        let count = PonyLock.all.count
        return GameStorage.load(PonyGroomingSave.self, game: folder, file: saveFile)?.repaired(count: count)
            ?? PonyGroomingSave(count: count)
    }

    init?(grooming: PonyGroomingSave? = nil) {
        motion = Array(repeating: PonyLockMotion(), count: PonyLock.all.count)
        save = grooming ?? Self.savedGrooming()
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
        dust = PonyCoat.patches(on: coat)
        for patch in dust { skeleton.addChildNode(patch) }
        showCoat()
        let feet = SCNNode(geometry: geometry(hooves))
        skeleton.addChildNode(feet)
        let ornament = SCNNode(geometry: geometry(horn))
        ornament.simdPosition = -Self.headRest
        head.addChildNode(ornament)
        addFace()
        tack.attach(to: skeleton, head: head, headRest: Self.headRest, tail: tail)
        tack.apply(save.outfit)
        for (i, lock) in PonyLock.all.enumerated() {
            let origin = lock.isTail ? Self.tailRest : lock.isForelock ? Self.headRest : Self.neckRest
            let mesh = PonyHairMesh(lock: lock, index: i, origin: origin)
            locks.append(mesh)
            let joint = lock.isTail ? tail : lock.isForelock ? head : neck
            joint.addChildNode(mesh.node)
            redraw(i)
        }
        placeRibbons()
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
        if value { save.locks = save.locks.map { min($0, 0.26) } }
        for i in locks.indices { redraw(i) }
        dirty = true
        flush()
    }

    var spotsLeft: Int { save.spotsLeft }

    func setTack(_ value: PonyTack) {
        guard save.outfit != value else { return }
        save.tack = value
        tack.apply(value)
        placeRibbons()
        dirty = true
        flush()
    }

    func dustCoat() {
        save.dust = nil
        showCoat()
        dirty = true
        flush()
    }

    func turn(_ dx: CGFloat) { requestedCamera.turn(points: Float(dx)) }
    func zoom(_ amount: CGFloat) { requestedCamera.pinch(factor: Float(amount)) }
    func detail(_ detail: Bool) { requestedCamera.detail = detail ? 1 : 0 }

    func canBrush(_ hit: SCNHitTestResult?) -> Bool {
        guard let name = hit?.node.name else { return false }
        return name == "pony-body" || name.hasPrefix("lock-")
    }

    func brush(hit: SCNHitTestResult, delta: SIMD3<Float>) {
        let distance = min(0.14, simd_length(delta))
        guard let name = hit.node.name else { return }
        if name == "pony-body" {
            let local = hit.localCoordinates
            if save.brushCoat(at: SIMD3<Float>(local.x, local.y, local.z), distance: distance) {
                showCoat()
                dirty = true
            }
            response = min(1, response + distance * 1.25)
            return
        }
        guard name.hasPrefix("lock-"), let index = Int(name.dropFirst(5)) else { return }
        guard locks.indices.contains(index) else { return }
        let mesh = locks[index]
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

    private func showCoat() {
        for (patch, amount) in zip(dust, save.coat) {
            patch.opacity = CGFloat(amount)
            patch.isHidden = amount == 0
        }
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
        placeRibbons()
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
        let center = SIMD3<Float>(detail * 0.54, 1.32 + detail * 0.56, 0)
        let offset = SIMD3<Float>(sin(angle) * radius, radius * 0.13, cos(angle) * radius)
        // SceneKit cameras face local -Z. Rebuild the basis from world up on every frame,
        // so the last frame's orientation cannot introduce roll as the camera orbits.
        let back = simd_normalize(offset)
        let right = simd_normalize(simd_cross(SIMD3<Float>(0, 1, 0), back))
        let up = simd_cross(back, right)
        camera.simdTransform = simd_float4x4(columns: (
            SIMD4<Float>(right, 0), SIMD4<Float>(up, 0), SIMD4<Float>(back, 0), SIMD4<Float>(center + offset, 1)
        ))
    }

    private func redraw(_ i: Int) {
        locks[i].draw(groomed: save.locks[i], tangled: save.tangled, motion: motion[i])
    }

    private func placeRibbons() {
        guard tack.hasRibbons else { return }
        for (side, i) in Self.ribbonLocks.enumerated() {
            let anchor = locks[i].lock.point(0.24, groomed: save.locks[i], tangled: save.tangled, motion: motion[i])
            tack.placeRibbon(side, at: anchor - Self.tailRest)
        }
    }

    private func geometry(_ part: PonyMeshPart) -> SCNGeometry {
        let features: [SCNGeometrySource.Semantic] = [.vertex, .normal]
        var sources = features.enumerated().map { i, key in
            SCNGeometrySource(data: part.vertices, semantic: key, vectorCount: part.count, usesFloatComponents: true,
                              componentsPerVector: 3, bytesPerComponent: 4, dataOffset: i * 12, dataStride: PonyMesh.vertexStride)
        }
        let colors: [SIMD4<Float>] = part.vertices.withUnsafeBytes { bytes in
            (0..<part.count).map { i in
                let offset = i * PonyMesh.vertexStride + 24
                return SIMD4<Float>(bytes.loadUnaligned(fromByteOffset: offset, as: Float.self),
                                    bytes.loadUnaligned(fromByteOffset: offset + 4, as: Float.self),
                                    bytes.loadUnaligned(fromByteOffset: offset + 8, as: Float.self), 1)
            }
        }
        sources.append(SCNGeometrySource(data: colors.withUnsafeBytes { Data($0) }, semantic: .color,
                                         vectorCount: part.count, usesFloatComponents: true, componentsPerVector: 4,
                                         bytesPerComponent: 4, dataOffset: 0, dataStride: 16))
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
            blink.simdPosition = SIMD3<Float>(1.052, 2.226, side * 0.232) - Self.headRest
            blink.eulerAngles.y = side * 0.13
            blink.eulerAngles.z = -0.16
            eyes.append(blink)
            oval(at: .zero, scale: SIMD3<Float>(0.080, 0.052, 0.037), color: rgb(0x765345), parent: blink)
            let iris = oval(at: SIMD3<Float>(0.007, -0.001, side * 0.022),
                            scale: SIMD3<Float>(0.059, 0.041, 0.024), color: rgb(0x492619), parent: blink)
            iris.geometry?.firstMaterial?.lightingModel = .blinn
            iris.geometry?.firstMaterial?.specular.contents = rgb(0xAA8A6F)
            oval(at: SIMD3<Float>(0.010, 0.001, side * 0.035),
                 scale: SIMD3<Float>(0.046, 0.027, 0.015), color: rgb(0x231519), parent: blink)
            oval(at: SIMD3<Float>(0.018, 0.013, side * 0.047),
                 scale: SIMD3<Float>(0.013, 0.009, 0.004), color: rgb(0xFFF2DA), parent: blink)
            let nostril = oval(at: SIMD3<Float>(1.584, 1.893, side * 0.121) - Self.headRest,
                               scale: SIMD3<Float>(0.030, 0.014, 0.009), color: rgb(0x59413A), parent: head)
            nostril.eulerAngles.z = -0.37
            nostril.eulerAngles.y = side * 0.66
        }
    }

    @discardableResult private func oval(at p: SIMD3<Float>, scale: SIMD3<Float>, color: UIColor, parent: SCNNode,
                                        segments: Int = 24) -> SCNNode {
        let g = SCNSphere(radius: 1)
        g.segmentCount = segments
        g.materials = [material(color)]
        let node = SCNNode(geometry: g)
        node.simdPosition = p
        node.simdScale = scale
        parent.addChildNode(node)
        return node
    }

    private func buildRoom() {
        scene.background.contents = rgb(0xE9CEE7)
        let wood = texture("stable-wood")
        let garden = texture("stable-garden")
        let floor = SCNPlane(width: 40, height: 40)
        let sand = material(rgb(0xE4C1A0))
        if let image = texture("stable-floor") {
            sand.diffuse.contents = image
            sand.diffuse.wrapS = .repeat
            sand.diffuse.wrapT = .repeat
            sand.diffuse.mipFilter = .linear
            sand.diffuse.maxAnisotropy = 8
            sand.diffuse.contentsTransform = SCNMatrix4MakeScale(15, 15, 1)
        }
        floor.materials = [sand]
        let ground = SCNNode(geometry: floor)
        ground.eulerAngles.x = -.pi / 2
        ground.categoryBitMask = 4
        ground.castsShadow = false
        scene.rootNode.addChildNode(ground)

        for side in 0..<12 {
            let theta = Float(side) / 12 * 2 * .pi
            let group = SCNNode()
            group.simdPosition = SIMD3<Float>(sin(theta) * 8.5, 0, cos(theta) * 8.5)
            group.eulerAngles.y = theta
            scene.rootNode.addChildNode(group)
            let wall = board(width: 4.60, height: 5.2, depth: 0.12, position: SIMD3<Float>(0, 2.6, 0),
                             color: rgb(0xD5B6D9), parent: group)
            if let wood, let surface = wall.geometry?.firstMaterial {
                surface.diffuse.contents = wood
                surface.diffuse.mipFilter = .linear
            }
            board(width: 0.23, height: 5.2, depth: 0.21, position: SIMD3<Float>(-2.26, 2.6, -0.11),
                  color: rgb(0xB38BAD), parent: group)
            board(width: 4.61, height: 0.18, depth: 0.21, position: SIMD3<Float>(0, 0.13, -0.10),
                  color: rgb(0xBA92B2), parent: group)
            board(width: 4.61, height: 0.12, depth: 0.21, position: SIMD3<Float>(0, 1.22, -0.10),
                  color: rgb(0xA4BFA6), parent: group)
            switch side {
            case 0, 6, 10:
                window(parent: group, garden: garden)
                planter(at: SIMD3<Float>(-1.48, 0, -0.75), parent: group)
            case 1, 2, 7:
                gate(parent: group)
                lantern(x: -1.72, parent: group)
            case 5, 8, 11:
                chest(parent: group)
                planter(at: SIMD3<Float>(1.48, 0, -0.6), parent: group)
            default:
                lantern(x: 0, parent: group)
            }
        }
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 430
        ambient.color = rgb(0xF4E4E6)
        let soft = SCNNode()
        soft.light = ambient
        scene.rootNode.addChildNode(soft)
        let sunlight = SCNLight()
        sunlight.type = .directional
        sunlight.intensity = 850
        sunlight.color = rgb(0xFFF0D6)
        sunlight.castsShadow = true
        sunlight.shadowRadius = 4
        sunlight.shadowSampleCount = 12
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

    private func window(parent: SCNNode, garden: UIImage?) {
        func arch(_ width: CGFloat, _ height: CGFloat, z: Float, finish: SCNMaterial) {
            let w = width / 2
            let cap = height - w * 0.72
            var points = [CGPoint(x: 0, y: height / 2), CGPoint(x: -w, y: 0), CGPoint(x: w, y: 0)]
            for i in 0...24 {
                let a = CGFloat(i) * .pi / 24
                points.append(CGPoint(x: cos(a) * w, y: cap + sin(a) * (height - cap)))
            }
            let vertices = points.map { SCNVector3(Float($0.x), Float($0.y), 0) }
            let uv = points.map { CGPoint(x: $0.x / width + 0.5, y: 1 - $0.y / height) }
            let edge = UInt16(points.count - 1)
            var faces = (1..<edge).flatMap { [UInt16.zero, $0, $0 + 1] }
            faces += [0, edge, 1]
            let element = SCNGeometryElement(data: faces.withUnsafeBytes { Data($0) }, primitiveType: .triangles,
                                             primitiveCount: faces.count / 3, bytesPerIndex: 2)
            let shape = SCNGeometry(sources: [SCNGeometrySource(vertices: vertices),
                                              SCNGeometrySource(textureCoordinates: uv)], elements: [element])
            finish.isDoubleSided = true
            shape.materials = [finish]
            let node = SCNNode(geometry: shape)
            node.position = SCNVector3(0, 1.58, z)
            node.categoryBitMask = 4
            node.castsShadow = false
            parent.addChildNode(node)
        }
        let frame = material(rgb(0xFFE1BD))
        let view = material(rgb(0xDCE9CA))
        frame.lightingModel = .constant
        view.lightingModel = .constant
        if let garden { view.diffuse.contents = garden }
        arch(3.73, 2.86, z: -0.14, finish: frame)
        arch(3.41, 2.67, z: -0.20, finish: view)
        board(width: 3.81, height: 0.16, depth: 0.36, position: SIMD3<Float>(0, 1.56, -0.25),
              color: rgb(0xC7A184), parent: parent)
        board(width: 0.082, height: 2.66, depth: 0.10, position: SIMD3<Float>(0, 2.9, -0.27),
              color: rgb(0xFFE6C7), parent: parent)
        board(width: 3.48, height: 0.087, depth: 0.10, position: SIMD3<Float>(0, 2.65, -0.27),
              color: rgb(0xFFE6C7), parent: parent)
    }

    private func chest(parent: SCNNode) {
        let green = rgb(0x92AE94), brass = rgb(0xD8A86A)
        board(width: 1.8, height: 0.83, depth: 0.77,
              position: SIMD3<Float>(0, 0.45, -0.62), color: green, parent: parent)
        board(width: 1.90, height: 0.20, depth: 0.85, position: SIMD3<Float>(0, 0.9, -0.62),
              color: rgb(0xB3C7A8), parent: parent)
        for x: Float in [-0.68, 0.68] {
            board(width: 0.090, height: 0.92, depth: 0.065, position: SIMD3<Float>(x, 0.52, -1.04),
                  color: brass, parent: parent)
        }
        board(width: 0.20, height: 0.18, depth: 0.10, position: SIMD3<Float>(0, 0.80, -1.07),
              color: brass, parent: parent)
    }

    private func planter(at position: SIMD3<Float>, parent: SCNNode) {
        let group = SCNNode()
        group.simdPosition = position
        parent.addChildNode(group)
        let pot = SCNCone(topRadius: 0.32, bottomRadius: 0.24, height: 0.46)
        pot.materials = [material(rgb(0xBC875D))]
        let base = SCNNode(geometry: pot)
        base.categoryBitMask = 4
        base.position.y = 0.23
        group.addChildNode(base)
        let lip = SCNTorus(ringRadius: 0.31, pipeRadius: 0.027)
        lip.materials = [material(rgb(0xDBAD79))]
        let rim = SCNNode(geometry: lip)
        rim.categoryBitMask = 4
        rim.position.y = 0.46
        group.addChildNode(rim)
        for i in 0..<17 {
            let f = Float(i)
            let angle = f * 2.399
            let reach = 0.10 + 0.17 * Float(i % 5) / 4
            let x = cos(angle) * reach, z = sin(angle) * reach
            let height = 0.58 + 0.37 * Float((i * 5) % 13) / 12
            let leaf = oval(at: SIMD3<Float>(x, 0.53 + height * 0.13, z),
                            scale: SIMD3<Float>(0.039, 0.19, 0.022), color: rgb(0x789A66), parent: group, segments: 9)
            leaf.eulerAngles.z = x * 2.4
            leaf.eulerAngles.y = angle
            leaf.categoryBitMask = 4
            leaf.castsShadow = false
            let blossom = oval(at: SIMD3<Float>(x, height, z), scale: SIMD3<Float>(0.055, 0.12, 0.048),
                               color: rgb(i % 2 == 0 ? 0xB585CA : 0xCE9CCF), parent: group, segments: 9)
            blossom.eulerAngles.z = x * 1.62
            blossom.categoryBitMask = 4
            blossom.castsShadow = false
        }
    }

    private func lantern(x: Float, parent: SCNNode) {
        board(width: 0.27, height: 0.39, depth: 0.24, position: SIMD3<Float>(x, 2.57, -0.30),
              color: rgb(0x7E5B62), parent: parent)
        let pane = board(width: 0.21, height: 0.32, depth: 0.08, position: SIMD3<Float>(x, 2.57, -0.43),
                         color: rgb(0xFFE7BD), parent: parent)
        pane.geometry?.firstMaterial?.lightingModel = .constant
        board(width: 0.39, height: 0.085, depth: 0.35, position: SIMD3<Float>(x, 2.81, -0.33),
              color: rgb(0x926C66), parent: parent)
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

    @discardableResult private func board(width: CGFloat, height: CGFloat, depth: CGFloat, position: SIMD3<Float>,
                                         color: UIColor, parent: SCNNode) -> SCNNode {
        let g = SCNBox(width: width, height: height, length: depth, chamferRadius: min(0.025, width / 3))
        g.materials = [material(color)]
        let node = SCNNode(geometry: g)
        node.categoryBitMask = 4
        node.castsShadow = false
        node.simdPosition = position
        parent.addChildNode(node)
        return node
    }

    private func material(_ color: UIColor) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .lambert
        m.diffuse.contents = color
        return m
    }

    private func texture(_ name: String) -> UIImage? {
        GameFiles.url(name, "jpg", game: "PonyGrooming").flatMap { UIImage(contentsOfFile: $0.path) }
    }

    private func rgb(_ hex: UInt32) -> UIColor {
        UIColor(red: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255,
                blue: CGFloat(hex & 255) / 255, alpha: 1)
    }
}
