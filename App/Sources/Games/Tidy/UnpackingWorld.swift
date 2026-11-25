import SwiftUI
import UIKit

// MARK: - Unpacking Room State & Interaction Engine

final class UnpackingBoxState: Identifiable {
    let spec: UnpackingBoxSpec
    var id: String { spec.id }
    var isOpened: Bool = false
    /// 0 = taped shut, 1 = flaps wide open.
    var openProgress: CGFloat = 0
    /// 0 = tape intact, 1 = tape peeled away.
    var tapePeel: CGFloat = 0
    var remaining: [UnpackingItemSpec]
    var kick: CGFloat = 0
    var isCollapsing: Bool = false
    /// 0 = full size, 1 = vanished.
    var collapseProgress: CGFloat = 0
    var isGone: Bool = false

    init(spec: UnpackingBoxSpec) {
        self.spec = spec
        self.remaining = spec.items
    }
}

enum UnpackingItemPhase: Equatable {
    case emerging
    case staged
    case held
    case settling
    case bouncingBack
    case placed
}

final class UnpackingItemState: Identifiable {
    let id: String
    let kind: UnpackingItemKind
    let color: Int
    let size: CGSize

    var phase: UnpackingItemPhase = .staged
    var pos: CGPoint = .zero
    var homeStagedPos: CGPoint = .zero
    var emergeStart: CGPoint = .zero
    var emergeElapsed: Double = 0
    var targetPos: CGPoint = .zero
    var surfaceID: String?
    var bounceStart: CGPoint = .zero
    var bounceTarget: CGPoint = .zero
    var bounceElapsed: Double = 0
    var bounceReturnsToPlaced: Bool = false

    var lift: CGFloat = 0
    var tilt: CGFloat = 0
    var squash: CGFloat = 0
    var squashVel: CGFloat = 0
    var z: Int = 0
    var isLit: Bool = false
    var interactTimer: Double = 0

    init(spec: UnpackingItemSpec) {
        self.id = spec.id
        self.kind = spec.kind
        self.color = spec.color
        self.size = spec.kind.size
    }

    func contains(_ p: CGPoint) -> Bool {
        let halfW = max(36, size.width * 0.5 + 16)
        let halfH = max(36, size.height * 0.5 + 16)
        return abs(p.x - pos.x) <= halfW && abs(p.y - pos.y) <= halfH
    }
}

struct UnpackingEffectParticle {
    enum Kind { case sparkle, puff, confetti, heart, steam }
    var kind: Kind
    var pos: TVec
    var vel: TVec
    var born: Double
    var life: Double
    var size: CGFloat
    var color: TRGB
    var rot: CGFloat
    var spin: CGFloat
}

final class UnpackingWorld: ObservableObject {
    static let completionRewardCoins = 5
    static let stageSize = CGSize(width: GameChromeLayout.width, height: GameChromeLayout.height)
    private static let fixedStep: Double = 1.0 / 120.0

    let room: UnpackingRoomSpec
    weak var store: UnpackingStore?

    @Published private(set) var complete: Bool = false
    @Published private(set) var shouldShowDoneButtons: Bool = false
    @Published private(set) var placedCount: Int = 0

    private(set) var isDone: Bool = false
    private(set) var boxes: [UnpackingBoxState] = []
    private(set) var items: [UnpackingItemState] = []
    private(set) var particles: [UnpackingEffectParticle] = []
    private(set) var rings: [TidyRing] = []

    private(set) var time: Double = 0
    private(set) var heldID: String?
    private(set) var hoverSurfaceID: String?
    private(set) var hoverPreviewPos: CGPoint?
    private(set) var hintSurfaceID: String?
    private(set) var hintAt: Double = -10
    private(set) var lastPlace: Double = -10
    private(set) var lastBounceAt: Double = -10
    private(set) var roomGlow: Double = 0

    private var lastDate: Date?
    private var zCounter: Int = 1
    private var combo: Int = 0
    private var didReward: Bool = false
    private var musicNoteIndex: Int = 0
    private var celebrateAt: Double?

    // Active gesture tracking
    private var finger: CGPoint = .zero
    private var grabOffset: CGPoint = .zero
    private var touchDownPos: CGPoint = .zero
    private var touchDownTime: Double = 0
    private var draggedFromBoxID: String?
    private var wasPlacedBeforeGrab: Bool = false
    private var previousPlacedPos: CGPoint = .zero
    private var previousSurfaceID: String?
    private var heldVel: TVec = .zero

    var totalItemCount: Int { room.allItems.count }

    var remainingInBoxesCount: Int {
        boxes.reduce(0) { $0 + $1.remaining.count }
    }

    var allBoxesEmpty: Bool {
        boxes.allSatisfy { $0.remaining.isEmpty }
    }

    init(roomID: UnpackingRoomID, store: UnpackingStore? = nil) {
        self.room = UnpackingRooms.spec(for: roomID)
        self.store = store
        self.boxes = room.boxes.map { UnpackingBoxState(spec: $0) }
        if let saved = store?.roomSave(for: roomID) {
            restore(from: saved)
        }
    }

    // MARK: - Save & Restore

    func makeRoomSave() -> SavedUnpackingRoom {
        let placedItems = items
            .filter { $0.phase == .placed || ($0.phase == .settling && $0.surfaceID != nil) }
            .sorted { $0.z < $1.z }
            .compactMap { item -> SavedUnpackingItem? in
                guard let sid = item.surfaceID else { return nil }
                let pos = item.phase == .settling ? item.targetPos : item.pos
                return SavedUnpackingItem(
                    itemID: item.id,
                    kind: item.kind,
                    color: item.color,
                    surfaceID: sid,
                    x: pos.x,
                    y: pos.y,
                    z: item.z,
                    isLit: item.isLit
                )
            }
        let opened = boxes.filter { $0.isOpened }.map(\.id)
        return SavedUnpackingRoom(completed: isDone, placed: placedItems, openedBoxes: opened)
    }

    private func persistProgress() {
        store?.update(room: room.id, save: makeRoomSave(), persist: true)
    }

    private func restore(from saved: SavedUnpackingRoom) {
        let placedByID = Dictionary(uniqueKeysWithValues: saved.placed.map { ($0.itemID, $0) })
        let openedSet = Set(saved.openedBoxes)

        items.removeAll()
        var maxZ = 1

        for box in boxes {
            var stillInside: [UnpackingItemSpec] = []
            for spec in box.spec.items {
                if let savedItem = placedByID[spec.id], let surface = room.surface(id: savedItem.surfaceID) {
                    let state = UnpackingItemState(spec: spec)
                    state.phase = .placed
                    state.surfaceID = surface.id
                    state.pos = resolvedPoint(for: state, on: surface, near: CGPoint(x: savedItem.x, y: savedItem.y))
                    state.targetPos = state.pos
                    state.homeStagedPos = stagedPoint(for: box, size: state.size, slotIndex: 0)
                    state.z = savedItem.z
                    state.isLit = savedItem.isLit
                    maxZ = max(maxZ, savedItem.z)
                    items.append(state)
                } else {
                    stillInside.append(spec)
                }
            }
            box.remaining = stillInside
            if stillInside.isEmpty {
                box.isOpened = true
                box.tapePeel = 1
                box.openProgress = 0
                box.isCollapsing = true
                box.collapseProgress = 1
                box.isGone = true
            } else if openedSet.contains(box.id) {
                box.isOpened = true
                box.tapePeel = 1
                box.openProgress = 1
            }
        }

        zCounter = maxZ + 1
        placedCount = items.filter { $0.phase == .placed }.count

        if saved.completed && allBoxesEmpty && placedCount == totalItemCount {
            isDone = true
            complete = true
            didReward = true
            shouldShowDoneButtons = false
            roomGlow = 1
            for item in items where item.kind.isLighting {
                item.isLit = true
            }
        }
    }

    func resetRoom() {
        store?.clear(room: room.id, persist: true)
        boxes = room.boxes.map { UnpackingBoxState(spec: $0) }
        items.removeAll()
        particles.removeAll()
        rings.removeAll()
        heldID = nil
        hoverSurfaceID = nil
        hoverPreviewPos = nil
        hintSurfaceID = nil
        celebrateAt = nil
        isDone = false
        complete = false
        shouldShowDoneButtons = false
        didReward = false
        roomGlow = 0
        placedCount = 0
        zCounter = 1
        TidySound.shared.play(.whoosh, volume: 0.5)
    }

    // MARK: - Box Interaction

    /// Tapping a closed box opens its flaps (`returns nil`); tapping an open box pops out one surprise item.
    @discardableResult
    func tapBox(_ boxID: String) -> UnpackingItemState? {
        guard let box = boxes.first(where: { $0.id == boxID && !$0.isGone && !$0.isCollapsing }) else { return nil }

        if !box.isOpened {
            box.isOpened = true
            box.kick = 1
            TidySound.shared.play(.pop, volume: 0.72, rate: 1.12)
            TidySound.shared.haptic(.light)
            spawnPuffs(at: CGPoint(x: box.spec.rect.midX, y: box.spec.rect.minY), count: 5)
            spawnSparkles(at: CGPoint(x: box.spec.rect.midX, y: box.spec.rect.minY - 6), count: 6, color: TRGB(0xFFE38A))
            persistProgress()
            return nil
        }

        return popNextItem(from: box, immediatelyHeld: false, fingerPoint: nil)
    }

    @discardableResult
    private func popNextItem(from box: UnpackingBoxState, immediatelyHeld: Bool, fingerPoint: CGPoint?) -> UnpackingItemState? {
        guard !box.remaining.isEmpty else { return nil }
        let spec = box.remaining.removeFirst()
        let item = UnpackingItemState(spec: spec)
        zCounter += 1
        item.z = zCounter

        let stagedExistingCount = items.filter { $0.phase == .staged || $0.phase == .emerging }.count
        let stagedPos = stagedPoint(for: box, size: item.size, slotIndex: stagedExistingCount)
        let originPt = CGPoint(x: box.spec.rect.midX, y: box.spec.rect.minY + 12)
        item.emergeStart = originPt
        item.homeStagedPos = stagedPos
        item.pos = originPt
        item.squashVel = 4.5

        if immediatelyHeld, let fp = fingerPoint {
            item.phase = .held
            item.lift = 0.4
            heldID = item.id
            wasPlacedBeforeGrab = false
            previousSurfaceID = nil
            finger = fp
            grabOffset = CGPoint(x: originPt.x - carriedPoint(for: item, finger: fp).x,
                                 y: originPt.y - carriedPoint(for: item, finger: fp).y)
            heldVel = .zero
            TidySound.shared.play(.pickup, volume: 0.72, rate: 1.1)
        } else {
            item.phase = .emerging
            item.emergeElapsed = 0
            TidySound.shared.play(.pop, volume: 0.65, rate: Float.random(in: 1.02...1.22))
        }

        items.append(item)
        box.kick = 1
        TidySound.shared.haptic(.light)
        spawnPuffs(at: CGPoint(x: box.spec.rect.midX, y: box.spec.rect.minY), count: 4)
        spawnSparkles(at: CGPoint(x: box.spec.rect.midX, y: box.spec.rect.minY - 12), count: 5, color: TidyPalette.c(item.color).light)

        if box.remaining.isEmpty {
            startBoxCollapse(box)
        }
        return item
    }

    private func startBoxCollapse(_ box: UnpackingBoxState) {
        guard !box.isCollapsing else { return }
        box.isCollapsing = true
        box.kick = 0.85
        TidySound.shared.play(.pop, volume: 0.6, rate: 1.35)
        spawnSparkles(at: CGPoint(x: box.spec.rect.midX, y: box.spec.rect.midY), count: 10, color: TRGB(0xFFE38A))
        spawnPuffs(at: CGPoint(x: box.spec.rect.midX, y: box.spec.rect.midY), count: 6)
    }

    private func stagedPoint(for box: UnpackingBoxState, size: CGSize, slotIndex: Int) -> CGPoint {
        let offsets: [CGFloat] = [0, -76, 76, -148, 148]
        let dx = offsets[slotIndex % offsets.count]
        let halfW = size.width * 0.5 + 14
        let x = min(max(box.spec.rect.midX + dx, halfW), Self.stageSize.width - halfW)
        let y = min(box.spec.rect.minY - size.height * 0.5 - 24, room.floorY - size.height * 0.5 - 120)
        return CGPoint(x: x, y: max(180, y))
    }

    // MARK: - Free-Form Surface Matching

    /// Finds the best compatible `SurfaceZone` under or near `point`, or `nil` if incompatible.
    func bestSurface(for item: UnpackingItemState, at point: CGPoint) -> SurfaceZone? {
        bestSurface(for: item.kind, at: point)
    }

    func bestSurface(for kind: UnpackingItemKind, at point: CGPoint) -> SurfaceZone? {
        let allowed = kind.allowedSurfaces
        let halfH = kind.size.height * 0.5
        // Standing items naturally aim with their lower body / base; wall items aim with their center.
        let probe = kind.prefersWall ? point : CGPoint(x: point.x, y: point.y + halfH * 0.35)

        var candidates: [(zone: SurfaceZone, score: CGFloat)] = []
        for zone in room.surfaces where allowed.contains(zone.kind) {
            let expanded = zone.rect.insetBy(dx: -24, dy: zone.kind == .wall ? -18 : -32)
            let hit = expanded.contains(point) || expanded.contains(probe)
            guard hit else { continue }
            let resolved = resolvedPoint(for: kind, on: zone, near: point)
            var dist = hypot(resolved.x - point.x, resolved.y - point.y)
            // Gently prefer wall surfaces for wall-art items when cleanly inside the wall rect,
            // and prefer furniture ledges/desks/beds/floors for standing items.
            if kind.prefersWall && zone.kind == .wall && zone.rect.contains(point) {
                dist *= 0.65
            } else if !kind.prefersWall && zone.kind != .wall {
                dist *= 0.85
            }
            candidates.append((zone, dist))
        }

        return candidates.min(by: { $0.score < $1.score })?.zone
    }

    /// Computes the free-form grounded center point along `zone` clamped safely within its bounds.
    func resolvedPoint(for item: UnpackingItemState, on zone: SurfaceZone, near point: CGPoint) -> CGPoint {
        resolvedPoint(for: item.kind, on: zone, near: point)
    }

    func resolvedPoint(for kind: UnpackingItemKind, on zone: SurfaceZone, near point: CGPoint) -> CGPoint {
        let halfW = kind.size.width * 0.5
        let halfH = kind.size.height * 0.5

        let minX = zone.rect.minX + halfW
        let maxX = zone.rect.maxX - halfW
        let clampedX = minX <= maxX ? min(max(point.x, minX), maxX) : zone.rect.midX

        if zone.kind == .wall {
            let minY = zone.rect.minY + halfH
            let maxY = zone.rect.maxY - halfH
            let clampedY = minY <= maxY ? min(max(point.y, minY), maxY) : zone.rect.midY
            return CGPoint(x: clampedX, y: clampedY)
        } else {
            let groundedY = min(zone.restY, 760) - halfH
            return CGPoint(x: clampedX, y: groundedY)
        }
    }

    private func preferredHintSurface(for kind: UnpackingItemKind) -> String? {
        if kind.prefersWall, let w = room.surfaces.first(where: { $0.kind == .wall }) {
            return w.id
        }
        return room.surfaces.first(where: { kind.allowedSurfaces.contains($0.kind) })?.id
    }

    // MARK: - FingerLift Geometry

    func lift(for item: UnpackingItemState) -> CGFloat {
        FingerLift.carry(below: item.size.height * 0.5)
    }

    func carriedPoint(for item: UnpackingItemState, finger f: CGPoint) -> CGPoint {
        FingerLift.point(f, lift: lift(for: item), top: 96, bottom: Self.stageSize.height, width: Self.stageSize.width)
    }

    func finger(toHold item: UnpackingItemState, at target: CGPoint) -> CGPoint {
        FingerLift.finger(for: target, lift: lift(for: item), top: 96, bottom: Self.stageSize.height, width: Self.stageSize.width)
    }

    // MARK: - Touch Handling

    func touchDown(_ p: CGPoint) {
        finger = p
        touchDownPos = p
        touchDownTime = time
        draggedFromBoxID = nil

        guard heldID == nil else { return }

        // 1. Check active unplaced items (staged / emerging) first so they're effortless to grab.
        let unplaced = items.filter { $0.phase == .staged || $0.phase == .emerging }.sorted { $0.z > $1.z }
        if let hit = unplaced.first(where: { $0.contains(p) }) {
            beginHolding(hit, at: p)
            return
        }

        // 2. Check moving boxes (tapped to open or pull an item).
        if let box = boxes.first(where: { !$0.isGone && !$0.isCollapsing && $0.spec.rect.insetBy(dx: -12, dy: -12).contains(p) }) {
            if !box.isOpened {
                tapBox(box.id)
            } else {
                draggedFromBoxID = box.id
            }
            return
        }

        // 3. Check already-placed items (top-most `z` first so overlapping decor lifts cleanly).
        let placed = items.filter { $0.phase == .placed }.sorted { $0.z > $1.z }
        if let hit = placed.first(where: { $0.contains(p) }) {
            beginHolding(hit, at: p)
        }
    }

    func touchMoved(_ p: CGPoint) {
        finger = p

        // Seamless pull-drag right out of an open box if she drags without releasing first!
        if heldID == nil, let boxID = draggedFromBoxID {
            let movedDist = hypot(p.x - touchDownPos.x, p.y - touchDownPos.y)
            if movedDist > 12, let box = boxes.first(where: { $0.id == boxID && $0.isOpened && !$0.remaining.isEmpty }) {
                draggedFromBoxID = nil
                popNextItem(from: box, immediatelyHeld: true, fingerPoint: p)
            }
        }
    }

    func touchUp(_ p: CGPoint) {
        finger = p

        // Quick tap on an open box pops out one surprise item onto the preview spot!
        if let boxID = draggedFromBoxID {
            draggedFromBoxID = nil
            tapBox(boxID)
            return
        }

        guard let id = heldID, let item = items.first(where: { $0.id == id }) else { return }
        heldID = nil
        hoverSurfaceID = nil
        hoverPreviewPos = nil

        let movedDist = hypot(p.x - touchDownPos.x, p.y - touchDownPos.y)
        let elapsed = time - touchDownTime

        // Short tap on an already-placed item triggers its cute interactive animation/sound!
        if wasPlacedBeforeGrab && movedDist < 16 && elapsed < 0.38 {
            item.phase = .placed
            item.pos = previousPlacedPos
            item.surfaceID = previousSurfaceID
            item.lift = 0
            item.tilt = 0
            triggerInteraction(for: item)
            return
        }

        if let zone = bestSurface(for: item, at: item.pos) {
            let dest = resolvedPoint(for: item, on: zone, near: item.pos)
            item.surfaceID = zone.id
            item.targetPos = dest
            item.phase = .settling
            TidySound.shared.play(.whoosh, volume: 0.25, rate: 1.25)
        } else {
            bounceBack(item)
        }
    }

    private func beginHolding(_ item: UnpackingItemState, at p: CGPoint) {
        wasPlacedBeforeGrab = (item.phase == .placed)
        previousPlacedPos = item.pos
        previousSurfaceID = item.surfaceID
        item.phase = .held
        heldID = item.id
        zCounter += 1
        item.z = zCounter
        item.squashVel += 3.2
        let carried = carriedPoint(for: item, finger: p)
        grabOffset = CGPoint(x: item.pos.x - carried.x, y: item.pos.y - carried.y)
        heldVel = .zero
        TidySound.shared.play(.pickup, volume: 0.68, rate: Float(1.16 - min(0.28, item.size.height / 500)))
        TidySound.shared.haptic(.light)
    }

    /// Directly attempts to drop an item at `point` (used by unit tests and programmatic placement).
    @discardableResult
    func dropItem(_ itemID: String, at point: CGPoint) -> Bool {
        guard let item = items.first(where: { $0.id == itemID }) else { return false }
        wasPlacedBeforeGrab = (item.phase == .placed)
        previousPlacedPos = item.pos
        previousSurfaceID = item.surfaceID
        item.pos = point

        if let zone = bestSurface(for: item, at: point) {
            let dest = resolvedPoint(for: item, on: zone, near: point)
            item.surfaceID = zone.id
            item.targetPos = dest
            land(item, on: zone)
            return true
        } else {
            bounceBack(item)
            return false
        }
    }

    private func bounceBack(_ item: UnpackingItemState) {
        item.phase = .bouncingBack
        item.bounceStart = item.pos
        item.bounceReturnsToPlaced = wasPlacedBeforeGrab && previousSurfaceID != nil
        item.bounceTarget = item.bounceReturnsToPlaced ? previousPlacedPos : item.homeStagedPos
        item.surfaceID = item.bounceReturnsToPlaced ? previousSurfaceID : nil
        item.bounceElapsed = 0
        item.squashVel += 3.0
        lastBounceAt = time
        hintSurfaceID = preferredHintSurface(for: item.kind)
        hintAt = time
        Sound.shared.play(.boing, volume: 0.46)
        TidySound.shared.haptic(.soft)
    }

    // MARK: - Interactive Placed Items

    func triggerInteraction(for item: UnpackingItemState) {
        item.squashVel += 5.0
        item.interactTimer = 1.0

        switch item.kind {
        case .deskLamp:
            item.isLit.toggle()
            TidySound.shared.play(.click, volume: 0.72, rate: item.isLit ? 1.2 : 0.9)
            TidySound.shared.haptic(.light)
            if item.isLit {
                spawnSparkles(at: CGPoint(x: item.pos.x, y: item.pos.y - 16), count: 8, color: TRGB(0xFFE38A))
            }
            persistProgress()
        case .fairyLights:
            item.isLit.toggle()
            Sound.shared.play(.sparkle, volume: 0.55)
            TidySound.shared.haptic(.light)
            if item.isLit {
                spawnSparkles(at: item.pos, count: 10, color: TRGB(0xFFE38A))
            }
            persistProgress()
        case .musicBox:
            let notes: [SFX] = [.note1, .note2, .note3, .note4]
            Sound.shared.play(notes[musicNoteIndex % notes.count], volume: 0.75)
            musicNoteIndex += 1
            spawnSparkles(at: CGPoint(x: item.pos.x, y: item.pos.y - 24), count: 7, color: TRGB(0xFF9AC2))
        case .alarmClock:
            Sound.shared.play(.ding, volume: 0.62)
            TidySound.shared.haptic(.rigid)
            spawnSparkles(at: CGPoint(x: item.pos.x, y: item.pos.y - 26), count: 6, color: TRGB(0xFFE38A))
        case .plushBunny, .plushCat, .teddy:
            TidySound.shared.play(.boop, volume: 0.58, rate: 1.28)
            TidySound.shared.haptic(.soft)
            spawnHearts(at: CGPoint(x: item.pos.x, y: item.pos.y - item.size.height * 0.45), count: 3)
        case .riceCooker:
            Sound.shared.play(.ding, volume: 0.55)
            TidySound.shared.play(.pop, volume: 0.42, rate: 1.2)
            spawnSteam(at: CGPoint(x: item.pos.x, y: item.pos.y - item.size.height * 0.45), count: 6)
        case .hanbokDoll:
            Sound.shared.play(.sparkle, volume: 0.6)
            spawnSparkles(at: CGPoint(x: item.pos.x, y: item.pos.y - 14), count: 8, color: TRGB(0xFF9AC2))
            spawnHearts(at: CGPoint(x: item.pos.x, y: item.pos.y - 36), count: 2)
        case .jewelCompact:
            Sound.shared.play(.sparkle, volume: 0.62)
            spawnSparkles(at: item.pos, count: 9, color: TRGB(0x9CE8FF))
        case .piggyBank:
            Sound.shared.play(.coin, volume: 0.62)
            spawnSparkles(at: CGPoint(x: item.pos.x, y: item.pos.y - 18), count: 6, color: TRGB(0xFFE38A))
        case .kettle, .teapot:
            TidySound.shared.play(.clink, volume: 0.55, rate: 1.15)
            spawnSteam(at: CGPoint(x: item.pos.x + 14, y: item.pos.y - 20), count: 4)
        default:
            TidySound.shared.place(item.kind.material, volume: 0.55, rate: 1.05)
        }
    }

    // MARK: - Landing & Completion

    private func land(_ item: UnpackingItemState, on zone: SurfaceZone) {
        item.phase = .placed
        item.pos = item.targetPos
        item.lift = 0
        item.tilt = 0
        item.squashVel -= 5.6

        if item.kind.isLighting && !item.isLit {
            item.isLit = true
        }

        combo = (time - lastPlace < 5) ? (combo + 1) : 0
        lastPlace = time
        let rate = Float(0.92 + 0.045 * Double(min(combo, 9)))
        TidySound.shared.place(item.kind.material, rate: rate)
        TidySound.shared.haptic(item.kind.material == .plush ? .soft : .rigid)

        let c = TidyPalette.c(item.color)
        rings.append(TidyRing(pos: TVec(item.pos), born: time, color: c.light, size: max(item.size.width, item.size.height)))
        spawnSparkles(at: item.pos, count: 9, color: c.light)

        if TidyWorld.hasStarBroom {
            rings.append(TidyRing(pos: TVec(item.pos), born: time, color: TRGB(0xFFD559), size: max(item.size.width, item.size.height) * 1.25))
            spawnSparkles(at: item.pos, count: 10, color: TRGB(0xFFCF4A))
        }

        placedCount = items.filter { $0.phase == .placed }.count
        persistProgress()
        checkCompletion()
    }

    private func checkCompletion() {
        guard !isDone else { return }
        guard allBoxesEmpty,
              items.count == totalItemCount,
              items.allSatisfy({ $0.phase == .placed }) else { return }
        celebrateAt = time + 0.2
    }

    private func celebrate() {
        isDone = true
        celebrateAt = nil
        complete = true
        shouldShowDoneButtons = true

        // Turn on all warm cozy lights across the finished room!
        for item in items where item.kind.isLighting {
            item.isLit = true
        }

        persistProgress()

        if !didReward {
            didReward = true
            Coins.shared.earn(Self.completionRewardCoins, game: TidyGame.id, from: CGPoint(x: 512, y: 380))
            unlockStickersForRoom()
        }

        TidySound.shared.play(.chime, volume: 0.9)
        TidySound.shared.success()

        // Joyful celebration bounce & sparkle wave across her decorated room!
        for item in items where item.phase == .placed {
            item.squashVel += 5.5
            spawnSparkles(at: CGPoint(x: item.pos.x, y: item.pos.y - item.size.height * 0.4), count: 3, color: TRGB(0xFFE38A))
        }
        let colors = TidyPalette.colors
        for k in 0..<96 {
            let x = CGFloat.random(in: 24...(Self.stageSize.width - 24))
            particles.append(UnpackingEffectParticle(
                kind: .confetti,
                pos: TVec(x, CGFloat.random(in: -110 ... -10)),
                vel: TVec(CGFloat.random(in: -110...110), CGFloat.random(in: 50...240)),
                born: time,
                life: Double.random(in: 2.3...3.5),
                size: CGFloat.random(in: 8...14),
                color: colors[k % 8],
                rot: CGFloat.random(in: 0...6),
                spin: CGFloat.random(in: -8...8)
            ))
        }
    }

    private func unlockStickersForRoom() {
        StickerBook.shared.find(game: TidyGame.id, id: TidyFind.firstRoom.rawValue)
        switch room.id {
        case .koreanKitchen:
            StickerBook.shared.find(game: TidyGame.id, id: TidyFind.kitchenWhiz.rawValue)
        case .bedroom, .livingRoom:
            StickerBook.shared.find(game: TidyGame.id, id: TidyFind.cozyCloset.rawValue)
        case .fairyPlayroom, .artNook, .starlightBalcony:
            StickerBook.shared.find(game: TidyGame.id, id: TidyFind.toyMaster.rawValue)
        }
        if (store?.completedCount ?? 0) >= 6 {
            StickerBook.shared.find(game: TidyGame.id, id: TidyFind.tidyChampion.rawValue)
        }
    }

    // MARK: - Simulation Step

    func step(to date: Date) {
        guard let last = lastDate else { lastDate = date; return }
        var dt = date.timeIntervalSince(last)
        lastDate = date
        if dt <= 0 { return }
        dt = min(dt, 1.0 / 20.0)
        var left = dt
        while left > 1e-6 {
            let h = min(Self.fixedStep, left)
            advance(h)
            left -= h
        }
    }

    /// Deterministic stepper for unit tests and demos.
    func simulate(seconds: Double) {
        var t = 0.0
        while t < seconds {
            advance(Self.fixedStep)
            t += Self.fixedStep
        }
    }

    private func advance(_ dt: Double) {
        time += dt
        let fdt = CGFloat(dt)

        // Smooth room lighting warmth
        let hasLitLight = items.contains { $0.phase == .placed && $0.kind.isLighting && $0.isLit }
        let targetGlow: Double = isDone ? 1.0 : (hasLitLight ? 0.55 : 0.0)
        roomGlow += (targetGlow - roomGlow) * min(1, dt * 3.5)

        // Boxes: tape peel, flap opening, kick recovery, and empty-box collapse
        for box in boxes {
            box.kick = max(0, box.kick - fdt * 4.5)
            if box.isCollapsing {
                box.openProgress = max(0, box.openProgress - fdt * 5.2)
                if box.openProgress < 0.25 {
                    box.collapseProgress = min(1, box.collapseProgress + fdt * 2.8)
                    if box.collapseProgress >= 1 {
                        box.isGone = true
                    }
                }
            } else if box.isOpened {
                box.tapePeel = min(1, box.tapePeel + fdt * 5.5)
                box.openProgress = min(1, box.openProgress + fdt * 5.0)
            }
        }

        // Items: emerge arc, held carry, settling spring, bounce-back, squash & interact timers
        for item in items {
            item.squashVel += (-item.squash * 850 - item.squashVel * 16) * fdt
            item.squash += item.squashVel * fdt
            if item.interactTimer > 0 {
                item.interactTimer = max(0, item.interactTimer - dt * 1.15)
            }

            switch item.phase {
            case .emerging:
                item.emergeElapsed += dt
                let dur = 0.32
                let u = min(1, item.emergeElapsed / dur)
                let ease = 1 - pow(1 - u, 3)
                let arc = sin(u * .pi) * 62
                item.pos = CGPoint(
                    x: item.emergeStart.x + (item.homeStagedPos.x - item.emergeStart.x) * CGFloat(ease),
                    y: item.emergeStart.y + (item.homeStagedPos.y - item.emergeStart.y) * CGFloat(ease) - CGFloat(arc)
                )
                item.lift = CGFloat(sin(u * .pi)) * 0.45
                if u >= 1 {
                    item.phase = .staged
                    item.pos = item.homeStagedPos
                    item.lift = 0
                    item.squashVel -= 3.5
                }

            case .staged:
                item.lift = max(0, item.lift - fdt * 6)
                item.tilt *= (1 - min(1, fdt * 10))

            case .held:
                grabOffset = CGPoint(x: grabOffset.x * (1 - min(1, fdt * 8)), y: grabOffset.y * (1 - min(1, fdt * 8)))
                let carried = carriedPoint(for: item, finger: finger)
                let goal = CGPoint(x: carried.x + grabOffset.x, y: carried.y + grabOffset.y)
                let prev = item.pos
                item.pos = CGPoint(
                    x: item.pos.x + (goal.x - item.pos.x) * min(1, fdt * 28),
                    y: item.pos.y + (goal.y - item.pos.y) * min(1, fdt * 28)
                )
                let inst = TVec((item.pos.x - prev.x) / max(0.001, fdt), (item.pos.y - prev.y) / max(0.001, fdt))
                heldVel = heldVel * 0.84 + inst * 0.16
                let targetTilt = max(-0.32, min(0.32, heldVel.x * 0.00038))
                item.tilt += (targetTilt - item.tilt) * min(1, fdt * 14)
                item.lift = min(1, item.lift + fdt * 9)

                if let zone = bestSurface(for: item, at: item.pos) {
                    hoverSurfaceID = zone.id
                    hoverPreviewPos = resolvedPoint(for: item, on: zone, near: item.pos)
                } else {
                    hoverSurfaceID = nil
                    hoverPreviewPos = nil
                }

            case .settling:
                let dx = item.targetPos.x - item.pos.x
                let dy = item.targetPos.y - item.pos.y
                let step = min(1, fdt * 22)
                item.pos = CGPoint(x: item.pos.x + dx * step, y: item.pos.y + dy * step)
                item.tilt *= (1 - min(1, fdt * 16))
                item.lift = max(0, item.lift - fdt * 7)
                if hypot(dx, dy) < 2.2 {
                    if let sid = item.surfaceID, let zone = room.surface(id: sid) {
                        land(item, on: zone)
                    } else {
                        item.phase = .staged
                    }
                }

            case .bouncingBack:
                item.bounceElapsed += dt
                let dur = 0.34
                let u = min(1, item.bounceElapsed / dur)
                let ease = 1 - pow(1 - u, 3)
                let arc = sin(u * .pi) * 48
                item.pos = CGPoint(
                    x: item.bounceStart.x + (item.bounceTarget.x - item.bounceStart.x) * CGFloat(ease),
                    y: item.bounceStart.y + (item.bounceTarget.y - item.bounceStart.y) * CGFloat(ease) - CGFloat(arc)
                )
                item.lift = CGFloat(sin(u * .pi)) * 0.35
                item.tilt = CGFloat(sin(u * .pi * 2)) * 0.16
                if u >= 1 {
                    item.pos = item.bounceTarget
                    item.lift = 0
                    item.tilt = 0
                    item.squashVel -= 4.2
                    item.phase = item.bounceReturnsToPlaced ? .placed : .staged
                }

            case .placed:
                item.lift = 0
                item.tilt = 0
            }
        }

        // Particles & rings
        for i in particles.indices {
            var p = particles[i]
            switch p.kind {
            case .sparkle:
                p.vel.y += 320 * fdt
                p.vel = p.vel * (1 - 2.2 * fdt)
            case .puff:
                p.vel = p.vel * (1 - 3.2 * fdt)
            case .confetti:
                p.vel.y += 460 * fdt
                p.vel = p.vel * (1 - 1.5 * fdt)
                p.vel.x += CGFloat(sin((time - p.born) * 8 + Double(p.size))) * 220 * fdt
            case .heart:
                p.vel.y -= 90 * fdt
                p.vel.x += CGFloat(sin((time - p.born) * 6)) * 45 * fdt
            case .steam:
                p.vel.y -= 75 * fdt
                p.vel.x += CGFloat(sin((time - p.born) * 5 + Double(p.size))) * 35 * fdt
            }
            p.pos += p.vel * fdt
            p.rot += p.spin * fdt
            particles[i] = p
        }
        particles.removeAll { time - $0.born > $0.life }
        rings.removeAll { time - $0.born > 0.6 }

        if let c = celebrateAt, time >= c, !isDone {
            celebrate()
        }
    }

    // MARK: - Particle Spawners

    private func spawnSparkles(at pt: CGPoint, count: Int, color: TRGB) {
        let palette: [TRGB] = [TRGB(0xFFE38A), .white, color]
        for k in 0..<count {
            let a = Double(k) / Double(max(1, count)) * 2 * .pi + Double.random(in: -0.2...0.2)
            let sp = CGFloat.random(in: 120...260)
            particles.append(UnpackingEffectParticle(
                kind: .sparkle,
                pos: TVec(pt),
                vel: TVec(CGFloat(cos(a)) * sp, CGFloat(sin(a)) * sp - 70),
                born: time,
                life: Double.random(in: 0.45...0.8),
                size: CGFloat.random(in: 10...18),
                color: palette[k % palette.count],
                rot: CGFloat.random(in: 0...(.pi)),
                spin: CGFloat.random(in: -6...6)
            ))
        }
    }

    private func spawnPuffs(at pt: CGPoint, count: Int) {
        for _ in 0..<count {
            particles.append(UnpackingEffectParticle(
                kind: .puff,
                pos: TVec(pt.x + CGFloat.random(in: -22...22), pt.y),
                vel: TVec(CGFloat.random(in: -90...90), CGFloat.random(in: -85 ... -20)),
                born: time,
                life: Double.random(in: 0.35...0.65),
                size: CGFloat.random(in: 10...18),
                color: .white,
                rot: 0,
                spin: 0
            ))
        }
    }

    private func spawnHearts(at pt: CGPoint, count: Int) {
        for k in 0..<count {
            particles.append(UnpackingEffectParticle(
                kind: .heart,
                pos: TVec(pt.x + CGFloat(k * 16 - (count - 1) * 8), pt.y),
                vel: TVec(CGFloat.random(in: -25...25), CGFloat.random(in: -95 ... -55)),
                born: time,
                life: Double.random(in: 0.75...1.1),
                size: CGFloat.random(in: 13...18),
                color: TRGB(0xFF77AB),
                rot: 0,
                spin: 0
            ))
        }
    }

    private func spawnSteam(at pt: CGPoint, count: Int) {
        for _ in 0..<count {
            particles.append(UnpackingEffectParticle(
                kind: .steam,
                pos: TVec(pt.x + CGFloat.random(in: -12...12), pt.y),
                vel: TVec(CGFloat.random(in: -22...22), CGFloat.random(in: -80 ... -40)),
                born: time,
                life: Double.random(in: 0.7...1.15),
                size: CGFloat.random(in: 9...16),
                color: .white,
                rot: 0,
                spin: 0
            ))
        }
    }
}
