import SceneKit
import XCTest
import simd
@testable import Glimmie

final class PonyGroomingTests: XCTestCase {
    func testCoatBrushClearsOneFlankAndKeepsOlderHairSaves() throws {
        let oldSave = Data(#"{"locks":[0.81,0.42],"tangled":true}"#.utf8)
        var groom = try JSONDecoder().decode(PonyGroomingSave.self, from: oldSave).repaired(count: PonyLock.all.count)
        let site = PonyDustSite.all[0]
        let count = PonyDustSite.all.count
        XCTAssertEqual(groom.spotsLeft, count)
        XCTAssertEqual(groom.outfit, PonyTack())
        XCTAssertFalse(groom.brushCoat(at: SIMD3<Float>(0, 0, 0), distance: 0.1))
        for _ in 0..<8 { XCTAssertTrue(groom.brushCoat(at: site.center, distance: 0.075)) }
        XCTAssertEqual(groom.spotsLeft, count - 1)
        XCTAssertEqual(groom.coat[0], 0)
        XCTAssertEqual(groom.coat[count / 2], 1)
        XCTAssertEqual(groom.locks[0], 0.81)
        XCTAssertTrue(groom.tangled)
        groom.tack = PonyTack(halter: true, saddle: .lilac, ribbons: true)
        let reopened = try JSONDecoder().decode(PonyGroomingSave.self, from: JSONEncoder().encode(groom))
        XCTAssertEqual(reopened, groom)
    }

    func testDustPatchesFollowCoatAndTackAttachesToCorrectJoints() async throws {
        try await MainActor.run {
            let pony = try XCTUnwrap(PonyScene())
            let root = pony.scene.rootNode
            let saddle = try XCTUnwrap(root.childNode(withName: "pony-saddle", recursively: true))
            XCTAssertTrue(saddle.parent === pony.neck.parent)
            XCTAssertTrue(pony.head.childNode(withName: "pony-halter", recursively: false)?.isHidden == true)
            XCTAssertNotNil(pony.tail.childNode(withName: "pony-ribbons", recursively: false))
            for i in PonyDustSite.all.indices {
                let patch = try XCTUnwrap(root.childNode(withName: "coat-dust-\(i)", recursively: true))
                XCTAssertTrue(patch.parent === saddle.parent)
                XCTAssertGreaterThan(try XCTUnwrap(patch.geometry?.elements.first).primitiveCount, 0)
                XCTAssertEqual(patch.categoryBitMask, 4)
            }
        }
    }

    func testOrbitStaysUprightThroughFullTurnsInBothViews() async throws {
        try await MainActor.run {
            let pony = try XCTUnwrap(PonyScene())
            var previous = pony.camera.simdTransform.columns.1
            for i in 0..<320 {
                if i == 160 { pony.detail(true); pony.zoom(1.25) }
                pony.turn(i < 160 ? 10 : -10)
                pony.frame(time: Double(i) / 30, dt: 1 / 30, reducedMotion: false)
                let transform = pony.camera.simdTransform
                XCTAssertEqual(transform.columns.0.y, 0, accuracy: 0.00001)
                XCTAssertGreaterThan(transform.columns.1.y, 0.98)
                XCTAssertGreaterThan(simd_dot(previous, transform.columns.1), 0.99)
                previous = transform.columns.1
            }
        }
    }

    func testSceneUsesSkinnedGeometryAndTurnsAroundTheSameMane() async throws {
        try await MainActor.run {
            let pony = try XCTUnwrap(PonyScene())
            let root = pony.scene.rootNode
            let body = try XCTUnwrap(root.childNode(withName: "pony-body", recursively: true))
            let mane = try XCTUnwrap(root.childNode(withName: "lock-0", recursively: true))
            let hairMesh = try XCTUnwrap(mane.geometry)
            XCTAssertEqual(body.skinner?.bones.count, 3)
            XCTAssertEqual(mane.parent, pony.neck)
            let start = pony.camera.position
            pony.turn(340)
            pony.detail(true)
            for frame in 0..<36 { pony.frame(time: 2 + Double(frame) / 30, dt: 1 / 30, reducedMotion: false) }
            XCTAssertGreaterThan(abs(pony.camera.position.x - start.x) + abs(pony.camera.position.z - start.z), 1)
            XCTAssertTrue(mane.geometry === hairMesh)
            XCTAssertNotEqual(pony.head.eulerAngles.z, 0)
        }
    }

    func testStandingPonyMeshBundlesClosedTriangleData() throws {
        let url = try XCTUnwrap(GameFiles.url("pony", "mesh", game: "PonyGrooming"))
        let bytes = try Data(contentsOf: url)
        let parts = try XCTUnwrap(PonyMesh.read(bytes))
        XCTAssertEqual(parts.map(\.name), ["coat", "hooves", "horn"])
        for part in parts {
            XCTAssertEqual(part.vertices.count, part.count * PonyMesh.vertexStride)
            XCTAssertGreaterThan(part.triangles.count, 0)
            XCTAssertEqual(part.triangles.count % 12, 0)
            let indices = part.triangles.withUnsafeBytes { Array($0.bindMemory(to: UInt32.self)) }
            XCTAssertLessThan(try XCTUnwrap(indices.max()), UInt32(part.count))
        }
        XCTAssertNil(PonyMesh.read(bytes.dropLast()))
    }

    func testGroomedLocksPersistAcrossCameraChangesAndSaveReload() throws {
        var groom = PonyGroomingSave(count: PonyLock.all.count)
        let original = groom.locks
        XCTAssertGreaterThan(groom.brush(2, distance: 0.1, downward: true), 0)
        XCTAssertEqual(groom.locks[3], original[3])
        XCTAssertEqual(groom.locks.last, original.last)
        var camera = PonyCameraPose()
        let initially = camera.orbit
        camera.turn(points: 390)
        camera.detail = 1
        camera.pinch(factor: 10)
        XCTAssertNotEqual(camera.orbit, initially)
        XCTAssertEqual(camera.zoom, 1.55)
        let encoded = try JSONEncoder().encode(groom)
        let restored = try JSONDecoder().decode(PonyGroomingSave.self, from: encoded)
        XCTAssertEqual(restored.locks, groom.locks)
    }

    func testBrushMovesFreeHairWhileAnchoringAndSettlingTheRoot() {
        var lock = PonyLockMotion()
        lock.stroke(SIMD3<Float>(0.04, -0.09, 0), at: 0.8)
        lock.tick(1 / 30)
        XCTAssertEqual(lock.offset(at: 0), .zero)
        XCTAssertNotEqual(lock.offset(at: 0.8), .zero)
        for _ in 0..<160 { lock.tick(1 / 30) }
        XCTAssertTrue(lock.settled)
    }

    func testOptionalTanglesRespondMoreToDownwardBrushing() {
        var upward = PonyGroomingSave(count: 1)
        upward.tangled = true
        var downward = upward
        let up = upward.brush(0, distance: 0.09, downward: false)
        let down = downward.brush(0, distance: 0.09, downward: true)
        XCTAssertGreaterThan(down, up)
        XCTAssertEqual(downward.brush(-1, distance: 0.5, downward: true), 0)
        XCTAssertEqual(downward.brush(0, distance: .nan, downward: true), 0)
    }
}
