import SwiftUI

// MARK: - The aquarium, simulated
//
// Fish steer like real fish: each has a place it is heading for (a wander point, the nearest flake of food, the spot
// where her finger rests on the glass) and turns its velocity toward it with limited acceleration, keeping its distance
// from the others; tetras and guppies school. They swim mostly level, beat their tails faster the harder they push,
// and turn round through a narrow side view. A tap on the glass startles the fish near it, and a moment later they come
// back to look.
//
// The water is a row of springy surface nodes (waves spread and die out), plus drag and buoyancy for everything in it:
// food flakes float a moment and then flutter down, decorations sink at their own speed and thump into the sand in a
// puff, bubbles rise faster the bigger they are, wobble, and pop at the surface in a little ripple.
//
// The front glass collects algae slowly, as a grid of cells; the sponge rubs it off and the snail grazes on it.

enum AquaTool: Equatable {
    case food, sponge, net
    case fish(FishKind)
    case decor(AquaDecorKind)
}

struct AquaFish {
    var id: Int
    var kind: FishKind
    var variant: Int
    var p: CGPoint
    var v: CGVector = .zero
    /// Drawn x scale, -1 ... 1: a turn passes through a narrow side view.
    var facing: CGFloat = 1
    /// The way it wants to face, -1 or 1.
    var dir: CGFloat = 1
    var phase: CGFloat = 0
    /// How hard the tail beats (radians).
    var amp: CGFloat = 0.2
    var accel: CGFloat = 0
    /// 0 at the back of the tank ... 1 at the front glass: nearer fish are drawn a little bigger and on top.
    var z: CGFloat = 0.5
    var zTarget: CGFloat = 0.5
    var target: CGPoint
    var nextThink: Double = 0
    var fleeUntil: Double = -10
    var flee: CGVector = .zero
    var curious: CGPoint?
    var curiousUntil: Double = -10
    var appetite: CGFloat = 5
    var gulp: CGFloat = 0
    var happy: Double = -10
    var puff: CGFloat = 0
    var puffV: CGFloat = 0
    var puffUntil: Double = -10
    var restUntil: Double = -10
    var nextBubble: Double = 0
    var caught = false

    var scale: CGFloat { 0.8 + 0.22 * z }
}

enum FoodState { case air, floating, sinking, settled }

struct AquaFood {
    var p: CGPoint
    var v: CGVector
    var state: FoodState = .air
    var age: CGFloat = 0
    var floatFor: CGFloat
    var hue: Int
    var rot: CGFloat
    var spin: CGFloat
    var seed: CGFloat
}

struct AquaBubble {
    var p: CGPoint
    var r: CGFloat
    var vy: CGFloat = 0
    var phase: CGFloat
    /// Behind the fish (the pump at the back) or in front.
    var back = false
}

enum AquaPart { case splash, sand, heart, sparkle, ring, algae, glow, poof }

struct AquaParticle {
    var kind: AquaPart
    var p: CGPoint
    var v: CGVector
    var age: CGFloat = 0
    var life: CGFloat
    var size: CGFloat
    var color: ARGB
}

struct AquaDecor {
    var id: Int
    var kind: AquaDecorKind
    var x: CGFloat
    /// The bottom of the drawing (it rests on the sand there).
    var y: CGFloat
    var vx: CGFloat = 0
    var vy: CGFloat = 0
    var rot: CGFloat = 0
    var rotV: CGFloat = 0
    var falling = false
    var wet = true
    var held = false
    var squash: CGFloat = 0
    var squashV: CGFloat = 0
    var sway: CGFloat = 0
    var swayV: CGFloat = 0
    /// The chest lid, 0 shut ... 1 open.
    var open: CGFloat = 0
    var openUntil: Double = -10
    var nextPuff: Double = 0
    var flip = false
    var poke: Double = -10
}

struct AquaSnail {
    var p: CGPoint
    var heading: CGFloat
    var target: CGPoint
    var hide: CGFloat = 0
    var hideUntil: Double = -10
    var phase: CGFloat = 0
}

final class AquariumSim {
    static let gameID = "aquarium"
    static let gravity: CGFloat = 1600
    static let maxFish = 24

    var reefStarted = false
    var eelSpine: [CGPoint] = []
    var fish: [AquaFish] = []
    private(set) var huntKind: FishKind?
    private(set) var fishFound = 0
    static let huntGoal = 3

    func startFishHunt() {
        fishFound = 0
        chooseHuntFish()
    }

    func stopFishHunt() { huntKind = nil }

    private func chooseHuntFish() {
        let present = FishKind.allCases.filter { kind in fish.contains { $0.kind == kind && !$0.caught } }
        huntKind = present.filter { $0 != huntKind }.randomElement() ?? present.first
    }

    private func findFish(_ index: Int) {
        guard fish[index].kind == huntKind else { return }
        fishFound += 1
        if fishFound == Self.huntGoal {
            huntKind = nil
            for k in 0..<12 {
                let x = fish[index].p.x + CGFloat(k - 6) * 8
                addFlake(at: CGPoint(x: x, y: surfaceY(x) - 12), v: .zero)
            }
            AquaSound.shared.play(.chime)
        } else {
            chooseHuntFish()
        }
    }
    var food: [AquaFood] = []
    var bubbles: [AquaBubble] = []
    var particles: [AquaParticle] = []
    var decor: [AquaDecor] = []
    var snail: AquaSnail
    var algae: [CGFloat]
    /// Surface heights (down is +) and speeds per node.
    var sh: [CGFloat]
    var sv: [CGFloat]

    var lightsOn = true
    var pump = true
    var night: CGFloat = 0
    var time: Double = 0
    var demo = false
    var lastFed: Double = 0
    /// Animals dropping in, and a pearl in the open chest (see AquariumFinds).
    var visitors: [AVisitor] = []
    var nextVisit: Double = 8
    var pearl: (id: Int, until: Double)?
    private var last: Date?
    private var lastSave: Double = 0
    private var nextID = 1
    private var algaeTick: Double = 0
    private var wasDirty = false

    // The carried tool
    var tool: AquaTool?
    var toolP = CGPoint.zero
    var finger = CGPoint.zero
    /// Her real finger while she carries a tool.
    var hold = CGPoint.zero
    var toolV = CGVector.zero
    var tilt: CGFloat = 0
    var tiltV: CGFloat = 0
    var shake: CGFloat = 0
    var caught: Int?
    private var lastToolV = CGVector.zero
    private var foodAcc: CGFloat = 0
    private var squeakAt: Double = 0
    /// A tool flying back to its place on the dock.
    var returning: (tool: AquaTool, from: CGPoint, to: CGPoint, start: Double, tilt: CGFloat)?

    // The bare hand
    private enum Grab {
        case none
        case decor(id: Int)
        case maybeDecor(id: Int)
        case surface
        case water
    }
    private var grab: Grab = .none
    var hand: CGPoint?
    private var handStart: Double = 0
    private var handStartP = CGPoint.zero
    private var handStill: Double = 0
    private var handV = CGVector.zero
    var decorTarget = CGPoint.zero

    // Drawing caches
    private(set) var algaeVersion = 0
    private var algaeDirty = true
    private var algaeBuilt: Double = -1
    private var algaeCache: [Path] = [Path(), Path(), Path()]

    init(save: AquaSave? = AquaStorage.load()) {
        let n = AGeo.algaeCols * AGeo.algaeRows
        algae = [CGFloat](repeating: 0, count: n)
        sh = [CGFloat](repeating: 0, count: AGeo.surfaceNodes)
        sv = [CGFloat](repeating: 0, count: AGeo.surfaceNodes)
        snail = AquaSnail(p: CGPoint(x: 880, y: 560), heading: .pi, target: CGPoint(x: 700, y: 520))
        if let s = save, s.algae.count == n {
            restore(s)
        } else {
            starterTank()
        }
    }

    private func starterTank() {
        addDecor(.seaweed, x: 120)
        addDecor(.castle, x: 300)
        addDecor(.grass, x: 470)
        addDecor(.starfish, x: 560)
        addDecor(.chest, x: 680)
        addDecor(.coral, x: 830)
        addDecor(.shell, x: 930)
        addDecor(.bubbler, x: 220)
        spawn(.goldfish, variant: 0)
        spawn(.clownfish, variant: 0)
        for _ in 0..<5 { spawn(.tetra, variant: 0) }
        spawn(.puffer, variant: 0)
        // a little algae in the bottom corners, so the sponge has something to do
        for r in 0..<AGeo.algaeRows {
            for c in 0..<AGeo.algaeCols {
                let edge = min(1, min(CGFloat(c), CGFloat(AGeo.algaeCols - 1 - c)) / 6)
                let low = CGFloat(r) / CGFloat(AGeo.algaeRows - 1)
                algae[r * AGeo.algaeCols + c] = edge < 1 ? aqClamp((1 - edge) * low * (0.6 + 0.5 * aqRand(c * 31 + r, 5))) : 0
            }
        }
    }

    private func restore(_ s: AquaSave) {
        for f in s.fish { spawn(f.kind, variant: f.variant) }
        for d in s.decor {
            let i = addDecor(d.kind, x: d.x)
            decor[i].flip = d.flip
        }
        algae = s.algae.map { CGFloat($0) }
        lightsOn = !s.night
        night = s.night ? 1 : 0
        pump = s.pump
        reefStarted = s.reefStarted ?? false
        for i in decor.indices where decor[i].kind == .slate && s.decor[i].supported == true {
            if let seat = bridge(at: decor[i].x) { decor[i].y = seat.y }
        }
    }

    func makeSave() -> AquaSave {
        AquaSave(fish: fish.map { AquaFishSave(kind: $0.kind, variant: $0.variant) },
                 decor: decor.filter { !$0.held }.map { AquaDecorSave(kind: $0.kind, x: $0.x, flip: $0.flip,
                     supported: $0.kind == .slate ? (!$0.falling && $0.y < AGeo.sand($0.x)-35) : nil) },
                 algae: algae.map { Float($0) }, night: !lightsOn, pump: pump, reefStarted: reefStarted)
    }

    func save() {
        guard !demo else { return }
        AquaStorage.save(makeSave())
    }

    // MARK: Fish

    /// Puts a fish somewhere in its favorite part of the water (for starting up and loading).
    @discardableResult
    func spawn(_ kind: FishKind, variant: Int, at p: CGPoint? = nil) -> Int {
        let s: CGFloat = 0.9
        let half = (kind.length + kind.tailLength) * 0.5 * s
        let lim = AGeo.swim(half: half)
        let x = p?.x ?? CGFloat.random(in: lim.minX...lim.maxX)
        let y = p?.y ?? randomDepth(kind, x: x)
        // a rare colorway keeps its mark (see AquaRare)
        let rare = variant >= AquaRare.variant ? AquaRare.variant : 0
        var f = AquaFish(id: nextID, kind: kind, variant: rare + (variant - rare) % max(1, kind.variants), p: CGPoint(x: x, y: y),
                         target: CGPoint(x: x, y: y))
        nextID += 1
        f.dir = Bool.random() ? 1 : -1
        f.facing = f.dir
        f.phase = CGFloat.random(in: 0...6)
        f.z = CGFloat.random(in: 0.1...0.95)
        f.zTarget = f.z
        f.nextBubble = time + Double.random(in: 3...12)
        fish.append(f)
        return fish.count - 1
    }

    private func randomDepth(_ kind: FishKind, x: CGFloat) -> CGFloat {
        let top = AGeo.waterY + 30
        let bottom = AGeo.sand(x) - kind.height * 0.5 - 20
        let d = CGFloat.random(in: kind.depth)
        return top + (bottom - top) * d
    }

    /// A bag of fish poured in at x: they splash in at the surface and dive.
    func addFish(_ kind: FishKind, x: CGFloat, y: CGFloat) {
        let n = kind.group
        while fish.count + n > AquariumSim.maxFish, let j = fish.firstIndex(where: { !$0.caught }) {
            bye(fish[j].p)
            fish.remove(at: j)
        }
        let cx = max(AGeo.left + 70, min(AGeo.right - 70, x))
        let above = y < surfaceY(cx)
        let y0 = above ? surfaceY(cx) + 8 : min(y, AGeo.sand(cx) - 40)
        let v = AquariumSim.rollVariant((nextID * 7) % max(1, kind.variants))
        for k in 0..<n {
            let i = spawn(kind, variant: v, at: CGPoint(x: cx + CGFloat(k) * 14 - CGFloat(n - 1) * 7, y: y0 + CGFloat(k % 2) * 6))
            fish[i].v = CGVector(dx: CGFloat.random(in: -60...60), dy: above ? CGFloat.random(in: 140...220) : 40)
            fish[i].target = CGPoint(x: cx + CGFloat.random(in: -160...160), y: randomDepth(kind, x: cx))
            fish[i].nextThink = time + 2
        }
        if above {
            splash(at: cx, strength: 1)
        } else {
            AquaSound.shared.play(.blub, volume: 0.6)
        }
        for _ in 0..<10 { addBubble(CGPoint(x: cx + CGFloat.random(in: -24...24), y: y0 + CGFloat.random(in: 0...50)), r: CGFloat.random(in: 2...6)) }
    }

    private func stepFish(_ dt: CGFloat) {
        let sleepy = 1 - 0.45 * night
        for i in fish.indices {
            if fish[i].caught {
                fish[i].phase += dt * 2 * .pi * 4.5
                fish[i].amp = 0.45
                continue
            }
            var f = fish[i]
            let k = f.kind
            let s = f.scale
            let half = (k.length * 0.5 + k.tailLength * 0.4) * s
            let lim = AGeo.swim(half: half)
            let floorY = AGeo.sand(f.p.x) - k.height * 0.5 * s - (k == .seahorse ? 6 : 12)
            var speed = k.cruise * sleepy
            var goal = f.target
            var urgent = false
            var feeding = false

            if f.appetite >= 1, let j = nearestFood(to: f.p, within: k == .seahorse ? 240 : 460) {
                goal = food[j].p
                speed = min(k.topSpeed, k.cruise * 2.6 + 30)
                urgent = true
                feeding = true
            } else if time < f.fleeUntil {
                goal = CGPoint(x: f.p.x + f.flee.dx * 240, y: f.p.y + f.flee.dy * 120)
                speed = k.topSpeed
                urgent = true
            } else if let c = f.curious, time < f.curiousUntil {
                // come and look, each from its own side
                let a = CGFloat(f.id) * 2.4
                goal = CGPoint(x: c.x + cos(a) * (48 + CGFloat(f.id % 3) * 18), y: c.y + sin(a) * 30)
                speed = k.cruise * 1.3
                if hypot(goal.x - f.p.x, goal.y - f.p.y) < 30 {
                    f.gulp = max(f.gulp, 0.5 + 0.5 * sin(CGFloat(time) * 9 + CGFloat(f.id)))
                    if k == .seahorse || k == .puffer { f.dir = c.x > f.p.x ? 1 : -1 }
                }
            } else if k == .clownfish, let home = decor.last(where: { $0.kind == .anemone && !$0.held }) {
                let peek = sin(CGFloat(time)*0.9+CGFloat(f.id))
                goal = CGPoint(x:home.x+37*peek,y:home.y-49-13*peek)
                speed = k.cruise*1.65
            } else {
                f.curious = nil
                if time > f.nextThink || hypot(goal.x - f.p.x, goal.y - f.p.y) < 24 {
                    f.target = pickTarget(f)
                    f.nextThink = time + Double.random(in: 3...8)
                    f.zTarget = CGFloat.random(in: 0.05...1)
                    goal = f.target
                }
                if time < f.restUntil { speed = 0 }
            }

            // Steering: head for the goal, slowing down as it gets there.
            var dx = goal.x - f.p.x
            var dy = goal.y - f.p.y
            let dist = max(1, hypot(dx, dy))
            let arrive = urgent ? 1 : min(1, dist / 90)
            dx = dx / dist * speed * arrive
            dy = dy / dist * speed * arrive * (k == .seahorse ? 1 : 0.6)

            // Keep a little room from the others; schools hold together and swim the same way.
            var cx: CGFloat = 0, cy: CGFloat = 0, ax: CGFloat = 0, ay: CGFloat = 0, n: CGFloat = 0
            for j in fish.indices where j != i && !fish[j].caught {
                let o = fish[j]
                let ox = f.p.x - o.p.x, oy = f.p.y - o.p.y
                let d = hypot(ox, oy)
                let room = (k.length + o.kind.length) * 0.42 * s
                if d < room, d > 0.01 {
                    let push = (1 - d / room) * speed * 1.1
                    dx += ox / d * push
                    dy += oy / d * push * 0.7
                }
                if k.schools && o.kind == k && d < 220 {
                    cx += o.p.x; cy += o.p.y; ax += o.v.dx; ay += o.v.dy; n += 1
                }
            }
            if n > 0 && !urgent {
                dx += ((cx / n - f.p.x) * 0.5 + (ax / n - f.v.dx) * 0.6)
                dy += ((cy / n - f.p.y) * 0.4 + (ay / n - f.v.dy) * 0.4)
            }
            if k.schools {
                for stone in decor where stone.kind == .pillar || stone.kind == .slate {
                    let rx = stone.kind.size.width/2+18, ry = stone.kind.size.height/2+13
                    let ox = (f.p.x-stone.x)/rx, oy = (f.p.y-stone.y+stone.kind.size.height/2)/ry
                    let radial = hypot(ox,oy)
                    if radial < 1.45 {
                        dx += ox*(1.45-radial)*speed
                        dy += oy*(1.45-radial)*speed*2
                    }
                }
            }
            // Turn before the glass, not into it.
            let edge: CGFloat = 70
            if f.p.x < lim.minX + edge { dx += (lim.minX + edge - f.p.x) * 2.2 }
            if f.p.x > lim.maxX - edge { dx -= (f.p.x - (lim.maxX - edge)) * 2.2 }
            // (going for food it may come right up under the surface)
            let topY = feeding ? AGeo.waterY + k.height * 0.3 * s + 2 : lim.minY
            if !feeding && f.p.y < lim.minY + 30 { dy += (lim.minY + 30 - f.p.y) * 2 }
            if f.p.y > floorY - 30 { dy -= (f.p.y - (floorY - 30)) * 2 }

            // Limited acceleration: fish glide and bank, they don't jerk.
            let maxA = (urgent ? 2.6 : 1.4) * k.topSpeed + 60
            var sx = (dx - f.v.dx) * 3, sy = (dy - f.v.dy) * 3
            let sa = hypot(sx, sy)
            if sa > maxA { sx *= maxA / sa; sy *= maxA / sa }
            f.v.dx += sx * dt
            f.v.dy += sy * dt
            f.accel += (min(sa, maxA) - f.accel) * min(1, dt * 6)
            let sp = hypot(f.v.dx, f.v.dy)
            let cap = k.topSpeed * (f.puff > 0.5 ? 0.35 : 1)
            if sp > cap { f.v.dx *= cap / sp; f.v.dy *= cap / sp }
            // water drag
            let drag = exp(-dt * 0.6)
            f.v.dx *= drag
            f.v.dy *= drag
            f.p.x += f.v.dx * dt
            f.p.y += f.v.dy * dt
            if f.p.x < lim.minX { f.p.x = lim.minX; f.v.dx = abs(f.v.dx) * 0.3 }
            if f.p.x > lim.maxX { f.p.x = lim.maxX; f.v.dx = -abs(f.v.dx) * 0.3 }
            if f.p.y < topY { f.p.y = topY; f.v.dy = abs(f.v.dy) * 0.3 }
            if f.p.y > floorY { f.p.y = floorY; f.v.dy = -abs(f.v.dy) * 0.3 }

            // Turning round: it faces the way it swims (a resting fish keeps its side).
            if f.v.dx > 9 { f.dir = 1 } else if f.v.dx < -9 { f.dir = -1 }
            f.facing += (f.dir - f.facing) * min(1, dt * (urgent ? 9 : 5.5))
            // Tail beat: faster and wider when it pushes harder.
            let speedNow = hypot(f.v.dx, f.v.dy)
            let hz = (k == .seahorse ? 5 : 1.4) + speedNow * 0.02 + f.accel * 0.002
            f.phase += 2 * .pi * hz * dt
            let wantAmp = (k == .seahorse ? 0.3 : 0.13) + min(0.42, speedNow * 0.0012 + f.accel * 0.0011)
            f.amp += (wantAmp - f.amp) * min(1, dt * 4)
            f.z += (f.zTarget - f.z) * min(1, dt * 0.25)
            f.gulp = max(0, f.gulp - dt * 3)
            if f.appetite < 5 { f.appetite = min(5, f.appetite + dt / 9) }

            // The puffer puffs up when surprised and slowly lets the water out again.
            let puffWant: CGFloat = time < f.puffUntil ? 1 : 0
            f.puffV += ((puffWant - f.puff) * 90 - f.puffV * 9) * dt
            f.puff = max(0, min(1.12, f.puff + f.puffV * dt))

            // A fish now and then lets a tiny bubble go.
            if time > f.nextBubble {
                f.nextBubble = time + Double.random(in: 5...14)
                addBubble(mouth(f), r: CGFloat.random(in: 1.5...3))
            }
            fish[i] = f
            if feeding { eat(i) }
        }
    }

    private func pickTarget(_ f: AquaFish) -> CGPoint {
        let k = f.kind
        // The seahorse likes to hold on to a plant with its tail.
        if k == .seahorse, Bool.random(), let w = decor.first(where: { $0.kind == .seaweed || $0.kind == .grass }), !w.falling, !w.held {
            return CGPoint(x: w.x + CGFloat.random(in: -14...14), y: w.y - w.kind.size.height * CGFloat.random(in: 0.35...0.6))
        }
        let half = (k.length + k.tailLength) * 0.5
        let lim = AGeo.swim(half: half)
        // mostly a level cruise along the tank, sometimes up or down a bit
        let reach = CGFloat.random(in: 180...520) * (Bool.random() ? 1 : -1)
        let x = max(lim.minX + 40, min(lim.maxX - 40, f.p.x + reach))
        var y = randomDepth(k, x: x)
        y = f.p.y + (y - f.p.y) * CGFloat.random(in: 0.3...1)
        if night > 0.5 { y = max(y, AGeo.waterY + (AGeo.sand(x) - AGeo.waterY) * 0.55) }
        return CGPoint(x: x, y: y)
    }

    func mouth(_ f: AquaFish) -> CGPoint {
        let s = f.scale
        if f.kind == .seahorse {
            return CGPoint(x: f.p.x + f.dir * 22 * s, y: f.p.y - 22 * s)
        }
        let pitch = fishPitch(f)
        let r = f.kind.length * 0.5 * s * (1 + f.puff * 0.15)
        return CGPoint(x: f.p.x + f.facing.sign1 * cos(pitch) * r, y: f.p.y + sin(pitch) * r)
    }

    /// Nose up or down a little when it rises or dives.
    func fishPitch(_ f: AquaFish) -> CGFloat {
        if f.kind == .seahorse { return 0 }
        let a = atan2(f.v.dy, max(abs(f.v.dx), 20))
        return max(-0.45, min(0.45, a * 0.7))
    }

    private func nearestFood(to p: CGPoint, within: CGFloat) -> Int? {
        var best: Int?
        var bd = within * within
        for j in food.indices where food[j].state != .air {
            if food[j].state == .settled && food[j].age > 10 { continue }
            let dx = food[j].p.x - p.x, dy = food[j].p.y - p.y
            let d = dx * dx + dy * dy
            if d < bd { bd = d; best = j }
        }
        return best
    }

    private func eat(_ i: Int) {
        guard fish[i].appetite >= 1 else { return }
        let m = mouth(fish[i])
        let reach = 9 + 8 * fish[i].scale
        guard let j = food.indices.first(where: { food[$0].state != .air && hypot(food[$0].p.x - m.x, food[$0].p.y - m.y) < reach }) else { return }
        let fp = food[j].p
        food.remove(at: j)
        fish[i].appetite -= 1
        fish[i].gulp = 1
        AquaSound.shared.play(.gulp, volume: 0.55, gap: 0.08)
        if fp.y < surfaceY(fp.x) + 26 {
            disturb(fp.x, -3, width: 2)
            AquaSound.shared.play(.bloop, volume: 0.35, gap: 0.1)
        }
        if Int.random(in: 0..<3) == 0 {
            particles.append(AquaParticle(kind: .heart, p: CGPoint(x: m.x, y: m.y - 14), v: CGVector(dx: CGFloat.random(in: -10...10), dy: -40),
                                          life: 1.2, size: 13, color: ARGB(0xFF7FAE)))
        }
    }

    // MARK: Food

    private static let flakeLimit = 48

    /// A pinch enters at the surface in the tapped column, even when she taps a fish deep down.
    func feed(at point: CGPoint) {
        guard point.x >= AGeo.left, point.x <= AGeo.right,
              point.y >= AGeo.rimY - 30, point.y <= AGeo.bottomY else { return }
        let x = max(AGeo.left + 24, min(AGeo.right - 24, point.x))
        let excess = food.count + 5 - Self.flakeLimit
        if excess > 0 { food.removeFirst(excess) }
        for offset in [-16, -8, 0, 8, 16] {
            let dx = CGFloat(offset)
            addFlake(at: CGPoint(x: x + dx, y: surfaceY(x) - 10 - abs(dx)),
                     v: CGVector(dx: dx * 1.4, dy: 45))
        }
        disturb(x, 2.5, width: 2)
        AquaSound.shared.play(.shake, volume: 0.55, gap: 0.12)
    }

    func addFlake(at p: CGPoint, v: CGVector) {
        guard food.count < Self.flakeLimit else { return }
        food.append(AquaFood(p: p, v: v, floatFor: CGFloat.random(in: 0.8...2.4), hue: Int.random(in: 0..<4),
                             rot: CGFloat.random(in: 0...6), spin: CGFloat.random(in: -3...3), seed: CGFloat.random(in: 0...6)))
        lastFed = time
    }

    private func stepFood(_ dt: CGFloat) {
        var i = 0
        while i < food.count {
            var f = food[i]
            f.age += dt
            let sy = surfaceY(f.p.x)
            switch f.state {
            case .air:
                f.v.dy += AquariumSim.gravity * dt
                f.p.x += f.v.dx * dt
                f.p.y += f.v.dy * dt
                f.rot += f.spin * dt
                if f.p.y >= sy {
                    f.state = .floating
                    f.age = 0
                    f.p.y = sy
                    f.v = CGVector(dx: f.v.dx * 0.2, dy: 0)
                    disturb(f.p.x, 1.2, width: 1)
                    AquaSound.shared.play(.plop, volume: 0.25, gap: 0.07)
                }
            case .floating:
                // rides the waves, drifts apart, soaks up water and sinks
                f.p.y = sy + 1
                f.v.dx *= exp(-dt * 1.5)
                f.p.x += f.v.dx * dt + sin(CGFloat(time) * 1.3 + f.seed) * 4 * dt
                f.rot += sin(CGFloat(time) + f.seed) * dt * 0.5
                if f.age > f.floatFor { f.state = .sinking; f.v = CGVector(dx: 0, dy: 6) }
            case .sinking:
                // a flake flutters down: slow, rocking side to side
                let fall: CGFloat = 26 + f.seed * 2
                f.v.dy += (fall - f.v.dy) * min(1, dt * 2)
                f.p.y += f.v.dy * dt
                f.p.x += sin(f.age * 2.6 + f.seed) * 12 * dt
                f.rot = sin(f.age * 2.6 + f.seed) * 0.8
                let ground = AGeo.sand(f.p.x) - 2
                if f.p.y >= ground { f.p.y = ground; f.state = .settled; f.age = 0 }
            case .settled:
                if f.age > 14 { food.remove(at: i); continue }
            }
            f.p.x = max(AGeo.left + 4, min(AGeo.right - 4, f.p.x))
            food[i] = f
            i += 1
        }
    }

    // MARK: Bubbles

    func addBubble(_ p: CGPoint, r: CGFloat, back: Bool = false) {
        guard bubbles.count < 220 else { return }
        bubbles.append(AquaBubble(p: p, r: r, vy: -10, phase: CGFloat.random(in: 0...6), back: back))
    }

    private func stepBubbles(_ dt: CGFloat) {
        var i = 0
        var pops = 0
        while i < bubbles.count {
            var b = bubbles[i]
            // Bigger bubbles rise faster and wobble wider; they grow a little as the water above thins out.
            let rise = min(170, 30 + b.r * 13)
            b.vy += (-rise - b.vy) * min(1, dt * 3)
            b.phase += dt * (4 + 26 / max(1.5, b.r))
            b.p.x += sin(b.phase) * b.r * 2.4 * dt
            b.p.y += b.vy * dt
            b.r *= 1 + dt * 0.012
            let top = surfaceY(b.p.x)
            if b.p.y - b.r * 0.3 <= top {
                pops += 1
                disturb(b.p.x, -min(2.5, b.r * 0.22), width: 1)
                if b.r > 2.2 {
                    particles.append(AquaParticle(kind: .ring, p: CGPoint(x: b.p.x, y: top), v: .zero, life: 0.35, size: b.r * 1.6, color: ARGB(0xFFFFFF)))
                }
                if b.r > 4.5 {
                    for _ in 0..<2 {
                        particles.append(AquaParticle(kind: .splash, p: CGPoint(x: b.p.x, y: top - 2),
                                                      v: CGVector(dx: CGFloat.random(in: -40...40), dy: CGFloat.random(in: -160 ... -70)),
                                                      life: 0.8, size: 1.6, color: ARGB(0xCFF1FF)))
                    }
                }
                bubbles.remove(at: i)
                continue
            }
            bubbles[i] = b
            i += 1
        }
        if pops > 0 { AquaSound.shared.play(.pop, volume: Float(min(0.45, 0.12 + CGFloat(pops) * 0.05)), gap: 0.09) }

        // The pump's air stone at the back, and every bubbler, chest and diver in the tank.
        guard pump else { return }
        if CGFloat.random(in: 0...1) < dt * 16 {
            addBubble(CGPoint(x: 936 + CGFloat.random(in: -5...5), y: AGeo.sand(936) - 10), r: CGFloat.random(in: 1.8...5.2), back: true)
        }
        for d in decor where !d.held && !d.falling {
            switch d.kind {
            case .bubbler:
                if CGFloat.random(in: 0...1) < dt * 18 {
                    addBubble(CGPoint(x: d.x + CGFloat.random(in: -12...12), y: d.y - 14), r: CGFloat.random(in: 1.5...4.2))
                }
            default: break
            }
        }
    }

    // MARK: Surface

    func surfaceY(_ x: CGFloat) -> CGFloat {
        let f = (x - AGeo.left) / AGeo.width * CGFloat(AGeo.surfaceNodes - 1)
        let i0 = max(0, min(AGeo.surfaceNodes - 1, Int(f.rounded(.down))))
        let i1 = min(AGeo.surfaceNodes - 1, i0 + 1)
        let k = max(0, min(1, f - CGFloat(i0)))
        let t = CGFloat(time)
        let calm = 1.4 * sin(x * 0.018 + t * 1.3) + 0.8 * sin(x * 0.043 - t * 2.1)
        return AGeo.waterY + sh[i0] + (sh[i1] - sh[i0]) * k + calm
    }

    /// Pushes the surface down (+) or up (-) around x.
    func disturb(_ x: CGFloat, _ amount: CGFloat, width: Int) {
        let f = (x - AGeo.left) / AGeo.width * CGFloat(AGeo.surfaceNodes - 1)
        let c = Int(f.rounded())
        for i in max(0, c - width)...min(AGeo.surfaceNodes - 1, c + width) {
            let k = 1 - CGFloat(abs(i - c)) / CGFloat(width + 1)
            sv[i] += amount * 60 * k
        }
    }

    func splash(at x: CGFloat, strength: CGFloat) {
        disturb(x, 7 * strength, width: 3)
        let y = surfaceY(x)
        for _ in 0..<Int(10 + 12 * strength) {
            particles.append(AquaParticle(kind: .splash, p: CGPoint(x: x + CGFloat.random(in: -16...16), y: y - 2),
                                          v: CGVector(dx: CGFloat.random(in: -150...150), dy: CGFloat.random(in: -420 ... -120) * strength),
                                          life: 1.2, size: CGFloat.random(in: 1.6...3.6), color: ARGB(0xD8F4FF)))
        }
        AquaSound.shared.play(.splash, volume: Float(0.4 + 0.4 * min(1, strength)), gap: 0.1)
    }

    private func stepSurface(_ dt: CGFloat) {
        let n = AGeo.surfaceNodes
        let h = dt / 2
        for _ in 0..<2 {
            for i in 0..<n {
                let l = i > 0 ? sh[i - 1] : sh[i]
                let r = i < n - 1 ? sh[i + 1] : sh[i]
                let a = -30 * sh[i] + 1100 * (l + r - 2 * sh[i]) - 2.2 * sv[i]
                sv[i] += a * h
            }
            for i in 0..<n {
                sh[i] = max(-24, min(24, sh[i] + sv[i] * h))
            }
        }
    }

    // MARK: Decorations

    @discardableResult
    func addDecor(_ kind: AquaDecorKind, x: CGFloat, falling: Bool = false, y: CGFloat? = nil) -> Int {
        let w = kind.size.width * 0.5
        let cx = max(AGeo.left + w * 0.6, min(AGeo.right - w * 0.6, x))
        var d = AquaDecor(id: nextID, kind: kind, x: cx, y: y ?? AGeo.sand(cx))
        nextID += 1
        d.falling = falling
        d.wet = !falling || (y ?? 999) - kind.size.height * 0.5 > surfaceY(cx)
        d.flip = nextID % 2 == 0
        d.nextPuff = time + Double.random(in: 2...9)
        decor.append(d)
        return decor.count - 1
    }

    private func stepDecor(_ dt: CGFloat) {
        let t = CGFloat(time)
        var i = 0
        while i < decor.count {
            var d = decor[i]
            let size = d.kind.size
            if d.held {
                let px = d.x
                let follow = min(1, dt * 18)
                d.x += (decorTarget.x - d.x) * follow
                d.y += (decorTarget.y - d.y) * follow
                let vx = (d.x - px) / max(dt, 0.001)
                d.rotV += ((max(-0.6, min(0.6, vx * 0.0016)) - d.rot) * 60 - d.rotV * 9) * dt
                d.rot += d.rotV * dt
                d.swayV += (-vx * 0.03 - d.sway * 14 - d.swayV * 2) * dt
                d.sway += d.swayV * dt
                decor[i] = d
                i += 1
                continue
            }
            let halfW = size.width * 0.5
            if d.falling {
                let mid = d.y - size.height * 0.5
                let water = mid > surfaceY(d.x)
                if !d.wet && water {
                    d.wet = true
                    splash(at: d.x, strength: min(1.4, 0.4 + d.vy / 900))
                    d.vy *= 0.35
                    d.vx *= 0.5
                    for _ in 0..<6 { addBubble(CGPoint(x: d.x + CGFloat.random(in: -halfW...halfW) * 0.6, y: mid), r: CGFloat.random(in: 2...6)) }
                }
                if water {
                    // buoyancy and drag: heavy things sink fast, plants drift down
                    let rho = d.kind.density
                    d.vy += (900 * (1 - 1 / rho) - 2.4 * d.vy) * dt
                    d.vx *= exp(-dt * 2.5)
                    if d.kind.sways { d.rotV += sin(t * 3 + CGFloat(d.id)) * 1.2 * dt }
                    if CGFloat.random(in: 0...1) < dt * 3 { addBubble(CGPoint(x: d.x + CGFloat.random(in: -halfW...halfW) * 0.4, y: d.y - size.height * 0.7), r: CGFloat.random(in: 1.5...3)) }
                } else {
                    d.vy += AquariumSim.gravity * dt
                }
                d.rotV += (-16 * d.rot - (water ? 4 : 0.5) * d.rotV) * dt
                d.rot += d.rotV * dt
                d.x += d.vx * dt
                d.y += d.vy * dt
                d.x = max(AGeo.left + halfW * 0.6, min(AGeo.right - halfW * 0.6, d.x))
                let seat = d.kind == .slate ? bridge(at: d.x) : nil
                let ground = seat?.y ?? AGeo.sand(d.x)
                if d.y >= ground {
                    let impact = d.vy
                    d.y = ground
                    d.vy = 0
                    d.vx = 0
                    d.falling = false
                    d.squashV = min(9, impact / 40)
                    land(d, impact: impact)
                }
            } else {
                let seat = d.kind == .slate ? bridge(at: d.x) : nil
                let ground = seat?.y ?? AGeo.sand(d.x)
                if ground > d.y+3 { d.falling = true }
                else { d.y = ground }
                d.rotV += (-30 * d.rot - 8 * d.rotV) * dt
                d.rot += d.rotV * dt
            }
            d.squashV += (-260 * d.squash - 12 * d.squashV) * dt
            d.squash += d.squashV * dt

            if d.kind.sways {
                // fish swimming past push plants with their wake
                var push: CGFloat = 0
                for f in fish where !f.caught {
                    let dx = abs(f.p.x - d.x), top = d.y - size.height
                    if dx < halfW + 40 && f.p.y > top && f.p.y < d.y { push += f.v.dx * 0.05 }
                }
                if let h = hand, case .water = grab, abs(h.x - d.x) < halfW + 30, h.y > d.y - size.height, h.y < d.y {
                    push += handV.dx * 0.06
                }
                d.swayV += (push - d.sway * 9 - d.swayV * 1.6) * dt
                d.sway = max(-1.2, min(1.2, d.sway + d.swayV * dt))
            }

            // chests open now and then and let a big gulp of air out; divers puff from their helmets
            if pump && !d.falling {
                if d.kind == .chest && time > d.nextPuff {
                    openChest(&d)
                    d.nextPuff = time + Double.random(in: 10...16)
                } else if d.kind == .diver && time > d.nextPuff {
                    d.nextPuff = time + Double.random(in: 2.5...4.5)
                    for k in 0..<4 {
                        addBubble(CGPoint(x: d.x + (d.flip ? -8 : 8) + CGFloat(k) * 2, y: d.y - 118 - CGFloat(k) * 9), r: CGFloat.random(in: 2...4.5))
                    }
                    AquaSound.shared.play(.bloop, volume: 0.3, gap: 0.3)
                } else if d.kind == .castle && time > d.nextPuff {
                    d.nextPuff = time + Double.random(in: 4...8)
                    addBubble(CGPoint(x: d.x + (d.flip ? 40 : -40), y: d.y - 140), r: CGFloat.random(in: 2...3.5))
                }
            }
            let lid: CGFloat = time < d.openUntil ? 1 : 0
            d.open += (lid - d.open) * min(1, dt * (lid > 0 ? 7 : 2.5))
            decor[i] = d
            i += 1
        }
    }

    private func openChest(_ d: inout AquaDecor) {
        d.openUntil = time + 1.8
        AquaSound.shared.play(.creak, volume: 0.45)
        for k in 0..<14 {
            addBubble(CGPoint(x: d.x + CGFloat.random(in: -26...26), y: d.y - 40 - CGFloat(k) * 4), r: CGFloat.random(in: 2.5...8))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { AquaSound.shared.play(.bloop, volume: 0.5) }
    }

    private func land(_ d: AquaDecor, impact: CGFloat) {
        let n = Int(min(26, 4 + impact / 12))
        let w = d.kind.size.width * 0.45
        for _ in 0..<n {
            let side: CGFloat = Bool.random() ? 1 : -1
            particles.append(AquaParticle(kind: .sand, p: CGPoint(x: d.x + side * CGFloat.random(in: 0...w), y: d.y - 3),
                                          v: CGVector(dx: side * CGFloat.random(in: 20...90), dy: CGFloat.random(in: -70 ... -15)),
                                          life: CGFloat.random(in: 1.2...2.2), size: CGFloat.random(in: 1.5...3), color: ARGB(0xE8D2A6)))
        }
        for k in 0..<3 {
            particles.append(AquaParticle(kind: .poof, p: CGPoint(x: d.x + CGFloat(k - 1) * w * 0.7, y: d.y - 6),
                                          v: CGVector(dx: CGFloat(k - 1) * 30, dy: -10), life: 1.8, size: 20 + w * 0.2, color: ARGB(0xEADBB8)))
        }
        AquaSound.shared.play(.thud, volume: Float(min(0.9, 0.2 + impact / 400)))
    }

    func decorIndex(_ id: Int) -> Int? { decor.firstIndex { $0.id == id } }

    /// The decoration under a finger at p (front-most first).
    func decorAt(_ p: CGPoint) -> Int? {
        for i in decor.indices.reversed() {
            let d = decor[i]
            let s = d.kind.size
            var w = s.width * 0.5 + 10
            var top = d.y - s.height - 6
            if d.kind == .seaweed || d.kind == .grass { w *= 0.7; top = d.y - s.height * 0.75 }
            if abs(p.x - d.x) < w && p.y > top && p.y < d.y + 16 { return i }
        }
        return nil
    }

    // MARK: Algae and the snail

    private func stepAlgae(_ dt: CGFloat) {
        if time - algaeTick > 1 {
            algaeTick = time
            let rate: CGFloat = (lightsOn ? 1 : 0.4) / 170
            for r in 0..<AGeo.algaeRows {
                let low = 0.5 + CGFloat(r) / CGFloat(AGeo.algaeRows) * 0.9
                for c in 0..<AGeo.algaeCols {
                    let i = r * AGeo.algaeCols + c
                    // it creeps from where there is already some, so it grows in patches
                    let seed = aqRand(i, 11)
                    // most of the glass stays clear for a long time; patches start where the seed is high and spread from there
                    let k = rate * low * (seed * seed * seed * 1.6) * (0.4 + algae[i] * 2)
                    algae[i] = min(1, algae[i] + k)
                }
            }
            algaeDirty = true
        }
        // The snail grazes: it heads for dirty glass and leaves a clean track.
        var s = snail
        s.phase += dt
        s.hide += ((time < s.hideUntil ? 1 : 0) - s.hide) * min(1, dt * 6)
        if s.hide < 0.3 {
            let dx = s.target.x - s.p.x, dy = s.target.y - s.p.y
            let d = hypot(dx, dy)
            if d < 10 {
                s.target = dirtiestSpot()
            } else {
                let want = atan2(dy, dx)
                var turn = want - s.heading
                while turn > .pi { turn -= 2 * .pi }
                while turn < -.pi { turn += 2 * .pi }
                s.heading += max(-0.5 * dt, min(0.5 * dt, turn))
                let sp: CGFloat = 7 * (1 + 0.3 * sin(s.phase * 2.2))
                s.p.x += cos(s.heading) * sp * dt
                s.p.y += sin(s.heading) * sp * dt
                s.p.x = max(AGeo.left + 20, min(AGeo.right - 20, s.p.x))
                s.p.y = max(AGeo.waterY + 24, min(AGeo.bottomY - 16, s.p.y))
                wipe(at: s.p, radius: 20, amount: 0.35 * dt, sparkle: false)
            }
        }
        snail = s
        if algaeDirty && time - algaeBuilt > 0.06 { rebuildAlgae() }
    }

    private func dirtiestSpot() -> CGPoint {
        var best = CGPoint(x: CGFloat.random(in: 120...900), y: CGFloat.random(in: 260...640))
        var bv: CGFloat = -1
        for k in 0..<7 {
            let c = Int(aqRand(Int(time * 10) + k, 3) * CGFloat(AGeo.algaeCols))
            let r = 2 + Int(aqRand(Int(time * 10) + k, 4) * CGFloat(AGeo.algaeRows - 3))
            let i = min(algae.count - 1, r * AGeo.algaeCols + min(c, AGeo.algaeCols - 1))
            if algae[i] > bv { bv = algae[i]; best = AGeo.cellCenter(min(c, AGeo.algaeCols - 1), r) }
        }
        best.y = max(AGeo.waterY + 30, min(AGeo.bottomY - 20, best.y))
        return best
    }

    /// Rubs algae off the glass around p. Returns how much came off.
    @discardableResult
    func wipe(at p: CGPoint, radius R: CGFloat, amount: CGFloat, sparkle: Bool) -> CGFloat {
        let c0 = max(0, Int((p.x - R - AGeo.left) / AGeo.cellW))
        let c1 = min(AGeo.algaeCols - 1, Int((p.x + R - AGeo.left) / AGeo.cellW))
        let r0 = max(0, Int((p.y - R - AGeo.glassTop) / AGeo.cellH))
        let r1 = min(AGeo.algaeRows - 1, Int((p.y + R - AGeo.glassTop) / AGeo.cellH))
        guard c0 <= c1, r0 <= r1 else { return 0 }
        var off: CGFloat = 0
        for r in r0...r1 {
            for c in c0...c1 {
                let q = AGeo.cellCenter(c, r)
                let d = hypot(q.x - p.x, q.y - p.y)
                guard d < R else { continue }
                let i = r * AGeo.algaeCols + c
                let before = algae[i]
                guard before > 0 else { continue }
                let k = amount * (1 - d / R * 0.6)
                algae[i] = max(0, before - k)
                off += before - algae[i]
                if sparkle && before > 0.3 && algae[i] < 0.08 && Int.random(in: 0..<4) == 0 {
                    particles.append(AquaParticle(kind: .sparkle, p: q, v: .zero, life: 0.6, size: 10, color: ARGB(0xFFFFFF)))
                }
            }
        }
        if off > 0 { algaeDirty = true }
        return off
    }

    var dirtiness: CGFloat { algae.reduce(0, +) / CGFloat(algae.count) }

    /// The algae drawn as soft blotches in three strengths (rebuilt only when the glass changes).
    var algaePaths: [Path] { algaeCache }

    private func rebuildAlgae() {
        algaeBuilt = time
        algaeDirty = false
        algaeVersion += 1
        var paths = [Path(), Path(), Path()]
        let w = AGeo.cellW, h = AGeo.cellH
        for r in 0..<AGeo.algaeRows {
            for c in 0..<AGeo.algaeCols {
                let i = r * AGeo.algaeCols + c
                let v = algae[i]
                guard v > 0.06 else { continue }
                let b = v < 0.3 ? 0 : (v < 0.62 ? 1 : 2)
                let q = AGeo.cellCenter(c, r)
                let jx = (aqRand(i, 1) - 0.5) * w * 0.5, jy = (aqRand(i, 2) - 0.5) * h * 0.5
                let rad = w * (0.6 + 0.55 * min(1, v * 1.3)) * (0.85 + 0.3 * aqRand(i, 3))
                paths[b].addEllipse(in: CGRect(x: q.x + jx - rad, y: q.y + jy - rad * 0.9, width: rad * 2, height: rad * 1.8))
            }
        }
        algaeCache = paths
        let dirty = dirtiness
        if wasDirty && dirty < 0.02 {
            // the whole glass is clean: a shimmer across it
            AquaSound.shared.play(.chime, volume: 0.7)
            for k in 0..<16 {
                particles.append(AquaParticle(kind: .sparkle, p: CGPoint(x: 90 + CGFloat(k) * 56, y: CGFloat.random(in: 200...600)),
                                              v: .zero, life: 0.9 + CGFloat(k % 4) * 0.15, size: 16, color: ARGB(0xFFFFFF)))
            }
            wasDirty = false
        } else if dirty > 0.1 {
            wasDirty = true
        }
    }

    // MARK: Particles

    private func stepParticles(_ dt: CGFloat) {
        var i = 0
        while i < particles.count {
            var q = particles[i]
            q.age += dt
            if q.age >= q.life { particles.remove(at: i); continue }
            switch q.kind {
            case .splash:
                q.v.dy += AquariumSim.gravity * dt
                q.p.x += q.v.dx * dt
                q.p.y += q.v.dy * dt
                if q.v.dy > 0 && q.p.y > surfaceY(q.p.x) && q.p.x > AGeo.left && q.p.x < AGeo.right {
                    disturb(q.p.x, 0.4, width: 0)
                    particles.remove(at: i)
                    continue
                }
            case .sand:
                // sand thrown up in water slows fast and settles back
                q.v.dx *= exp(-dt * 3)
                q.v.dy += (22 - q.v.dy) * min(1, dt * 2.5)
                q.p.x += q.v.dx * dt
                q.p.y += q.v.dy * dt
                if q.p.y > AGeo.sand(q.p.x) { particles.remove(at: i); continue }
            case .poof:
                q.v.dx *= exp(-dt * 2)
                q.p.x += q.v.dx * dt
                q.p.y += q.v.dy * dt
                q.size += dt * 22
            case .heart:
                q.p.x += q.v.dx * dt + sin(q.age * 6) * 12 * dt
                q.p.y += q.v.dy * dt
            case .algae:
                q.v.dy += (18 - q.v.dy) * min(1, dt * 2)
                q.p.x += sin(q.age * 3 + q.size) * 10 * dt
                q.p.y += q.v.dy * dt
                if q.p.y > AGeo.sand(q.p.x) { particles.remove(at: i); continue }
            case .glow:
                q.p.x += q.v.dx * dt + sin(q.age * 1.3 + q.size * 3) * 6 * dt
                q.p.y += q.v.dy * dt
            case .ring, .sparkle:
                break
            }
            particles[i] = q
            i += 1
        }
        // a few glowing specks drift about in the dark
        if night > 0.5 && CGFloat.random(in: 0...1) < dt * 2.5 && particles.count < 260 {
            particles.append(AquaParticle(kind: .glow, p: CGPoint(x: CGFloat.random(in: 80...950), y: CGFloat.random(in: 200...580)),
                                          v: CGVector(dx: CGFloat.random(in: -6...6), dy: CGFloat.random(in: -5...3)),
                                          life: CGFloat.random(in: 4...8), size: CGFloat.random(in: 1.5...3.2),
                                          color: [ARGB(0x8CF7FF), ARGB(0xB8FFC8), ARGB(0xD9B8FF)][Int.random(in: 0..<3)]))
        }
    }

    private func bye(_ p: CGPoint) {
        for k in 0..<8 {
            let a = CGFloat(k) / 8 * 2 * .pi
            particles.append(AquaParticle(kind: .sparkle, p: CGPoint(x: p.x + cos(a) * 24, y: p.y + sin(a) * 24), v: .zero,
                                          life: 0.5 + CGFloat(k % 3) * 0.1, size: 12, color: ARGB(0xFFFFFF)))
        }
    }

    // MARK: Time

    func step(_ now: Date) {
        let raw = last.map { now.timeIntervalSince($0) } ?? 1.0 / 60
        last = now
        step(dt: CGFloat(min(max(raw, 0), 1.0 / 30)))
    }

    func step(dt: CGFloat) {
        guard dt > 0 else { return }
        time += Double(dt)
        night += ((lightsOn ? 0 : 1) - night) * min(1, dt * 1.6)
        if let kind = huntKind, !fish.contains(where: { $0.kind == kind && !$0.caught }) { chooseHuntFish() }
        stepHand(dt)
        stepTool(dt)
        stepSurface(dt)
        stepFish(dt)
        stepFood(dt)
        stepBubbles(dt)
        stepDecor(dt)
        updateReef(dt)
        stepAlgae(dt)
        stepParticles(dt)
        stepFinds(dt)
        AquaSound.shared.setLoop(.hum, volume: 0.3)
        AquaSound.shared.setLoop(.pump, volume: pump ? 0.32 : 0)
        if time - lastSave > 20 { lastSave = time; save() }
    }

    func setLights(_ on: Bool) {
        lightsOn = on
        AquaSound.shared.play(.click, volume: 0.6)
    }

    func setPump(_ on: Bool) {
        pump = on
        AquaSound.shared.play(on ? .bloop : .click, volume: 0.6)
    }

    // MARK: Her hand on the glass

    func handBegan(_ p: CGPoint) {
        hand = p
        handStart = time
        handStill = 0
        handV = .zero
        handStartP = p
        if let i = decorAt(p) {
            grab = .maybeDecor(id: decor[i].id)
        } else if p.x > AGeo.left, p.x < AGeo.right, abs(p.y - surfaceY(p.x)) < 36 {
            grab = .surface
        } else if AGeo.tank.contains(p) {
            grab = .water
        } else {
            grab = .none
        }
    }

    func handMoved(_ p: CGPoint, dt: CGFloat) {
        guard let h = hand else { return }
        let v = CGVector(dx: (p.x - h.x) / dt, dy: (p.y - h.y) / dt)
        handV.dx += (v.dx - handV.dx) * 0.5
        handV.dy += (v.dy - handV.dy) * 0.5
        hand = p
        let moved = hypot(p.x - h.x, p.y - h.y)
        if moved > 1.5 { handStill = 0 }
        switch grab {
        case .maybeDecor(let id):
            if hypot(p.x - handStartP.x, p.y - handStartP.y) > 10, let i = decorIndex(id) {
                grab = .decor(id: id)
                decorTarget = CGPoint(x:decor[i].x,y:decor[i].y)
                decor[i].held = true
                decor[i].falling = false
                AquaSound.shared.play(.pick, volume: 0.5)
            }
        case .surface:
            // dragging a finger through the surface makes waves, and a fast swipe throws droplets
            let f = (p.x - AGeo.left) / AGeo.width * CGFloat(AGeo.surfaceNodes - 1)
            let c = max(0, min(AGeo.surfaceNodes - 1, Int(f.rounded())))
            sv[c] += handV.dy * 0.08 + abs(handV.dx) * 0.03
            if hypot(handV.dx, handV.dy) > 500 && CGFloat.random(in: 0...1) < 0.4 {
                particles.append(AquaParticle(kind: .splash, p: CGPoint(x: p.x, y: surfaceY(p.x) - 2),
                                              v: CGVector(dx: handV.dx * 0.25 + CGFloat.random(in: -40...40), dy: CGFloat.random(in: -300 ... -120)),
                                              life: 1, size: CGFloat.random(in: 1.5...3), color: ARGB(0xD8F4FF)))
                AquaSound.shared.play(.splish, volume: 0.35, gap: 0.18)
            }
        case .water:
            // a quick swipe sends nearby fish darting off
            if hypot(handV.dx, handV.dy) > 700 {
                for i in fish.indices where !fish[i].caught && hypot(fish[i].p.x - p.x, fish[i].p.y - p.y) < 110 {
                    startle(i, from: p)
                }
            }
        default:
            break
        }
    }

    private func stepHand(_ dt: CGFloat) {
        guard let h = hand else { return }
        handStill += Double(dt)
        switch grab {
        case .decor(let id):
            guard decorIndex(id) != nil else { break }
            if let i = decorIndex(id), decor[i].kind == .slate || decor[i].kind == .pillar {
                decorTarget = CGPoint(x:h.x,y:h.y+decor[i].kind.size.height/2)
            } else {
                decorTarget = FingerLift.point(h, lift: FingerLift.item, bottom: DesignCanvas<EmptyView>.designHeight, width: 1024)
            }
        case .water:
            // a finger resting on the glass: the fish come to see it
            if handStill > 0.35 {
                for i in fish.indices where !fish[i].caught && time > fish[i].fleeUntil {
                    if hypot(fish[i].p.x - h.x, fish[i].p.y - h.y) < 420 {
                        fish[i].curious = h
                        fish[i].curiousUntil = time + 0.6
                    }
                }
            }
        default:
            break
        }
    }

    func handEnded(_ p: CGPoint, tap: Bool) {
        defer { hand = nil; grab = .none }
        switch grab {
        case .decor(let id):
            guard let i = decorIndex(id) else { return }
            decor[i].held = false
            if p.y > AGeo.bottomY + 6 || decor[i].x < AGeo.left || decor[i].x > AGeo.right {
                // dropped on the cabinet: it goes back in the box
                bye(CGPoint(x: decor[i].x, y: decor[i].y - decor[i].kind.size.height * 0.5))
                AquaSound.shared.play(.swish, volume: 0.5)
                decor.remove(at: i)
            } else {
                decor[i].falling = true
                decor[i].wet = decor[i].y - decor[i].kind.size.height * 0.5 > surfaceY(decor[i].x)
                decor[i].vy = handV.dy * 0.15
                decor[i].vx = handV.dx * 0.15
                AquaSound.shared.play(.swish, volume: 0.25)
            }
            return
        case .maybeDecor(let id):
            if tap, let i = decorIndex(id) {
                if tapFishOrBubble(p) { return }
                pokeDecor(i)
            }
            return
        default:
            break
        }
        guard tap else { return }
        if tapFishOrBubble(p) { return }
        if hypot(p.x - snail.p.x, p.y - snail.p.y) < 34 {
            snail.hideUntil = time + 3
            AquaSound.shared.play(.blub, volume: 0.4)
            return
        }
        if AGeo.tank.contains(p) { tapGlass(p) }
    }

    /// A tap on a bubble pops it; a tap on a fish makes it happy. True if something was there.
    private func tapFishOrBubble(_ p: CGPoint) -> Bool {
        if let kind = huntKind, let i = fishAt(p), fish[i].kind == kind {
            tapFish(i)
            findFish(i)
            return true
        }
        if tapVisitor(p) { return true }
        if let b = bubbles.indices.last(where: { hypot(bubbles[$0].p.x - p.x, bubbles[$0].p.y - p.y) < bubbles[$0].r + 16 && !bubbles[$0].back }) {
            let q = bubbles[b].p
            particles.append(AquaParticle(kind: .ring, p: q, v: .zero, life: 0.3, size: bubbles[b].r * 2, color: ARGB(0xFFFFFF)))
            bubbles.remove(at: b)
            AquaSound.shared.play(.pop, volume: 0.6)
            return true
        }
        if let i = fishAt(p) {
            tapFish(i)
            return true
        }
        return false
    }

    func fishAt(_ p: CGPoint) -> Int? {
        var best: Int?
        var bz: CGFloat = -1
        for i in fish.indices where !fish[i].caught {
            let f = fish[i]
            let s = f.scale * (1 + f.puff * 0.3)
            let w = (f.kind.length * 0.5 + f.kind.tailLength * 0.5) * s + 16
            let h = f.kind.height * 0.5 * s + 18
            if abs(p.x - f.p.x) < w && abs(p.y - f.p.y) < h && f.z > bz { bz = f.z; best = i }
        }
        return best
    }

    func tapFish(_ i: Int) {
        fish[i].happy = time
        fish[i].gulp = 1
        fish[i].v.dx += fish[i].dir * 70
        if fish[i].kind == .puffer {
            fish[i].puffUntil = time + 2.6
            AquaSound.shared.play(.puff, volume: 0.7)
        } else {
            AquaSound.shared.play(.blub, volume: 0.65)
        }
        let m = mouth(fish[i])
        for k in 0..<3 { addBubble(CGPoint(x: m.x, y: m.y - CGFloat(k) * 7), r: 2 + CGFloat(k)) }
        particles.append(AquaParticle(kind: .heart, p: CGPoint(x: fish[i].p.x, y: fish[i].p.y - 30), v: CGVector(dx: 0, dy: -46),
                                      life: 1.3, size: 16, color: ARGB(0xFF7FAE)))
    }

    private func pokeDecor(_ i: Int) {
        decor[i].poke = time
        decor[i].squashV = 5
        if decor[i].kind.sways { decor[i].swayV += 3 * (Bool.random() ? 1 : -1) }
        switch decor[i].kind {
        case .chest:
            var d = decor[i]
            openChest(&d)
            decor[i] = d
            maybePearl(i)
        case .shell:
            AquaSound.shared.play(.creak, volume: 0.35)
            particles.append(AquaParticle(kind: .sparkle, p: CGPoint(x: decor[i].x, y: decor[i].y - 22), v: .zero, life: 0.7, size: 16, color: ARGB(0xFFFFFF)))
        case .diver, .bubbler, .castle:
            for k in 0..<6 {
                let top = decor[i].kind == .bubbler ? 16 : decor[i].kind.size.height * 0.8
                addBubble(CGPoint(x: decor[i].x + CGFloat.random(in: -10...10), y: decor[i].y - top - CGFloat(k) * 6), r: CGFloat.random(in: 2...5))
            }
            AquaSound.shared.play(.bloop, volume: 0.5)
        default:
            AquaSound.shared.play(.boing, volume: 0.4)
        }
    }

    private func tapGlass(_ p: CGPoint) {
        AquaSound.shared.play(.tink, volume: 0.6)
        particles.append(AquaParticle(kind: .ring, p: p, v: .zero, life: 0.5, size: 34, color: ARGB(0xFFFFFF)))
        for i in fish.indices where !fish[i].caught {
            if hypot(fish[i].p.x - p.x, fish[i].p.y - p.y) < 300 { startle(i, from: p) }
        }
    }

    private func startle(_ i: Int, from p: CGPoint) {
        var f = fish[i]
        let dx = f.p.x - p.x, dy = f.p.y - p.y
        let d = max(1, hypot(dx, dy))
        f.flee = CGVector(dx: dx / d, dy: dy / d)
        f.fleeUntil = time + Double.random(in: 0.5...0.9)
        // then, a moment later, curiosity wins
        f.curious = p
        f.curiousUntil = time + Double.random(in: 3.5...5)
        if f.kind == .puffer { f.puffUntil = time + 2.4; AquaSound.shared.play(.puff, volume: 0.5, gap: 0.5) }
        fish[i] = f
    }

    // MARK: Tools

    func pickUp(_ t: AquaTool, at p: CGPoint) {
        tool = t
        finger = p
        toolP = p
        toolV = .zero
        lastToolV = .zero
        tilt = 0
        tiltV = 0
        shake = 0
        caught = nil
        returning = nil
        switch t {
        case .food: AquaSound.shared.play(.shake, volume: 0.5)
        case .sponge: AquaSound.shared.play(.pick, volume: 0.5)
        case .net:
            AquaSound.shared.play(.swish, volume: 0.4)
            if AGeo.inWater(p) { scoop(at: p) }
        case .fish: AquaSound.shared.play(.bag, volume: 0.6)
        case .decor: AquaSound.shared.play(.pick, volume: 0.5)
        }
    }

    private func scoop(at point: CGPoint) {
        guard caught == nil else { return }
        var nearest = fishAt(point)
        if nearest == nil {
            var best: CGFloat = 48 * 48
            for i in fish.indices where !fish[i].caught {
                let dx = fish[i].p.x - point.x, dy = fish[i].p.y - point.y
                let distance = dx * dx + dy * dy
                if distance < best { best = distance; nearest = i }
            }
        }
        if let i = nearest {
            fish[i].caught = true
            caught = fish[i].id
            AquaSound.shared.play(.blub, volume: 0.6)
        }
    }

    /// How much bigger the sponge is in her hand than on the shelf.
    static let spongeScale: CGFloat = 1.6

    /// `p` is where the tool goes, `hand` where her finger really is (the net's handle points away from it).
    func carry(to p: CGPoint, hand h: CGPoint? = nil) {
        finger = p
        hold = h ?? CGPoint(x: p.x, y: p.y + FingerLift.tool)
    }

    /// Lets go of the carried tool. `home` is where it flies back to.
    func release(home: CGPoint) {
        guard let t = tool else { return }
        let over = AGeo.overTank(toolP) && finger.y < AGeo.bottomY + 40
        switch t {
        case .fish(let k) where over:
            addFish(k, x: toolP.x, y: toolP.y)
        case .decor(let k) where over:
            let i = addDecor(k, x: toolP.x, falling: true, y: min(toolP.y + k.size.height * 0.5, AGeo.sand(toolP.x)))
            decor[i].rot = tilt
            decor[i].vx = toolV.dx * 0.15
            decor[i].vy = max(0, toolV.dy * 0.2)
            AquaSound.shared.play(.swish, volume: 0.4)
        default:
            if case .net = t, let id = caught, let i = fish.firstIndex(where: { $0.id == id }) {
                if over {
                    // back into the water it goes
                    fish[i].caught = false
                    fish[i].p = CGPoint(x: max(AGeo.left + 50, min(AGeo.right - 50, toolP.x)),
                                        y: max(surfaceY(toolP.x) + 20, min(AGeo.sand(toolP.x) - 40, toolP.y)))
                    fish[i].v = CGVector(dx: fish[i].dir * 140, dy: 30)
                    fish[i].fleeUntil = time + 0.6
                    fish[i].flee = CGVector(dx: fish[i].dir, dy: 0.2)
                    if toolP.y < surfaceY(toolP.x) { splash(at: toolP.x, strength: 0.6) } else { AquaSound.shared.play(.blub, volume: 0.5) }
                } else {
                    // lifted out and taken home: back to the shop's tank
                    bye(toolP)
                    AquaSound.shared.play(.chime, volume: 0.4)
                    fish.remove(at: i)
                }
            }
            returning = (t, toolP, home, time, tilt)
        }
        caught = nil
        tool = nil
    }

    private func stepTool(_ dt: CGFloat) {
        guard let t = tool else { return }
        let prev = toolP
        let wasWet = AGeo.inWater(prev)
        // things in the water drag behind her finger a little
        let follow: CGFloat = t == .net || t == .food ? 1 : min(1, dt * 30)
        toolP.x += (finger.x - toolP.x) * follow
        toolP.y += (finger.y - toolP.y) * follow
        let vx = (toolP.x - prev.x) / dt
        let vy = (toolP.y - prev.y) / dt
        lastToolV = toolV
        toolV.dx += (vx - toolV.dx) * min(1, dt * 18)
        toolV.dy += (vy - toolV.dy) * min(1, dt * 18)
        let jerk = hypot(toolV.dx - lastToolV.dx, toolV.dy - lastToolV.dy) / dt
        shake = max(shake * exp(-dt * 4), min(3, jerk / 4000))
        let over = AGeo.overTank(toolP)
        let wet = AGeo.inWater(toolP)
        if wet != wasWet && hypot(toolV.dx, toolV.dy) > 150 && (t == .net || t == .food) {
            splash(at: toolP.x, strength: 0.35)
        }

        var target: CGFloat = 0
        switch t {
        case .food:
            // turned over above the water and shaken: flakes tumble out of the cap
            target = over ? 1.98 + sin(CGFloat(time) * 14) * 0.06 * shake : 0
            if over {
                foodAcc += dt * (4 + min(1, shake) * 6)
                while foodAcc > 1 {
                    foodAcc -= 1
                    addFlake(at: CGPoint(x: toolP.x + CGFloat.random(in: -6...6) * FingerLift.spread * 2, y: toolP.y + 4),
                             v: CGVector(dx: toolV.dx * 0.3 + CGFloat.random(in: -40...40), dy: max(0, toolV.dy * 0.3) + CGFloat.random(in: 20...80)))
                }
                if shake > 0.3 { AquaSound.shared.play(.shake, volume: Float(min(0.6, 0.2 + shake * 0.2)), gap: 0.2) }
            }
        case .sponge:
            target = max(-0.4, min(0.4, toolV.dx * 0.0006))
            if over {
                let moved = hypot(toolP.x - prev.x, toolP.y - prev.y)
                if moved > 0.3 {
                    let off = wipe(at: toolP, radius: 46 * FingerLift.spread, amount: min(0.5, moved * 0.022), sparkle: true)
                    if off > 0.02 && CGFloat.random(in: 0...1) < min(1, off * 3) {
                        particles.append(AquaParticle(kind: .algae, p: CGPoint(x: toolP.x + CGFloat.random(in: -30...30) * FingerLift.spread, y: toolP.y + 26 * AquariumSim.spongeScale),
                                                      v: CGVector(dx: 0, dy: 10), life: 5, size: CGFloat.random(in: 1.5...3), color: ARGB(0x6E9A47)))
                    }
                    let sp = hypot(toolV.dx, toolV.dy)
                    if sp > 120 && time - squeakAt > 0.2 {
                        squeakAt = time
                        AquaSound.shared.play(.squeak, volume: Float(min(0.7, 0.2 + sp / 1400)))
                    }
                }
            }
        case .net:
            target = max(-0.5, min(0.5, toolV.dx * -0.0008))
            if wet { scoop(at: toolP) }
            if let id = caught, let i = fish.firstIndex(where: { $0.id == id }) {
                fish[i].p = CGPoint(x: toolP.x, y: toolP.y + 8)
                fish[i].v = toolV
            }
            // fish nearby keep out of the net's way
            if wet {
                for i in fish.indices where !fish[i].caught && fish[i].id != caught {
                    if hypot(fish[i].p.x - toolP.x, fish[i].p.y - toolP.y) < 110 && hypot(toolV.dx, toolV.dy) > 420 {
                        startle(i, from: toolP)
                    }
                }
            }
        case .fish, .decor:
            target = max(-0.35, min(0.35, toolV.dx * 0.0007))
        }
        tiltV += ((target - tilt) * 70 - tiltV * 11) * dt
        tilt += tiltV * dt
    }
}

extension CGFloat {
    /// -1 or 1.
    var sign1: CGFloat { self < 0 ? -1 : 1 }
}
