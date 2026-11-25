import SwiftUI
import UIKit

// MARK: - Backyard Playhouse domain model

enum PlayhouseBackdrop {
    static let porch = "playhouse_porch"
    static let livingRoom = "playhouse_living"
    static let originals = [porch, livingRoom]

    static func isCustom(_ id: String) -> Bool {
        id == porch || id == livingRoom
    }
}

enum PlayhouseFreezePose: Int, CaseIterable, Equatable {
    case oneLegTilt
    case handsUpSurprised
    case sillyWink

    var tiltDegrees: Double {
        switch self {
        case .oneLegTilt: return 16
        case .handsUpSurprised: return -4
        case .sillyWink: return -13
        }
    }

    var liftPoints: CGFloat {
        switch self {
        case .oneLegTilt: return 10
        case .handsUpSurprised: return 26
        case .sillyWink: return 6
        }
    }
}

enum TeaTreatKind: String, CaseIterable, Identifiable {
    case strawberryCake
    case bungeoppang
    case cupcake
    case teapot

    var id: String { rawValue }
    var isDrink: Bool { self == .teapot }
}

struct PlayhouseActor: Identifiable, Equatable {
    let id: UUID
    var look: Look?
    var pet: PetLook?
    var thing: String?
    /// Normalized stage coordinates (0...1).
    var x: Double
    var y: Double
    var flip = false
    var lift = false
    var happy = false
    var armsUp = false
    var nibbling = false
    var freezePose: PlayhouseFreezePose?

    init(
        id: UUID = UUID(),
        look: Look? = nil,
        pet: PetLook? = nil,
        thing: String? = nil,
        x: Double,
        y: Double,
        flip: Bool = false
    ) {
        self.id = id
        self.look = look
        self.pet = pet
        self.thing = thing
        self.x = x
        self.y = y
        self.flip = flip
    }

    var isLiving: Bool { look != nil || pet != nil }
    var isFrozen: Bool { freezePose != nil }
}

struct KeepyUppyBalloon: Equatable {
    static let palette: [UInt32] = [0xFF8FB8, 0x8CD4FF, 0xFFE07A, 0x9FE3CF, 0xC9B6FF, 0xFFB085]

    /// Stage-space coordinates (in points).
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var colorIndex: Int
    var squash: CGFloat = 1
    var bounces: Int = 0
    var phase: Double = 0

    var colorHex: UInt32 {
        Self.palette[((colorIndex % Self.palette.count) + Self.palette.count) % Self.palette.count]
    }
}

struct PlayhouseTreat: Identifiable, Equatable {
    let id: UUID
    var kind: TeaTreatKind
    /// Normalized stage coordinates (0...1).
    var x: Double
    var y: Double
    var bitesLeft: Int

    init(id: UUID = UUID(), kind: TeaTreatKind, x: Double, y: Double, bitesLeft: Int = 3) {
        self.id = id
        self.kind = kind
        self.x = x
        self.y = y
        self.bitesLeft = bitesLeft
    }
}

struct PlayhouseParticle: Identifiable {
    enum Kind { case sparkle, note, heart, crumb, confetti }
    let id = UUID()
    var kind: Kind
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var age: Double = 0
    var life: Double
    var size: CGFloat
    var color: Color
    var spin: Double
}

struct PlayhouseStepEvents: Equatable {
    var actorBoppedIDs: [UUID] = []
    var floorBounce = false
}

/// Pure simulation state for Keepy Uppy Balloon, Magic Xylophone freeze toggle, and Tea Party treats.
struct PlayhouseState {
    var bg: String = PlayhouseBackdrop.porch
    var actors: [PlayhouseActor] = []
    var balloon: KeepyUppyBalloon?
    var treats: [PlayhouseTreat] = []
    var particles: [PlayhouseParticle] = []
    var activeXylophoneBar: Int?
    var xylophonePulseAge: Double = 1
    private var actorBopCooldown: [UUID: Double] = [:]
    private var nextBalloonColor = 0
    var elapsed: Double = 0

    var isAnyFrozen: Bool {
        actors.contains { $0.isLiving && $0.isFrozen }
    }

    var needsAnimationTick: Bool {
        balloon != nil || !particles.isEmpty || xylophonePulseAge < 0.45
    }

    var sceneSignature: String {
        let castSig = actors.map { a in
            let kind = a.look != nil ? "d" : (a.pet?.kind ?? a.thing ?? "p")
            let rx = Int((a.x * 20).rounded())
            let ry = Int((a.y * 20).rounded())
            let fr = a.freezePose?.rawValue ?? -1
            return "\(kind):\(rx),\(ry),\(a.flip ? 1 : 0),\(fr)"
        }.joined(separator: "|")
        let balSig = balloon != nil ? "b\(balloon?.colorIndex ?? 0)" : "nb"
        let treatSig = treats.map { "\($0.kind.rawValue)\($0.bitesLeft)" }.joined(separator: ",")
        return "\(bg)#\(castSig)#\(balSig)#\(treatSig)"
    }

    // MARK: Keepy Uppy Balloon

    mutating func spawnOrBoostBalloon(stageSize: CGSize) {
        let w = max(300, stageSize.width)
        let h = max(260, stageSize.height)
        if var b = balloon {
            nextBalloonColor = (nextBalloonColor + 1) % KeepyUppyBalloon.palette.count
            b.colorIndex = nextBalloonColor
            b.vy = -340
            b.vx += (b.x < w * 0.5 ? 70 : -70)
            b.squash = 0.78
            b.bounces += 1
            balloon = b
            emitSparkles(at: CGPoint(x: b.x, y: b.y), count: 7, kind: .sparkle)
        } else {
            let color = nextBalloonColor
            nextBalloonColor = (nextBalloonColor + 1) % KeepyUppyBalloon.palette.count
            let startX = w * 0.5
            let startY = h * 0.24
            balloon = KeepyUppyBalloon(x: startX, y: startY, vx: 48, vy: -90, colorIndex: color, squash: 1.15)
            emitSparkles(at: CGPoint(x: startX, y: startY), count: 9, kind: .sparkle)
        }
    }

    @discardableResult
    mutating func tapBalloon(at point: CGPoint, hitRadius: CGFloat = 74) -> Bool {
        guard var b = balloon else { return false }
        let dx = point.x - b.x
        let dy = point.y - b.y
        guard dx * dx + dy * dy <= hitRadius * hitRadius else { return false }
        b.vy = -370
        let nudge = max(-150, min(150, (b.x - point.x) * 3.2))
        b.vx = b.vx * 0.45 + nudge + (abs(nudge) < 12 ? (b.bounces % 2 == 0 ? 45 : -45) : 0)
        b.squash = 0.74
        b.bounces += 1
        balloon = b
        emitSparkles(at: CGPoint(x: b.x, y: b.y), count: 8, kind: .sparkle)
        return true
    }

    @discardableResult
    mutating func step(dt rawDT: Double, stageSize: CGSize) -> PlayhouseStepEvents {
        let dt = min(0.05, max(0, rawDT))
        guard dt > 0 else { return PlayhouseStepEvents() }
        elapsed += dt
        xylophonePulseAge = min(1, xylophonePulseAge + dt)

        for key in Array(actorBopCooldown.keys) {
            let rem = (actorBopCooldown[key] ?? 0) - dt
            if rem <= 0 { actorBopCooldown.removeValue(forKey: key) } else { actorBopCooldown[key] = rem }
        }

        var events = PlayhouseStepEvents()

        if var b = balloon, stageSize.width > 40, stageSize.height > 40 {
            let gravity: CGFloat = 215
            let breeze = CGFloat(sin(elapsed * 1.45 + b.phase)) * 42
            let drag = CGFloat(pow(0.985, dt * 60))
            b.vx = (b.vx + breeze * CGFloat(dt)) * drag
            b.vy = min(230, b.vy + gravity * CGFloat(dt))
            b.x += b.vx * CGFloat(dt)
            b.y += b.vy * CGFloat(dt)
            b.squash += (1 - b.squash) * min(1, CGFloat(dt) * 10)
            b.phase += dt * 0.5

            let minX: CGFloat = 52
            let maxX = stageSize.width - 52
            let minY: CGFloat = 62
            let floorY = stageSize.height - 54

            if b.x < minX {
                b.x = minX
                b.vx = abs(b.vx) * 0.8 + 24
                b.squash = 0.86
            } else if b.x > maxX {
                b.x = maxX
                b.vx = -abs(b.vx) * 0.8 - 24
                b.squash = 0.86
            }
            if b.y < minY {
                b.y = minY
                b.vy = abs(b.vy) * 0.4 + 30
                b.squash = 0.86
            }

            // Unfrozen dolls and pets leap up to bounce the balloon whenever it dips near them.
            if b.vy > -30 {
                for i in actors.indices {
                    let a = actors[i]
                    guard a.isLiving, !a.isFrozen, actorBopCooldown[a.id] == nil else { continue }
                    let k = Self.depthScale(forY: a.y)
                    let actorX = stageSize.width * a.x
                    let actorFeetY = stageSize.height * a.y
                    let actorH: CGFloat = (a.look != nil ? 420 : 185) * k
                    let reachTopY = actorFeetY - actorH * 0.96
                    let reachBottomY = actorFeetY - actorH * 0.12
                    let reachHalfW: CGFloat = (a.look != nil ? 102 : 84) * k

                    if abs(b.x - actorX) < reachHalfW && b.y >= reachTopY && b.y <= reachBottomY {
                        b.vy = -375
                        let aimCenter = (stageSize.width * 0.5 - actorX) * 0.55
                        b.vx = max(-185, min(185, aimCenter + (b.bounces % 2 == 0 ? 55 : -55)))
                        b.y = min(b.y, reachTopY + 14)
                        b.squash = 0.72
                        b.bounces += 1
                        actorBopCooldown[a.id] = 0.55
                        events.actorBoppedIDs.append(a.id)
                        emitSparkles(at: CGPoint(x: b.x, y: b.y + 18), count: 8, kind: .sparkle)
                        break
                    }
                }
            }

            if b.y >= floorY {
                b.y = floorY
                b.vy = -245
                b.squash = 0.76
                events.floorBounce = true
            }
            balloon = b
        }

        if !particles.isEmpty {
            for i in particles.indices {
                particles[i].age += dt
                particles[i].x += particles[i].vx * CGFloat(dt)
                particles[i].y += particles[i].vy * CGFloat(dt)
                if particles[i].kind == .confetti || particles[i].kind == .crumb {
                    particles[i].vy += 260 * CGFloat(dt)
                }
            }
            particles.removeAll { $0.age >= $0.life }
        }

        return events
    }

    // MARK: Magic Xylophone

    /// Toggles dolls and pets between hilarious frozen statue poses and unfrozen joyful bounces.
    /// Returns `true` when actors were frozen, `false` when unfrozen.
    @discardableResult
    mutating func triggerXylophone(bar: Int, stageSize: CGSize) -> Bool {
        let clampedBar = max(0, min(3, bar))
        activeXylophoneBar = clampedBar
        xylophonePulseAge = 0

        let barColors: [Color] = [Color(hex: 0xFF7B9C), Color(hex: 0xFFE066), Color(hex: 0x7FE0B8), Color(hex: 0x82C8FF)]
        let noteColor = barColors[clampedBar]

        if isAnyFrozen {
            for i in actors.indices where actors[i].isLiving {
                actors[i].freezePose = nil
                let px = stageSize.width * actors[i].x
                let py = stageSize.height * actors[i].y - 170
                emitNotes(at: CGPoint(x: px, y: py), color: noteColor, count: 4)
            }
            return false
        } else {
            let poses = PlayhouseFreezePose.allCases
            var livingIndex = 0
            for i in actors.indices where actors[i].isLiving {
                let pose = poses[(clampedBar + livingIndex) % poses.count]
                actors[i].freezePose = pose
                livingIndex += 1
                let px = stageSize.width * actors[i].x
                let py = stageSize.height * actors[i].y - 180
                emitNotes(at: CGPoint(x: px, y: py), color: noteColor, count: 5)
            }
            return true
        }
    }

    // MARK: Backyard Tea Party

    mutating func setOutTeaParty() {
        let positions: [(TeaTreatKind, Double, Double)] = [
            (.strawberryCake, 0.25, 0.87),
            (.bungeoppang, 0.42, 0.90),
            (.cupcake, 0.59, 0.90),
            (.teapot, 0.75, 0.87),
        ]
        treats = positions.map { PlayhouseTreat(kind: $0.0, x: $0.1, y: $0.2, bitesLeft: $0.0.isDrink ? 99 : 3) }
    }

    /// Feeds `treatID` to the nearest living actor (or explicit `targetActorID`), returning the actor who nibbled.
    @discardableResult
    mutating func nibbleTreat(_ treatID: UUID, nearActor targetActorID: UUID? = nil, stageSize: CGSize) -> UUID? {
        guard let ti = treats.firstIndex(where: { $0.id == treatID }) else { return nil }
        let treat = treats[ti]
        let chosenIndex: Int?
        if let explicit = targetActorID,
           let idx = actors.firstIndex(where: { $0.id == explicit && $0.isLiving }) {
            chosenIndex = idx
        } else {
            chosenIndex = actors.indices
                .filter { actors[$0].isLiving }
                .min { a, b in
                    hypot(actors[a].x - treat.x, actors[a].y - treat.y) <
                    hypot(actors[b].x - treat.x, actors[b].y - treat.y)
                }
        }
        guard let ai = chosenIndex else { return nil }
        let actorID = actors[ai].id
        actors[ai].freezePose = nil

        let pt = CGPoint(x: stageSize.width * actors[ai].x, y: stageSize.height * actors[ai].y - 165)
        emitSparkles(at: pt, count: 6, kind: .heart)
        emitSparkles(at: CGPoint(x: pt.x, y: pt.y + 30), count: 5, kind: .crumb)

        if !treat.kind.isDrink {
            treats[ti].bitesLeft -= 1
            if treats[ti].bitesLeft <= 0 {
                treats.remove(at: ti)
            }
        }
        return actorID
    }

    mutating func emitConfetti(in stageSize: CGSize) {
        let colors: [Color] = [Theme.pink, Theme.lemon, Theme.mint, Theme.sky, Theme.lilac, Theme.peach]
        for i in 0..<28 {
            let a = Double(i) / 28.0 * .pi * 2 + Double(i % 3) * 0.12
            let speed = CGFloat(130 + (i % 5) * 45)
            particles.append(PlayhouseParticle(
                kind: .confetti,
                x: stageSize.width * 0.5,
                y: stageSize.height * 0.34,
                vx: CGFloat(cos(a)) * speed,
                vy: CGFloat(sin(a)) * speed - 110,
                life: 1.35,
                size: CGFloat(9 + (i % 3) * 4),
                color: colors[i % colors.count],
                spin: Double((i % 2 == 0 ? 1 : -1) * 240)
            ))
        }
    }

    private mutating func emitSparkles(at p: CGPoint, count: Int, kind: PlayhouseParticle.Kind) {
        let colors: [Color] = [.white, Theme.lemon, Theme.pink, Theme.mint, Theme.sky]
        for i in 0..<count {
            let a = Double(i) / Double(max(1, count)) * .pi * 2 + elapsed
            let speed = CGFloat(55 + (i % 3) * 35)
            particles.append(PlayhouseParticle(
                kind: kind,
                x: p.x,
                y: p.y,
                vx: CGFloat(cos(a)) * speed,
                vy: CGFloat(sin(a)) * speed - (kind == .heart ? 75 : 25),
                life: kind == .crumb ? 0.7 : 0.95,
                size: CGFloat(kind == .crumb ? 6 : 11 + (i % 3) * 3),
                color: kind == .heart ? Theme.pink : colors[i % colors.count],
                spin: Double((i % 2 == 0 ? 1 : -1) * 160)
            ))
        }
    }

    private mutating func emitNotes(at p: CGPoint, color: Color, count: Int) {
        for i in 0..<count {
            let spread = CGFloat(i - count / 2) * 32
            particles.append(PlayhouseParticle(
                kind: .note,
                x: p.x + spread * 0.3,
                y: p.y,
                vx: spread * 0.85,
                vy: -85 - CGFloat(i % 3) * 25,
                life: 1.15,
                size: CGFloat(15 + (i % 2) * 5),
                color: i % 2 == 0 ? color : Theme.lemon,
                spin: Double((i % 2 == 0 ? 1 : -1) * 30)
            ))
        }
    }

    static func depthScale(forY y: Double) -> CGFloat {
        0.62 + 0.40 * CGFloat(max(0, min(1, (y - 0.35) / 0.65)))
    }
}

// MARK: - Snapshot Renderer (real UIImage saving!)

enum PlayhouseSnapshotRenderer {
    static let snapshotSize = CGSize(width: 1200, height: 800)

    @MainActor
    static func render(
        bg: String,
        actors: [PlayhouseActor],
        balloon: KeepyUppyBalloon?,
        treats: [PlayhouseTreat],
        me: Look,
        sourceStageSize: CGSize = CGSize(width: 1024, height: 616),
        outputSize: CGSize = snapshotSize
    ) -> UIImage? {
        let view = PlayhouseSnapshotCanvas(
            bg: bg,
            actors: actors,
            balloon: balloon,
            treats: treats,
            me: me,
            sourceStageSize: sourceStageSize
        )
        .frame(width: outputSize.width, height: outputSize.height)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        return renderer.uiImage
    }
}

private struct PlayhouseSnapshotCanvas: View {
    let bg: String
    let actors: [PlayhouseActor]
    let balloon: KeepyUppyBalloon?
    let treats: [PlayhouseTreat]
    let me: Look
    let sourceStageSize: CGSize

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                PlayhouseBackdropView(bg: bg)
                    .frame(width: size.width, height: size.height)

                ForEach(actors.sorted { $0.y < $1.y }) { a in
                    let k = PlayhouseState.depthScale(forY: a.y) * (size.height / 616)
                    let box = DressUpView.stageBox
                    let dollH: CGFloat = 415 * k
                    let w: CGFloat = a.look != nil ? dollH * box.width / box.height : (a.pet != nil ? 185 : 112) * k
                    let h: CGFloat = a.look != nil ? dollH : w
                    let freezeTilt = a.freezePose?.tiltDegrees ?? 0
                    let freezeLift = (a.freezePose?.liftPoints ?? 0) * (size.height / 616)

                    PlayhouseActorArtwork(actor: a, me: me, forceSmile: true)
                        .frame(width: w, height: h)
                        .scaleEffect(x: a.flip ? -1 : 1, y: 1)
                        .rotationEffect(.degrees(freezeTilt), anchor: .bottom)
                        .offset(y: -freezeLift)
                        .position(x: size.width * a.x, y: size.height * a.y - h / 2)
                }

                ForEach(treats) { treat in
                    let s = 82 * (size.height / 616)
                    TeaTreatArtView(kind: treat.kind, bitesLeft: treat.bitesLeft)
                        .frame(width: s, height: s)
                        .position(x: size.width * treat.x, y: size.height * treat.y - s * 0.35)
                }

                if let b = balloon {
                    let sx = size.width / max(1, sourceStageSize.width)
                    let sy = size.height / max(1, sourceStageSize.height)
                    Canvas { ctx, _ in
                        PlayhouseBalloonPainter.draw(
                            balloon: KeepyUppyBalloon(
                                x: b.x * sx,
                                y: b.y * sy,
                                vx: b.vx,
                                vy: b.vy,
                                colorIndex: b.colorIndex,
                                squash: b.squash,
                                bounces: b.bounces,
                                phase: b.phase
                            ),
                            scale: sy,
                            in: ctx
                        )
                    }
                    .frame(width: size.width, height: size.height)
                }
            }
            .clipped()
        }
    }
}

// MARK: - Backyard Playhouse View (StoryStage)

struct StoryStage: View {
    let me: Look
    let friends: [Look]
    let store: LookStore?
    let close: () -> Void

    @State private var playhouse: PlayhouseState
    @State private var petSave: PetSave
    @State private var selectedActor: UUID?
    @State private var tab = 0
    @State private var movingActor: (id: UUID, x: Double, y: Double)?
    @State private var movingTreat: (id: UUID, x: Double, y: Double)?
    @State private var overBin = false
    @State private var flash = false
    @State private var snapBurst = 0
    @State private var lastSnapPreview: UIImage?
    @State private var lastTickDate: Date?
    @State private var currentStageSize = CGSize(width: 1024, height: 616)

    init(me: Look, friends: [Look], store: LookStore? = nil, close: @escaping () -> Void) {
        self.me = me
        self.friends = friends
        self.store = store
        self.close = close

        let loadedPets = GameStorage.load(PetSave.self, game: LookStore.game, file: "pets.json") ?? PetSave()
        _petSave = State(initialValue: loadedPets)

        var cast: [PlayhouseActor] = [PlayhouseActor(look: me, x: 0.31, y: 0.91)]
        if let friend = friends.first {
            cast.append(PlayhouseActor(look: friend, x: 0.69, y: 0.90, flip: true))
        }
        let starterPet = me.pet ?? loadedPets.look(loadedPets.current).sanitized()
        if let starterPet {
            cast.append(PlayhouseActor(pet: starterPet, x: 0.50, y: 0.94))
        }

        var initial = PlayhouseState()
        initial.bg = PlayhouseBackdrop.porch
        initial.actors = cast
        _playhouse = State(initialValue: initial)
        _selectedActor = State(initialValue: cast.first?.id)
    }

    private static let stageHeight: CGFloat = 616
    private static let trayHeight: CGFloat = 196
    private let art = DressUpArt.shared

    var body: some View {
        ZStack {
            PlayhouseBackdropView(bg: playhouse.bg)
                .ignoresSafeArea()
                .id(playhouse.bg)
                .transition(.opacity)
            if !PlayhouseBackdrop.isCustom(playhouse.bg) {
                SceneLife(bg: playhouse.bg)
                    .ignoresSafeArea()
                    .id("life." + playhouse.bg)
            }
            DesignCanvas {
                VStack(spacing: 0) {
                    GeometryReader { g in
                        stage(g.size)
                            .onAppear { currentStageSize = g.size }
                            .onChange(of: g.size) { newSize in currentStageSize = newSize }
                    }
                    .frame(height: Self.stageHeight)

                    tray
                        .frame(height: Self.trayHeight)
                        .padding(.horizontal, 18)
                        .padding(.bottom, 12)
                }
                .overlay(alignment: .top) { topBar }
                .coinPurse(game: LookStore.game)
            }
            if flash {
                Color.white.ignoresSafeArea().transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: playhouse.bg)
    }

    // MARK: Top bar & toy dock

    private var topBar: some View {
        HStack(spacing: 12) {
            RoundButton(symbol: "chevron.down", tint: Theme.pink, size: GameChromeLayout.buttonSize) {
                Sound.shared.play(.whoosh, volume: 0.6)
                close()
            }

            // Keepy Uppy Balloon toy button
            Button {
                Sound.shared.play(.boing, volume: 0.75)
                Sound.shared.tap()
                playhouse.spawnOrBoostBalloon(stageSize: currentStageSize)
                lastTickDate = Date()
            } label: {
                ToyCircleIcon(tint: Color(hex: 0xFF7FA8)) {
                    Canvas { ctx, size in
                        PlayhouseBalloonPainter.drawIcon(in: ctx, size: size)
                    }
                }
            }
            .buttonStyle(Squish())

            // Backyard Tea Party picnic basket button
            Button {
                Sound.shared.play(.sparkle, volume: 0.75)
                Sound.shared.tap()
                withAnimation(.spring(response: 0.38, dampingFraction: 0.65)) {
                    playhouse.setOutTeaParty()
                }
            } label: {
                ToyCircleIcon(tint: Color(hex: 0xF5A855)) {
                    Canvas { ctx, size in
                        PicnicBasketIconPainter.draw(in: ctx, size: size)
                    }
                }
            }
            .buttonStyle(Squish())

            Spacer()

            CoinCounter(game: LookStore.game, height: GameChromeLayout.buttonSize)

            if !playhouse.actors.isEmpty {
                RoundButton(symbol: "arrow.left.and.right", tint: Color(hex: 0x9B79E0), size: GameChromeLayout.buttonSize) {
                    flipSelected()
                }
            }

            RoundButton(symbol: "camera.fill", tint: Color(hex: 0xF45C9A), size: GameChromeLayout.buttonSize) {
                snapStage()
            }
            .overlay(alignment: .bottomLeading) {
                if let preview = lastSnapPreview {
                    Image(uiImage: preview)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(.white, lineWidth: 2.5))
                        .shadow(color: Theme.ink.opacity(0.25), radius: 4, y: 2)
                        .offset(x: -16, y: 14)
                        .transition(.scale.combined(with: .opacity))
                        .allowsHitTesting(false)
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
    }

    // MARK: Interactive Playhouse Stage

    private func stage(_ size: CGSize) -> some View {
        ZStack {
            // Actors sorted by floor depth
            ForEach(playhouse.actors.sorted { $0.y < $1.y }) { a in
                actorView(a, in: size)
            }

            // Backyard Tea Party treats
            ForEach(playhouse.treats) { treat in
                treatView(treat, in: size)
            }

            // Physics-driven Keepy Uppy Balloon & musical/confetti/heart particles (paused when idle!)
            TimelineView(.animation(minimumInterval: 1.0 / 60, paused: !playhouse.needsAnimationTick)) { tl in
                Canvas { ctx, canvasSize in
                    if let b = playhouse.balloon {
                        PlayhouseBalloonPainter.draw(balloon: b, scale: 1, in: ctx)
                    }
                    PlayhouseParticlePainter.draw(playhouse.particles, in: ctx, size: canvasSize)
                }
                .onChange(of: tl.date) { now in
                    advancePhysics(to: now, size: size)
                }
            }
            .allowsHitTesting(false)

            // Generous tap hitbox over the Keepy Uppy Balloon
            if let b = playhouse.balloon {
                Color.clear
                    .frame(width: 148, height: 158)
                    .contentShape(Circle())
                    .position(x: b.x, y: b.y)
                    .onTapGesture {
                        if playhouse.tapBalloon(at: CGPoint(x: b.x, y: b.y + 12)) {
                            let sfx: SFX = (playhouse.balloon?.bounces ?? 0) % 3 == 0 ? .pop : .boing
                            Sound.shared.play(sfx, volume: 0.78)
                            Sound.shared.tap()
                            lastTickDate = Date()
                        }
                    }
            }

            // Compact rainbow 4-bar Magic Xylophone at the deck edge
            magicXylophone(in: size)
                .position(x: size.width - 134, y: size.height - 52)

            if snapBurst > 0 {
                TwinkleBurst(colors: [.white, Theme.lemon, Theme.pink, Theme.mint], count: 16, radius: 220)
                    .id(snapBurst)
                    .position(x: size.width / 2, y: size.height * 0.45)
            }

            if movingActor != nil || movingTreat != nil {
                Image(systemName: overBin ? "trash.fill" : "trash")
                    .font(.system(size: overBin ? 40 : 32, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 88, height: 88)
                    .background(Circle().fill(overBin ? Color(hex: 0xE8475A) : Theme.ink.opacity(0.45)))
                    .overlay(Circle().stroke(.white, lineWidth: 4))
                    .position(binCenter(size))
                    .allowsHitTesting(false)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private func advancePhysics(to now: Date, size: CGSize) {
        let dt = lastTickDate.map { now.timeIntervalSince($0) } ?? (1.0 / 60.0)
        lastTickDate = now
        let events = playhouse.step(dt: dt, stageSize: size)
        if events.floorBounce {
            Sound.shared.play(.pop, volume: 0.55)
        }
        for actorID in events.actorBoppedIDs {
            Sound.shared.play(.boing, volume: 0.75)
            bounceActor(actorID, armsUp: true)
        }
    }

    private func binCenter(_ size: CGSize) -> CGPoint {
        CGPoint(x: 78, y: size.height - 64)
    }

    // MARK: Magic Xylophone Toy

    private func magicXylophone(in size: CGSize) -> some View {
        let barColors: [UInt32] = [0xFF7B9C, 0xFFE066, 0x7FE0B8, 0x82C8FF]
        let notes: [SFX] = [.note1, .note2, .note3, .note4]
        let frozen = playhouse.isAnyFrozen

        return ZStack {
            // Warm honey wooden frame rails
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(hex: 0xD89B62))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(frozen ? Color(hex: 0x8CD4FF) : .white, lineWidth: 4)
                )
                .shadow(color: Theme.ink.opacity(0.24), radius: 8, y: 4)

            HStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { i in
                    let isPulsing = playhouse.activeXylophoneBar == i && playhouse.xylophonePulseAge < 0.35
                    let barHeight: CGFloat = 62 - CGFloat(i) * 5
                    Button {
                        Sound.shared.play(notes[i], volume: 0.85)
                        Sound.shared.tap()
                        let nowFrozen = withAnimation(.spring(response: 0.28, dampingFraction: 0.58)) {
                            playhouse.triggerXylophone(bar: i, stageSize: size)
                        }
                        lastTickDate = Date()
                        if !nowFrozen {
                            Sound.shared.play(.boing, volume: 0.55)
                            for a in playhouse.actors where a.isLiving {
                                bounceActor(a.id, armsUp: false)
                            }
                        }
                    } label: {
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(Color(hex: barColors[i]))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                                        .stroke(StorybookArt.outline(for: barColors[i]), lineWidth: 2.5)
                                )
                                .overlay(alignment: .top) {
                                    Circle().fill(.white.opacity(0.85)).frame(width: 7, height: 7).padding(.top, 6)
                                }
                                .overlay(alignment: .bottom) {
                                    Circle().fill(.white.opacity(0.85)).frame(width: 7, height: 7).padding(.bottom, 6)
                                }
                                .frame(width: 40, height: barHeight)
                                .scaleEffect(isPulsing ? 1.12 : 1)
                            Spacer(minLength: 0)
                        }
                    }
                    .buttonStyle(Squish())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 214, height: 80)
        .overlay(alignment: .topTrailing) {
            Image(systemName: frozen ? "snowflake" : "music.note")
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Circle().fill(frozen ? Color(hex: 0x62B6FF) : Theme.pink))
                .overlay(Circle().stroke(.white, lineWidth: 2.5))
                .offset(x: 8, y: -10)
                .allowsHitTesting(false)
        }
    }

    // MARK: Actors & Treats

    private func actorView(_ a: PlayhouseActor, in size: CGSize) -> some View {
        let k = PlayhouseState.depthScale(forY: a.y)
        let box = DressUpView.stageBox
        let dollH: CGFloat = 415 * k
        let w: CGFloat = a.look != nil ? dollH * box.width / box.height : (a.pet != nil ? 185 : 112) * k
        let h: CGFloat = a.look != nil ? dollH : w
        let isSelected = selectedActor == a.id
        let freezeTilt = a.freezePose?.tiltDegrees ?? 0
        let freezeLift = a.freezePose?.liftPoints ?? 0
        let bounceLift: CGFloat = a.lift ? 38 * k : 0

        return ZStack(alignment: .bottom) {
            if isSelected {
                Ellipse()
                    .fill(Theme.lemon.opacity(0.45))
                    .overlay(Ellipse().stroke(.white.opacity(0.88), lineWidth: 2.5))
                    .frame(width: max(64, w * 0.62), height: max(18, 22 * k))
                    .offset(y: 4)
            }

            PlayhouseActorArtwork(actor: a, me: me, forceSmile: false)
                .frame(width: w, height: h)
                .scaleEffect(x: a.flip ? -1 : 1, y: 1)
                .scaleEffect(movingActor?.id == a.id ? 1.07 : (a.armsUp ? 1.06 : 1), anchor: .bottom)
                .rotationEffect(.degrees(freezeTilt + (a.armsUp ? (a.flip ? -5 : 5) : 0)), anchor: .bottom)
                .offset(y: -(bounceLift + freezeLift))
                .overlay(alignment: .top) {
                    if a.isFrozen {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                            Image(systemName: "music.note")
                        }
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color(hex: 0x70C6FF))
                        .shadow(color: .white, radius: 2)
                        .offset(y: -18 - freezeLift)
                        .allowsHitTesting(false)
                    } else if a.armsUp {
                        Image(systemName: "sparkle")
                            .font(.system(size: 22, weight: .black))
                            .foregroundStyle(Theme.lemon)
                            .shadow(color: .white, radius: 2)
                            .offset(y: -24 - bounceLift)
                            .allowsHitTesting(false)
                    }
                }
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { flip(a.id) }
        .onTapGesture { poke(a.id) }
        .gesture(
            DragGesture(minimumDistance: 4)
                .onChanged { v in
                    guard let i = index(a.id) else { return }
                    if movingActor?.id != a.id {
                        selectedActor = a.id
                        movingActor = (a.id, playhouse.actors[i].x, playhouse.actors[i].y)
                        Sound.shared.play(.tap, volume: 0.6)
                    }
                    guard let m = movingActor else { return }
                    playhouse.actors[i].x = m.x + v.translation.width / size.width
                    playhouse.actors[i].y = m.y + v.translation.height / size.height
                    let bin = inBin(x: playhouse.actors[i].x, y: playhouse.actors[i].y, size: size)
                    if bin != overBin { withAnimation(.spring(response: 0.25)) { overBin = bin } }
                }
                .onEnded { _ in dropActor(a.id, size) }
        )
        .position(x: size.width * a.x, y: size.height * a.y - h / 2)
    }

    private func treatView(_ treat: PlayhouseTreat, in size: CGSize) -> some View {
        let isDragging = movingTreat?.id == treat.id
        let itemSize: CGFloat = isDragging ? 96 : 82

        return TeaTreatArtView(kind: treat.kind, bitesLeft: treat.bitesLeft)
            .frame(width: itemSize, height: itemSize)
            .shadow(color: Theme.ink.opacity(0.18), radius: 6, y: 4)
            .contentShape(Circle())
            .onTapGesture {
                feedNearestActor(treatID: treat.id, preferredActor: selectedActor, in: size)
            }
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { v in
                        guard let i = playhouse.treats.firstIndex(where: { $0.id == treat.id }) else { return }
                        if movingTreat?.id != treat.id {
                            movingTreat = (treat.id, playhouse.treats[i].x, playhouse.treats[i].y)
                            Sound.shared.play(.tap, volume: 0.5)
                        }
                        guard let m = movingTreat else { return }
                        playhouse.treats[i].x = m.x + v.translation.width / size.width
                        playhouse.treats[i].y = m.y + v.translation.height / size.height
                        let bin = inBin(x: playhouse.treats[i].x, y: playhouse.treats[i].y, size: size)
                        if bin != overBin { withAnimation(.spring(response: 0.25)) { overBin = bin } }
                    }
                    .onEnded { _ in dropTreat(treat.id, in: size) }
            )
            .position(x: size.width * treat.x, y: size.height * treat.y - itemSize * 0.35)
    }

    // MARK: Actions

    private func index(_ id: UUID) -> Int? { playhouse.actors.firstIndex { $0.id == id } }

    private func inBin(x: Double, y: Double, size: CGSize) -> Bool {
        let c = binCenter(size)
        let dx = x * size.width - c.x
        let dy = y * size.height - c.y
        return dx * dx + dy * dy < 88 * 88
    }

    private func dropActor(_ id: UUID, _ size: CGSize) {
        defer { withAnimation(.spring(response: 0.3)) { movingActor = nil; overBin = false } }
        guard let i = index(id) else { return }
        if inBin(x: playhouse.actors[i].x, y: playhouse.actors[i].y, size: size)
            || playhouse.actors[i].x < -0.05 || playhouse.actors[i].x > 1.05 {
            Sound.shared.play(.whoosh, volume: 0.7)
            withAnimation(.spring(response: 0.3)) {
                playhouse.actors.remove(at: i)
                if selectedActor == id { selectedActor = playhouse.actors.last?.id }
            }
            return
        }
        Sound.shared.play(.pop, volume: 0.6)
        withAnimation(.spring(response: 0.3)) {
            playhouse.actors[i].x = min(0.95, max(0.05, playhouse.actors[i].x))
            playhouse.actors[i].y = min(0.98, max(0.32, playhouse.actors[i].y))
        }
    }

    private func dropTreat(_ treatID: UUID, in size: CGSize) {
        defer { withAnimation(.spring(response: 0.3)) { movingTreat = nil; overBin = false } }
        guard let ti = playhouse.treats.firstIndex(where: { $0.id == treatID }) else { return }
        let treat = playhouse.treats[ti]
        if inBin(x: treat.x, y: treat.y, size: size) {
            Sound.shared.play(.whoosh, volume: 0.6)
            withAnimation(.spring(response: 0.3)) { playhouse.treats.remove(at: ti) }
            return
        }

        // If dropped near any doll or pet, let them take a happy sparkly nibble!
        let nearActor = playhouse.actors
            .filter { $0.isLiving }
            .first { a in
                let dx = CGFloat(a.x - treat.x) * size.width
                let dy = CGFloat(a.y - 0.18 - treat.y) * size.height
                return hypot(dx, dy) < 165
            }
        if let target = nearActor {
            feedNearestActor(treatID: treatID, preferredActor: target.id, in: size)
            return
        }

        Sound.shared.play(.pop, volume: 0.5)
        withAnimation(.spring(response: 0.3)) {
            playhouse.treats[ti].x = min(0.92, max(0.08, playhouse.treats[ti].x))
            playhouse.treats[ti].y = min(0.96, max(0.45, playhouse.treats[ti].y))
        }
    }

    private func feedNearestActor(treatID: UUID, preferredActor: UUID?, in size: CGSize) {
        let matchedActor = withAnimation(.spring(response: 0.3, dampingFraction: 0.62)) {
            playhouse.nibbleTreat(treatID, nearActor: preferredActor, stageSize: size)
        }
        guard let actorID = matchedActor else { return }
        Sound.shared.play(.bubble, volume: 0.75)
        Sound.shared.play(.sparkle, volume: 0.5)
        Sound.shared.tap()
        lastTickDate = Date()
        bounceActor(actorID, armsUp: false, nibbling: true)
    }

    private func poke(_ id: UUID) {
        guard let i = index(id) else { return }
        selectedActor = id
        if playhouse.actors[i].isFrozen {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.55)) {
                playhouse.actors[i].freezePose = nil
            }
            Sound.shared.play(.sparkle, volume: 0.7)
        } else {
            Sound.shared.play(playhouse.actors[i].look != nil ? .boing : .bubble, volume: 0.7)
        }
        Sound.shared.tap()
        bounceActor(id, armsUp: false)
    }

    private func bounceActor(_ id: UUID, armsUp: Bool, nibbling: Bool = false) {
        guard let i = index(id) else { return }
        withAnimation(.spring(response: 0.22, dampingFraction: 0.5)) {
            playhouse.actors[i].lift = true
            playhouse.actors[i].happy = true
            if armsUp { playhouse.actors[i].armsUp = true }
            if nibbling { playhouse.actors[i].nibbling = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
            guard let j = index(id) else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) {
                playhouse.actors[j].lift = false
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {
            guard let j = index(id) else { return }
            playhouse.actors[j].happy = false
            playhouse.actors[j].armsUp = false
            playhouse.actors[j].nibbling = false
        }
    }

    private func flip(_ id: UUID) {
        guard let i = index(id) else { return }
        selectedActor = id
        Sound.shared.play(.whoosh, volume: 0.65)
        Sound.shared.tap()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.62)) {
            playhouse.actors[i].flip.toggle()
            playhouse.actors[i].lift = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            guard let j = index(id) else { return }
            withAnimation(.spring(response: 0.28, dampingFraction: 0.6)) {
                playhouse.actors[j].lift = false
            }
        }
    }

    private func flipSelected() {
        if let id = selectedActor, index(id) != nil {
            flip(id)
        } else if let last = playhouse.actors.last?.id {
            flip(last)
        }
    }

    /// Renders the live Backyard Playhouse scene into a real UIImage and saves it into Dress Up's gallery.
    @MainActor
    private func snapStage() {
        Sound.shared.play(.fanfare, volume: 0.8)
        Sound.shared.tap()
        snapBurst += 1
        playhouse.emitConfetti(in: currentStageSize)
        lastTickDate = Date()
        DressUpFind.storyDirector.unlock()

        if let image = PlayhouseSnapshotRenderer.render(
            bg: playhouse.bg,
            actors: playhouse.actors,
            balloon: playhouse.balloon,
            treats: playhouse.treats,
            me: me,
            sourceStageSize: currentStageSize
        ) {
            if let store {
                store.savePlayhouseSnapshot(image)
                store.awardPlayhouseSnapCoins(
                    signature: playhouse.sceneSignature,
                    from: CGPoint(x: 512, y: 360)
                )
            } else {
                let fallbackStore = LookStore()
                fallbackStore.savePlayhouseSnapshot(image)
                fallbackStore.awardPlayhouseSnapCoins(
                    signature: playhouse.sceneSignature,
                    from: CGPoint(x: 512, y: 360)
                )
            }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                lastSnapPreview = image
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                withAnimation(.easeOut(duration: 0.35)) { lastSnapPreview = nil }
            }
        }

        withAnimation(.easeOut(duration: 0.08)) { flash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.easeIn(duration: 0.35)) { flash = false }
        }
        for a in playhouse.actors {
            bounceActor(a.id, armsUp: true)
        }
    }

    private func bringOn(look: Look? = nil, pet: PetLook? = nil, thing: String? = nil) {
        Sound.shared.play(.sparkle, volume: 0.7)
        Sound.shared.tap()
        let yRange: ClosedRange<Double> = look != nil ? 0.84...0.95 : (pet != nil ? 0.86...0.96 : 0.45...0.92)
        var a = PlayhouseActor(
            look: look,
            pet: pet,
            thing: thing,
            x: .random(in: 0.18...0.82),
            y: .random(in: yRange)
        )
        a.flip = a.x > 0.5
        selectedActor = a.id
        withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
            playhouse.actors.append(a)
            if playhouse.actors.count > 16 { playhouse.actors.removeFirst(playhouse.actors.count - 16) }
        }
    }

    // MARK: Bottom Tray (Backdrops, Saved Dolls, PetCorner Pets, Props)

    private var tray: some View {
        HStack(spacing: 12) {
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    tabButton(0, symbol: "house.fill", tint: Color(hex: 0x46B7B0))
                    tabButton(1, symbol: "person.2.fill", tint: Color(hex: 0xF45C9A))
                }
                HStack(spacing: 6) {
                    tabButton(2, symbol: "pawprint.fill", tint: Color(hex: 0xFFA24C))
                    tabButton(3, symbol: "star.fill", tint: Color(hex: 0xFFC93C))
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    switch tab {
                    case 0: scenes
                    case 1: people
                    case 2: pets
                    default: props
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 8)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 36, style: .continuous).fill(Theme.cream.opacity(0.96)))
        .overlay(RoundedRectangle(cornerRadius: 36, style: .continuous).stroke(Theme.blush, lineWidth: 4))
        .shadow(color: Theme.ink.opacity(0.18), radius: 16, y: 8)
    }

    private func tabButton(_ i: Int, symbol: String, tint: Color) -> some View {
        Button {
            Sound.shared.play(.tap)
            tab = i
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(tab == i ? .white : tint)
                .frame(width: 66, height: 68)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(tab == i ? Theme.pink.opacity(0.92) : Theme.blush.opacity(0.7)))
        }
        .buttonStyle(Squish())
    }

    private func card<Content: View>(selected: Bool = false, width: CGFloat = 120, @ViewBuilder _ content: () -> Content,
                                     action: @escaping () -> Void) -> some View {
        Button(action: action) {
            content()
                .frame(width: width, height: 148)
                .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color(hex: 0xFFF7FA)))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(selected ? Theme.pink : Color(hex: 0xF5DDE8), lineWidth: selected ? 6 : 3))
        }
        .buttonStyle(Squish())
    }

    @ViewBuilder private var scenes: some View {
        let allScenes = PlayhouseBackdrop.originals + (art.category("bg")?.items ?? [])
        ForEach(allScenes, id: \.self) { id in
            card(selected: playhouse.bg == id, width: 170) {
                PlayhouseBackdropView(bg: id)
            } action: {
                Sound.shared.play(.ding, volume: 0.7)
                playhouse.bg = id
            }
        }
    }

    @ViewBuilder private var people: some View {
        ForEach([me] + Array(friends.prefix(30))) { l in
            card {
                DollView(look: l, box: CGRect(x: 110, y: 30, width: 380, height: 540))
                    .padding(6)
            } action: { bringOn(look: l) }
        }
    }

    @ViewBuilder private var pets: some View {
        ForEach(PetArt.shared.order, id: \.self) { kind in
            let dressed = petSave.look(kind).sanitized() ?? PetLook(kind: kind)
            card(width: 120) {
                PetThumb(pet: dressed)
                    .padding(8)
            } action: { bringOn(pet: dressed) }
        }
    }

    @ViewBuilder private var props: some View {
        ForEach(Stickers.all(for: me).filter { $0 != "mypet" && !$0.hasPrefix("pet:") }, id: \.self) { kind in
            card(width: 110) {
                StickerView(kind: kind, look: me).padding(18)
            } action: { bringOn(thing: kind) }
        }
    }
}

// MARK: - Actor Artwork

private struct PlayhouseActorArtwork: View {
    let actor: PlayhouseActor
    let me: Look
    let forceSmile: Bool

    private var dollExpression: Expression {
        if forceSmile || actor.happy || actor.armsUp || actor.nibbling { return .happy }
        if actor.freezePose == .sillyWink { return .blink }
        return .normal
    }

    private var petPose: PetPose {
        var pose = PetPose()
        if forceSmile || actor.happy || actor.armsUp {
            pose.eyes = "happy"
            pose.mouth = "grin"
        } else if actor.nibbling {
            pose.eyes = "sparkle"
            pose.mouth = "yum"
        } else if actor.freezePose == .handsUpSurprised {
            pose.eyes = "sparkle"
            pose.mouth = "o"
        } else if actor.freezePose == .sillyWink {
            pose.eyes = "blink"
            pose.mouth = "grin"
        }
        return pose
    }

    var body: some View {
        if let l = actor.look {
            DollView(look: l, expression: dollExpression, box: DressUpView.stageBox)
        } else if let pet = actor.pet {
            PetThumb(pet: pet, pose: petPose)
        } else if let t = actor.thing {
            StickerView(kind: t, look: me)
        }
    }
}

// MARK: - Custom Backyard Porch & Sunny Living Room Backdrops

struct PlayhouseBackdropView: View {
    let bg: String

    var body: some View {
        switch bg {
        case PlayhouseBackdrop.porch:
            Canvas { ctx, size in drawBackyardPorch(in: ctx, size: size) }
        case PlayhouseBackdrop.livingRoom:
            Canvas { ctx, size in drawSunnyLivingRoom(in: ctx, size: size) }
        default:
            SceneView(bg: bg)
        }
    }

    private func drawBackyardPorch(in ctx: GraphicsContext, size: CGSize) {
        let w = size.width, h = size.height

        // Warm sunny Queensland sky
        ctx.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .linearGradient(
                Gradient(colors: [Color(hex: 0x8ED8FF), Color(hex: 0xD2F1FF), Color(hex: 0xFFF7DA)]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: h * 0.62)
            )
        )

        // Glowing warm sun in top-right sky
        let sunC = CGPoint(x: w * 0.84, y: h * 0.16)
        ctx.fill(
            Path(ellipseIn: CGRect(x: sunC.x - 110, y: sunC.y - 110, width: 220, height: 220)),
            with: .radialGradient(
                Gradient(colors: [Color(hex: 0xFFF3A8).opacity(0.65), .clear]),
                center: sunC, startRadius: 12, endRadius: 110
            )
        )
        StorybookArt.shape(ctx, Path(ellipseIn: CGRect(x: sunC.x - 36, y: sunC.y - 36, width: 72, height: 72)), hex: 0xFFE378, width: 3.5)

        // Fluffy storybook clouds
        for (cx, cy, s) in [(w * 0.22, h * 0.14, 1.0), (w * 0.56, h * 0.11, 0.82)] as [(CGFloat, CGFloat, CGFloat)] {
            var cloud = Path()
            cloud.addEllipse(in: CGRect(x: cx - 54 * s, y: cy - 16 * s, width: 64 * s, height: 38 * s))
            cloud.addEllipse(in: CGRect(x: cx - 22 * s, y: cy - 30 * s, width: 66 * s, height: 48 * s))
            cloud.addEllipse(in: CGRect(x: cx + 18 * s, y: cy - 14 * s, width: 52 * s, height: 34 * s))
            ctx.fill(cloud, with: .color(.white.opacity(0.92)))
        }

        // Rolling sunlit backyard hills
        var hillBack = Path()
        hillBack.move(to: CGPoint(x: 0, y: h * 0.48))
        hillBack.addQuadCurve(to: CGPoint(x: w, y: h * 0.46), control: CGPoint(x: w * 0.45, y: h * 0.34))
        hillBack.addLine(to: CGPoint(x: w, y: h))
        hillBack.addLine(to: CGPoint(x: 0, y: h))
        hillBack.closeSubpath()
        ctx.fill(hillBack, with: .color(Color(hex: 0xA8E39B)))

        var lawn = Path()
        lawn.move(to: CGPoint(x: 0, y: h * 0.53))
        lawn.addQuadCurve(to: CGPoint(x: w, y: h * 0.52), control: CGPoint(x: w * 0.62, y: h * 0.45))
        lawn.addLine(to: CGPoint(x: w, y: h))
        lawn.addLine(to: CGPoint(x: 0, y: h))
        lawn.closeSubpath()
        ctx.fill(lawn, with: .color(Color(hex: 0x8ED985)))

        // Flowering backyard blossom / poinciana tree on the left
        let trunk = Path(roundedRect: CGRect(x: w * 0.08, y: h * 0.25, width: w * 0.045, height: h * 0.32), cornerRadius: 12)
        StorybookArt.shape(ctx, trunk, hex: 0xB87E56, width: 3.5)
        for (px, py, r, col) in [
            (w * 0.05, h * 0.24, 62.0, 0x80CE7A),
            (w * 0.13, h * 0.20, 74.0, 0x95DC8B),
            (w * 0.20, h * 0.26, 56.0, 0x7BC974),
        ] as [(CGFloat, CGFloat, CGFloat, UInt32)] {
            StorybookArt.shape(ctx, Path(ellipseIn: CGRect(x: px - r, y: py - r * 0.78, width: r * 2, height: r * 1.56)), hex: col, width: 3.5)
        }
        // Little pink blossom clusters in the tree canopy
        for (bx, by) in [(w * 0.07, h * 0.22), (w * 0.14, h * 0.16), (w * 0.18, h * 0.25), (w * 0.11, h * 0.27)] as [(CGFloat, CGFloat)] {
            ctx.fill(DressUpCulturalOutfits.flowerPath(center: CGPoint(x: bx, y: by), radius: 13), with: .color(Color(hex: 0xFFC2DC)))
            ctx.fill(Path(ellipseIn: CGRect(x: bx - 4, y: by - 4, width: 8, height: 8)), with: .color(Color(hex: 0xFFE680)))
        }

        // Cozy cream picket garden fence across backyard
        let fenceY = h * 0.50
        let picketW: CGFloat = max(24, w / 34)
        for x in stride(from: CGFloat(0), to: w + picketW, by: picketW * 1.25) {
            let p = Path(roundedRect: CGRect(x: x, y: fenceY, width: picketW * 0.9, height: h * 0.14), cornerRadius: 6)
            StorybookArt.fillAndStroke(ctx, p, fill: Color(hex: 0xFFF7EA), stroke: Color(hex: 0xDFC7AA), width: 2.2)
        }
        let fenceRail = Path(roundedRect: CGRect(x: 0, y: fenceY + h * 0.04, width: w, height: 12), cornerRadius: 4)
        StorybookArt.fillAndStroke(ctx, fenceRail, fill: Color(hex: 0xFFFDF8), stroke: Color(hex: 0xDFC7AA), width: 2.2)

        // Warm honey-cedar timber veranda deck floor
        let deckY = h * 0.61
        let deckRect = CGRect(x: 0, y: deckY, width: w, height: h - deckY)
        ctx.fill(
            Path(deckRect),
            with: .linearGradient(
                Gradient(colors: [Color(hex: 0xF5C994), Color(hex: 0xE7B076)]),
                startPoint: CGPoint(x: 0, y: deckY),
                endPoint: CGPoint(x: 0, y: h)
            )
        )
        for row in 0..<7 {
            let py = deckY + CGFloat(row) * ((h - deckY) / 6.5)
            var plank = Path()
            plank.move(to: CGPoint(x: 0, y: py))
            plank.addLine(to: CGPoint(x: w, y: py))
            ctx.stroke(plank, with: .color(Color(hex: 0xC68B53).opacity(0.45)), style: StrokeStyle(lineWidth: 2.5))
        }

        // White veranda deck railing posts & rail
        let railTopY = deckY - h * 0.10
        let topBeam = Path(roundedRect: CGRect(x: 0, y: railTopY, width: w, height: 14), cornerRadius: 6)
        StorybookArt.fillAndStroke(ctx, topBeam, fill: Color(hex: 0xFFFDF9), stroke: Color(hex: 0xD8C2B0), width: 2.6)
        for i in 0...14 {
            let bx = CGFloat(i) * (w / 14)
            let baluster = Path(roundedRect: CGRect(x: bx - 5, y: railTopY + 12, width: 10, height: h * 0.10), cornerRadius: 4)
            StorybookArt.fillAndStroke(ctx, baluster, fill: Color(hex: 0xFFFBF3), stroke: Color(hex: 0xD8C2B0), width: 2)
        }

        // Festive pastel porch bunting flags overhead
        var stringPath = Path()
        stringPath.move(to: CGPoint(x: 0, y: h * 0.04))
        stringPath.addQuadCurve(to: CGPoint(x: w, y: h * 0.04), control: CGPoint(x: w * 0.5, y: h * 0.15))
        ctx.stroke(stringPath, with: .color(Color(hex: 0xC8A89A)), style: StrokeStyle(lineWidth: 2.5))
        let flagHexes: [UInt32] = [0xFF9EC0, 0xFFE38A, 0x9FE3CF, 0x9CCBFF, 0xD2C0FF]
        for i in 1..<11 {
            let u = CGFloat(i) / 11.0
            let fx = w * u
            let fy = h * 0.04 + 4 * u * (1 - u) * (h * 0.055)
            var flag = Path()
            flag.move(to: CGPoint(x: fx - 18, y: fy))
            flag.addLine(to: CGPoint(x: fx + 18, y: fy))
            flag.addLine(to: CGPoint(x: fx, y: fy + 34))
            flag.closeSubpath()
            StorybookArt.shape(ctx, flag, hex: flagHexes[i % flagHexes.count], width: 2.2)
        }

        // Cozy striped woven outdoor rug in the middle of the porch
        let rugRect = CGRect(x: w * 0.22, y: h * 0.72, width: w * 0.56, height: h * 0.20)
        StorybookArt.fillAndStroke(
            ctx,
            Path(ellipseIn: rugRect),
            fill: Color(hex: 0xFFF3E2),
            stroke: Color(hex: 0xE4A57B),
            width: 4
        )
        let innerRug = rugRect.insetBy(dx: 24, dy: 14)
        StorybookArt.fillAndStroke(
            ctx,
            Path(ellipseIn: innerRug),
            fill: Color(hex: 0xFFE0EC),
            stroke: Color(hex: 0xA8E8CF),
            width: 5
        )

        // Cute terracotta flower pots framing the deck corners
        for px in [w * 0.09, w * 0.91] as [CGFloat] {
            let pot = Path { p in
                p.move(to: CGPoint(x: px - 24, y: deckY - 12))
                p.addLine(to: CGPoint(x: px + 24, y: deckY - 12))
                p.addLine(to: CGPoint(x: px + 18, y: deckY + 24))
                p.addLine(to: CGPoint(x: px - 18, y: deckY + 24))
                p.closeSubpath()
            }
            StorybookArt.shape(ctx, pot, hex: 0xE68A66, width: 3)
            let bush = Path(ellipseIn: CGRect(x: px - 26, y: deckY - 40, width: 52, height: 34))
            StorybookArt.shape(ctx, bush, hex: 0x7ED389, width: 3)
            ctx.fill(DressUpCulturalOutfits.flowerPath(center: CGPoint(x: px - 8, y: deckY - 26), radius: 9), with: .color(.white))
            ctx.fill(DressUpCulturalOutfits.flowerPath(center: CGPoint(x: px + 10, y: deckY - 22), radius: 9), with: .color(Theme.lemon))
        }
    }

    private func drawSunnyLivingRoom(in ctx: GraphicsContext, size: CGSize) {
        let w = size.width, h = size.height

        // Creamy sunlit living room walls
        ctx.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .linearGradient(
                Gradient(colors: [Color(hex: 0xFFF7E9), Color(hex: 0xFFEEDB)]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: h * 0.65)
            )
        )

        // Soft cream wainscoting paneling on lower wall
        let wainscotY = h * 0.44
        ctx.fill(Path(CGRect(x: 0, y: wainscotY, width: w, height: h * 0.22)), with: .color(Color(hex: 0xFFFDF8)))
        var trim = Path()
        trim.move(to: CGPoint(x: 0, y: wainscotY))
        trim.addLine(to: CGPoint(x: w, y: wainscotY))
        ctx.stroke(trim, with: .color(Color(hex: 0xE2CBB2)), style: StrokeStyle(lineWidth: 5))

        // Big sunny bay window looking out onto the garden
        let winRect = CGRect(x: w * 0.28, y: h * 0.08, width: w * 0.44, height: h * 0.36)
        ctx.fill(
            Path(roundedRect: winRect, cornerRadius: 24),
            with: .linearGradient(
                Gradient(colors: [Color(hex: 0x99DCFF), Color(hex: 0xDCF5FF)]),
                startPoint: CGPoint(x: winRect.midX, y: winRect.minY),
                endPoint: CGPoint(x: winRect.midX, y: winRect.maxY)
            )
        )
        // Green tree & cloud glimpsed through the window
        var winCtx = ctx
        winCtx.clip(to: Path(roundedRect: winRect, cornerRadius: 24))
        winCtx.fill(Path(ellipseIn: CGRect(x: winRect.minX - 20, y: winRect.maxY - 68, width: 170, height: 110)), with: .color(Color(hex: 0x95DC8B)))
        winCtx.fill(Path(ellipseIn: CGRect(x: winRect.maxX - 130, y: winRect.maxY - 54, width: 160, height: 90)), with: .color(Color(hex: 0x82CE7C)))
        winCtx.fill(Path(ellipseIn: CGRect(x: winRect.midX - 40, y: winRect.minY + 26, width: 90, height: 34)), with: .color(.white.opacity(0.9)))

        ctx.stroke(Path(roundedRect: winRect, cornerRadius: 24), with: .color(.white), style: StrokeStyle(lineWidth: 10))
        ctx.stroke(Path(roundedRect: winRect, cornerRadius: 24), with: .color(Color(hex: 0xDBC5AE)), style: StrokeStyle(lineWidth: 3))
        var paneCross = Path()
        paneCross.move(to: CGPoint(x: winRect.midX, y: winRect.minY))
        paneCross.addLine(to: CGPoint(x: winRect.midX, y: winRect.maxY))
        paneCross.move(to: CGPoint(x: winRect.minX, y: winRect.midY))
        paneCross.addLine(to: CGPoint(x: winRect.maxX, y: winRect.midY))
        ctx.stroke(paneCross, with: .color(.white), style: StrokeStyle(lineWidth: 6))

        // Sheer pastel curtains flanking the window
        for side in [-1.0, 1.0] as [CGFloat] {
            let cx = side < 0 ? winRect.minX : winRect.maxX
            let drape = Path { p in
                p.move(to: CGPoint(x: cx - side * 14, y: winRect.minY - 8))
                p.addLine(to: CGPoint(x: cx + side * 48, y: winRect.minY - 8))
                p.addQuadCurve(to: CGPoint(x: cx + side * 34, y: winRect.maxY + 28), control: CGPoint(x: cx + side * 66, y: winRect.midY))
                p.addQuadCurve(to: CGPoint(x: cx - side * 8, y: winRect.maxY + 18), control: CGPoint(x: cx + side * 10, y: winRect.maxY + 32))
                p.closeSubpath()
            }
            StorybookArt.fillAndStroke(ctx, drape, fill: Color(hex: 0xFFE5EE, alpha: 0.9), stroke: Color(hex: 0xE6B0C6), width: 2.8)
        }

        // Warm honey timber floorboards
        let floorY = h * 0.62
        ctx.fill(
            Path(CGRect(x: 0, y: floorY, width: w, height: h - floorY)),
            with: .linearGradient(
                Gradient(colors: [Color(hex: 0xF4CFA0), Color(hex: 0xE5B682)]),
                startPoint: CGPoint(x: 0, y: floorY),
                endPoint: CGPoint(x: 0, y: h)
            )
        )
        for row in 0..<7 {
            let py = floorY + CGFloat(row) * ((h - floorY) / 6.5)
            var line = Path()
            line.move(to: CGPoint(x: 0, y: py))
            line.addLine(to: CGPoint(x: w, y: py))
            ctx.stroke(line, with: .color(Color(hex: 0xC68E58).opacity(0.38)), style: StrokeStyle(lineWidth: 2.5))
        }

        // Soft diagonal sunbeam falling across the living room floor
        var beam = Path()
        beam.move(to: CGPoint(x: winRect.minX + 18, y: winRect.maxY))
        beam.addLine(to: CGPoint(x: winRect.maxX - 18, y: winRect.maxY))
        beam.addLine(to: CGPoint(x: w * 0.84, y: h))
        beam.addLine(to: CGPoint(x: w * 0.22, y: h))
        beam.closeSubpath()
        ctx.fill(
            beam,
            with: .linearGradient(
                Gradient(colors: [Color(hex: 0xFFF7C4).opacity(0.36), Color(hex: 0xFFF7C4).opacity(0.06)]),
                startPoint: CGPoint(x: w * 0.5, y: winRect.maxY),
                endPoint: CGPoint(x: w * 0.5, y: h)
            )
        )

        // Cozy plush pastel sofa on the left-center
        let sofaRect = CGRect(x: w * 0.14, y: floorY - 92, width: w * 0.36, height: 96)
        StorybookArt.shape(ctx, Path(roundedRect: sofaRect, cornerRadius: 28), hex: 0xAED7FF, width: 3.5)
        let cushionRect = CGRect(x: sofaRect.minX + 18, y: sofaRect.midY - 8, width: sofaRect.width - 36, height: 48)
        StorybookArt.shape(ctx, Path(roundedRect: cushionRect, cornerRadius: 18), hex: 0xC9E6FF, width: 3)
        // Polka-dot throw cushions
        StorybookArt.shape(ctx, Path(roundedRect: CGRect(x: sofaRect.minX + 26, y: sofaRect.minY + 18, width: 48, height: 44), cornerRadius: 14), hex: 0xFFB6D2, width: 2.8)
        StorybookArt.shape(ctx, Path(roundedRect: CGRect(x: sofaRect.maxX - 74, y: sofaRect.minY + 18, width: 48, height: 44), cornerRadius: 14), hex: 0xFFE58A, width: 2.8)

        // Wooden playroom cubby shelf with stacked pastel blocks on the right
        let shelfRect = CGRect(x: w * 0.72, y: floorY - 88, width: w * 0.19, height: 92)
        StorybookArt.shape(ctx, Path(roundedRect: shelfRect, cornerRadius: 14), hex: 0xE6B98A, width: 3.2)
        let blockColors: [UInt32] = [0xFF9EC0, 0xFFE38A, 0x9FE3CF]
        for (i, hex) in blockColors.enumerated() {
            let b = CGRect(x: shelfRect.minX + 18 + CGFloat(i) * 38, y: shelfRect.minY - 26, width: 30, height: 26)
            StorybookArt.shape(ctx, Path(roundedRect: b, cornerRadius: 6), hex: hex, width: 2.5)
        }

        // Round braided sunny playroom rug
        let rug = CGRect(x: w * 0.20, y: h * 0.72, width: w * 0.60, height: h * 0.21)
        StorybookArt.fillAndStroke(ctx, Path(ellipseIn: rug), fill: Color(hex: 0xFFECC6), stroke: Color(hex: 0xF5A882), width: 5)
        StorybookArt.fillAndStroke(ctx, Path(ellipseIn: rug.insetBy(dx: 28, dy: 14)), fill: Color(hex: 0xFFF8E8), stroke: Color(hex: 0x9FE3CF), width: 4)
    }
}

// MARK: - Toy Art Painters (Keepy Uppy Balloon, Picnic Basket, Tea Party Treats, Particles)

enum PlayhouseBalloonPainter {
    static func draw(balloon b: KeepyUppyBalloon, scale: CGFloat, in ctx: GraphicsContext) {
        var g = ctx
        g.translateBy(x: b.x, y: b.y)
        g.scaleBy(x: scale / sqrt(b.squash), y: scale * b.squash)

        // Curly wavy ribbon string
        var str = Path()
        str.move(to: CGPoint(x: 0, y: 46))
        let sway = CGFloat(sin(b.phase * 4)) * 10
        str.addCurve(
            to: CGPoint(x: sway, y: 112),
            control1: CGPoint(x: -14 + sway * 0.5, y: 68),
            control2: CGPoint(x: 16 - sway * 0.5, y: 92)
        )
        g.stroke(str, with: .color(.white.opacity(0.9)), style: StrokeStyle(lineWidth: 3, lineCap: .round))

        // Balloon knot
        var knot = Path()
        knot.move(to: CGPoint(x: -6, y: 46))
        knot.addLine(to: CGPoint(x: 6, y: 46))
        knot.addLine(to: CGPoint(x: 0, y: 38))
        knot.closeSubpath()
        StorybookArt.shape(g, knot, hex: b.colorHex, width: 2.5)

        // Plump bouncy pastel balloon body
        let body = Path(ellipseIn: CGRect(x: -36, y: -44, width: 72, height: 86))
        let fill = StorybookArt.color(b.colorHex)
        let light = StorybookArt.tint(for: b.colorHex, amount: 0.48)
        g.fill(
            body,
            with: .radialGradient(
                Gradient(colors: [light, fill]),
                center: CGPoint(x: -12, y: -16),
                startRadius: 4,
                endRadius: 56
            )
        )
        g.stroke(body, with: .color(StorybookArt.outline(for: b.colorHex)), style: StrokeStyle(lineWidth: 3.5))

        // Glossy specular highlight
        let shine = Path(ellipseIn: CGRect(x: -22, y: -28, width: 15, height: 24))
        var sg = g
        sg.rotate(by: .degrees(-18))
        sg.fill(shine, with: .color(.white.opacity(0.65)))
    }

    static func drawIcon(in ctx: GraphicsContext, size: CGSize) {
        let s = min(size.width, size.height) / 100
        let sample = KeepyUppyBalloon(x: size.width / 2, y: size.height * 0.44, vx: 0, vy: 0, colorIndex: 0)
        draw(balloon: sample, scale: s * 0.72, in: ctx)
    }
}

private enum PicnicBasketIconPainter {
    static func draw(in ctx: GraphicsContext, size: CGSize) {
        let s = min(size.width, size.height) / 100
        var g = ctx
        g.translateBy(x: size.width / 2, y: size.height / 2 + 4 * s)
        g.scaleBy(x: s, y: s)

        // Basket handle
        var handle = Path()
        handle.addArc(center: CGPoint(x: 0, y: -8), radius: 22, startAngle: .degrees(190), endAngle: .degrees(350), clockwise: false)
        g.stroke(handle, with: .color(StorybookArt.outline(for: 0xD69454)), style: StrokeStyle(lineWidth: 8, lineCap: .round))
        g.stroke(handle, with: .color(StorybookArt.color(0xF0BC7A)), style: StrokeStyle(lineWidth: 4, lineCap: .round))

        // Checkered picnic cloth peeking out
        let cloth = Path(roundedRect: CGRect(x: -28, y: -12, width: 56, height: 14), cornerRadius: 6)
        StorybookArt.shape(g, cloth, hex: 0xFF9EC0, width: 2.5)

        // Woven basket body
        var body = Path()
        body.move(to: CGPoint(x: -30, y: -4))
        body.addLine(to: CGPoint(x: 30, y: -4))
        body.addLine(to: CGPoint(x: 22, y: 26))
        body.addLine(to: CGPoint(x: -22, y: 26))
        body.closeSubpath()
        StorybookArt.shape(g, body, hex: 0xE8AF6A, width: 3)

        for x in [-12.0, 0.0, 12.0] as [CGFloat] {
            var v = Path()
            v.move(to: CGPoint(x: x, y: -2))
            v.addLine(to: CGPoint(x: x * 0.8, y: 24))
            g.stroke(v, with: .color(StorybookArt.outline(for: 0xD69454).opacity(0.6)), style: StrokeStyle(lineWidth: 2))
        }
    }
}

private struct ToyCircleIcon<Content: View>: View {
    let tint: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(6)
            .frame(width: GameChromeLayout.buttonSize, height: GameChromeLayout.buttonSize)
            .background(Circle().fill(.white))
            .overlay(Circle().stroke(tint.opacity(0.55), lineWidth: 4))
            .shadow(color: Theme.ink.opacity(0.22), radius: 6, y: 4)
    }
}

struct TeaTreatArtView: View {
    let kind: TeaTreatKind
    let bitesLeft: Int

    var body: some View {
        Canvas { ctx, size in
            let s = min(size.width, size.height) / 100
            var g = ctx
            g.translateBy(x: size.width / 2, y: size.height / 2)
            g.scaleBy(x: s, y: s)

            // Cute porcelain saucer underneath
            let plate = Path(ellipseIn: CGRect(x: -42, y: 18, width: 84, height: 22))
            StorybookArt.fillAndStroke(g, plate, fill: .white, stroke: Color(hex: 0xE6C6D8), width: 3)

            g.drawLayer { l in
                switch kind {
                case .strawberryCake:
                    drawStrawberryCake(in: l)
                case .bungeoppang:
                    drawBungeoppang(in: l)
                case .cupcake:
                    drawCupcake(in: l)
                case .teapot:
                    drawTeapot(in: l)
                }

                // Show playful bite scallop after nibbles without punching through the background.
                if !kind.isDrink && bitesLeft < 3 {
                    let bite = Path(ellipseIn: CGRect(x: 10, y: -14, width: CGFloat(3 - bitesLeft) * 14, height: CGFloat(3 - bitesLeft) * 14))
                    l.blendMode = .destinationOut
                    l.fill(bite, with: .color(.white))
                }
            }
        }
    }

    private func drawStrawberryCake(in g: GraphicsContext) {
        // Korean café white whipped cream sponge slice
        let cake = Path(roundedRect: CGRect(x: -30, y: -16, width: 60, height: 42), cornerRadius: 8)
        StorybookArt.fillAndStroke(g, cake, fill: Color(hex: 0xFFFDF8), stroke: Color(hex: 0xDEBDC8), width: 3)
        // Sponge & berry jam middle layers
        g.fill(Path(CGRect(x: -28, y: -2, width: 56, height: 7)), with: .color(Color(hex: 0xFFE4A8)))
        g.fill(Path(CGRect(x: -28, y: 7, width: 56, height: 8)), with: .color(Color(hex: 0xFF84A6)))
        g.fill(Path(CGRect(x: -28, y: 16, width: 56, height: 7)), with: .color(Color(hex: 0xFFE4A8)))
        // Whipped cream cloud + juicy red strawberry on top
        let dollop = Path(ellipseIn: CGRect(x: -16, y: -26, width: 32, height: 18))
        StorybookArt.fillAndStroke(g, dollop, fill: .white, stroke: Color(hex: 0xE5CCD6), width: 2.5)
        let berry = DressUpCulturalOutfits.heartPath(center: CGPoint(x: 0, y: -26), halfWidth: 11)
        StorybookArt.shape(g, berry, hex: 0xF24E6C, width: 2.4)
        let leaf = Path(ellipseIn: CGRect(x: 4, y: -38, width: 12, height: 6))
        StorybookArt.shape(g, leaf, hex: 0x70D488, width: 2)
    }

    private func drawBungeoppang(in g: GraphicsContext) {
        // Warm golden Korean fish-shaped pastry
        let tail = Path { p in
            p.move(to: CGPoint(x: 20, y: 2))
            p.addLine(to: CGPoint(x: 38, y: -12))
            p.addQuadCurve(to: CGPoint(x: 38, y: 16), control: CGPoint(x: 32, y: 2))
            p.closeSubpath()
        }
        StorybookArt.shape(g, tail, hex: 0xE8A85A, width: 3)

        let fish = Path(ellipseIn: CGRect(x: -34, y: -18, width: 60, height: 40))
        StorybookArt.shape(g, fish, hex: 0xF2BA6C, width: 3.2)

        // Cute toasted waffle scale arcs & tiny happy eye
        for sx in [-8.0, 2.0, 12.0] as [CGFloat] {
            var scale = Path()
            scale.addArc(center: CGPoint(x: sx, y: 2), radius: 7, startAngle: .degrees(-65), endAngle: .degrees(65), clockwise: false)
            g.stroke(scale, with: .color(StorybookArt.outline(for: 0xD68D3E)), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
        }
        g.fill(Path(ellipseIn: CGRect(x: -23, y: -4, width: 6, height: 6)), with: .color(StorybookArt.outline(for: 0xB87330)))
        StorybookArt.highlight(g, in: CGRect(x: -22, y: -12, width: 24, height: 7), opacity: 0.4)
    }

    private func drawCupcake(in g: GraphicsContext) {
        var cup = Path()
        cup.move(to: CGPoint(x: -24, y: 2))
        cup.addLine(to: CGPoint(x: 24, y: 2))
        cup.addLine(to: CGPoint(x: 18, y: 28))
        cup.addLine(to: CGPoint(x: -18, y: 28))
        cup.closeSubpath()
        StorybookArt.shape(g, cup, hex: 0x9CCBFF, width: 3)

        let swirl1 = Path(ellipseIn: CGRect(x: -28, y: -14, width: 56, height: 24))
        let swirl2 = Path(ellipseIn: CGRect(x: -20, y: -26, width: 40, height: 20))
        StorybookArt.shape(g, swirl1, hex: 0xFFA4C8, width: 3)
        StorybookArt.shape(g, swirl2, hex: 0xFFC2DC, width: 2.8)
        StorybookArt.shape(g, Path(ellipseIn: CGRect(x: -7, y: -36, width: 14, height: 14)), hex: 0xF24E6C, width: 2.4)
        for (sx, sy, col) in [(-12.0, -8.0, Theme.lemon), (10.0, -6.0, Theme.mint), (0.0, -16.0, .white)] as [(CGFloat, CGFloat, Color)] {
            g.fill(Path(ellipseIn: CGRect(x: sx - 3, y: sy - 2, width: 6, height: 4)), with: .color(col))
        }
    }

    private func drawTeapot(in g: GraphicsContext) {
        // Spout & handle
        var spout = Path()
        spout.move(to: CGPoint(x: -24, y: 8))
        spout.addQuadCurve(to: CGPoint(x: -40, y: -14), control: CGPoint(x: -36, y: 4))
        g.stroke(spout, with: .color(StorybookArt.outline(for: 0xC9B6FF)), style: StrokeStyle(lineWidth: 11, lineCap: .round))
        g.stroke(spout, with: .color(StorybookArt.color(0xD8C6FF)), style: StrokeStyle(lineWidth: 6, lineCap: .round))

        var handle = Path()
        handle.addArc(center: CGPoint(x: 24, y: 2), radius: 13, startAngle: .degrees(-70), endAngle: .degrees(80), clockwise: false)
        g.stroke(handle, with: .color(StorybookArt.outline(for: 0xC9B6FF)), style: StrokeStyle(lineWidth: 9, lineCap: .round))
        g.stroke(handle, with: .color(StorybookArt.color(0xD8C6FF)), style: StrokeStyle(lineWidth: 4.5, lineCap: .round))

        // Rounded porcelain body & lid
        let body = Path(ellipseIn: CGRect(x: -28, y: -16, width: 56, height: 44))
        StorybookArt.shape(g, body, hex: 0xD8C6FF, width: 3.2)
        let lid = Path(ellipseIn: CGRect(x: -18, y: -24, width: 36, height: 14))
        StorybookArt.shape(g, lid, hex: 0xFFB8D4, width: 2.6)
        StorybookArt.shape(g, Path(ellipseIn: CGRect(x: -5, y: -30, width: 10, height: 10)), hex: 0xFFE378, width: 2)
        StorybookArt.heart(g, at: CGPoint(x: 0, y: 6), size: 16, color: .white, opacity: 0.9)
    }
}

private enum PlayhouseParticlePainter {
    static func draw(_ particles: [PlayhouseParticle], in ctx: GraphicsContext, size: CGSize) {
        for p in particles {
            let fade = max(0, 1 - p.age / max(0.01, p.life))
            var g = ctx
            g.opacity = fade
            g.translateBy(x: p.x, y: p.y)
            g.rotate(by: .degrees(p.spin * p.age))
            switch p.kind {
            case .sparkle:
                StorybookArt.sparkle(g, at: .zero, radius: p.size * 0.7, color: p.color, opacity: 1)
            case .heart:
                StorybookArt.heart(g, at: .zero, size: p.size * 1.4, color: p.color, opacity: 1)
            case .note:
                let note = Path(ellipseIn: CGRect(x: -p.size * 0.45, y: 0, width: p.size * 0.6, height: p.size * 0.45))
                g.fill(note, with: .color(p.color))
                var stem = Path()
                stem.move(to: CGPoint(x: p.size * 0.1, y: p.size * 0.15))
                stem.addLine(to: CGPoint(x: p.size * 0.1, y: -p.size * 0.85))
                stem.addQuadCurve(to: CGPoint(x: p.size * 0.65, y: -p.size * 0.55), control: CGPoint(x: p.size * 0.5, y: -p.size * 0.9))
                g.stroke(stem, with: .color(p.color), style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
            case .crumb:
                g.fill(Path(ellipseIn: CGRect(x: -p.size / 2, y: -p.size / 2, width: p.size, height: p.size)), with: .color(Color(hex: 0xF5C97B)))
            case .confetti:
                let rect = CGRect(x: -p.size * 0.6, y: -p.size * 0.35, width: p.size * 1.2, height: p.size * 0.7)
                g.fill(Path(roundedRect: rect, cornerRadius: 2.5), with: .color(p.color))
            }
        }
    }
}
