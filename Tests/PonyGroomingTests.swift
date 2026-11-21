import XCTest
@testable import Glimmie

final class PonyGroomingTests: XCTestCase {
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
