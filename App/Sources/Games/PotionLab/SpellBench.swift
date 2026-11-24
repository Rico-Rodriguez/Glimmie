import SwiftUI

enum BenchIngredient: Int, Codable, CaseIterable {
    case berry, bean, stone
    var color: RGB {
        switch self {
        case .berry: return RGB(hex:"#8299FF")
        case .bean: return RGB(hex:"#83CF86")
        case .stone: return RGB(hex:"#B4A0C3")
        }
    }
    var center: CGPoint { CGPoint(x:CGFloat(rawValue)*98+68,y:204) }
    var label: String { ["Bubble berry", "Spring bean", "Heavy pebble"][rawValue] }
}

struct BenchToy {
    var p: CGPoint
    var radius: CGFloat
    var v = CGVector.zero
    var recipe: [BenchIngredient] = []
    var angle: CGFloat = 0
    var spin: CGFloat = 0
    var squash: CGFloat = 0
    var springSpeed: CGFloat = 0
    var trail: [CGPoint] = []
    var floating: Bool { recipe.contains(.berry) && !recipe.contains(.stone) }
    var heavy: Bool { recipe.contains(.stone) && !recipe.contains(.berry) }
}

final class SpellBench {
    let sim = PotionSim(save:nil)
    let liquid = PotionLiquid()
    static let bottleSpot = CGPoint(x:485,y:638)
    static let bell = CGPoint(x:690,y:317)
    static let floor: CGFloat = 700
    var chosen: [BenchIngredient] = []
    var brewed: [BenchIngredient] = []
    var toys = [
        BenchToy(p:CGPoint(x:686,y:653),radius:47),
        BenchToy(p:CGPoint(x:817,y:675),radius:25),
        BenchToy(p:CGPoint(x:894,y:668),radius:32),
        BenchToy(p:CGPoint(x:956,y:678),radius:22)
    ]
    enum Grab { case jar(BenchIngredient), toy(Int), cork, stir, idle }
    var grab = Grab.idle
    var touch = CGPoint.zero
    var began = CGPoint.zero
    var lastDate: Date?
    var bellAngle: CGFloat = 0
    var bellSpeed: CGFloat = 0
    var bellAt = -10.0
    var appliedAt = -10.0
    var applied = CGPoint.zero
    var poured: (BenchIngredient, Double)?
    var coatNext = false
    private var trailTime: CGFloat = 0
    private var lastContact = -10.0

    init(saved: [BenchIngredient]? = GameStorage.load([BenchIngredient].self,game:PotionSim.gameID,file:"toy-brew.json")) {
        sim.demo = true
        sim.heat = 1
        if let saved {
            chosen = Array(saved.prefix(2))
            brewed = chosen
            if let tint = chosen.last?.color { dye(tint) }
        }
    }

    func dye(_ tint: RGB) {
        let hit = CGPoint(x:502,y:sim.level+25)
        sim.inject(hit,color:tint,amount:30,density:2,radius:3)
        sim.push(hit,CGVector(dx:50,dy:180),radius:36)
    }

    func select(_ ingredient: BenchIngredient) {
        if let i = chosen.firstIndex(of:ingredient) { chosen.remove(at:i) }
        else {
            if chosen.count >= 2 { chosen.removeFirst() }
            chosen.append(ingredient)
        }
        poured = (ingredient, sim.time)
        coatNext = false
        dye(ingredient.color)
        PotionSound.shared.play(.plop)
    }

    func brew() {
        guard !chosen.isEmpty else { return }
        brewed = chosen
        coatNext = true
        GameStorage.save(brewed,game:PotionSim.gameID,file:"toy-brew.json")
        PotionSound.shared.play(.cork)
    }

    func coat(_ i: Int) {
        toys[i].recipe = brewed
        toys[i].springSpeed = 3.7
        toys[i].v.dy = toys[i].floating ? -125 : -78
        if toys[i].recipe.contains(.bean) && !toys[i].floating { toys[i].v.dy = -365 }
        applied = toys[i].p
        appliedAt = sim.time
        PotionSound.shared.play(.magic)
    }

    func step(_ now: Date) {
        let dt = CGFloat(min(1.0/30,max(0,now.timeIntervalSince(lastDate ?? now))))
        lastDate = now
        sim.step(now)
        sim.cues.removeAll(keepingCapacity:true)
        advance(dt)
    }

    func advance(_ dt: CGFloat) {
        guard dt > 0 else { return }
        bellSpeed += (-16*bellAngle-1.7*bellSpeed)*dt
        bellAngle += bellSpeed*dt
        trailTime += dt
        let sample = trailTime >= 0.038
        if sample { trailTime = 0 }
        for i in toys.indices {
            if case .toy(let j) = grab, i == j { continue }
            var toy = toys[i]
            let ground = Self.floor-toy.radius
            let accel: CGFloat = toy.floating ? (460-toy.p.y)*7.5-toy.v.dy*1.6 : (toy.heavy ? 1420 : 820)
            toy.v.dy += accel*dt
            toy.v.dx *= exp(-dt*(toy.p.y >= ground-1 ? 3.2 : 0.45))
            toy.p.x += toy.v.dx*dt
            toy.p.y += toy.v.dy*dt
            toy.angle += toy.spin*dt
            toy.spin *= exp(-2.2*dt)
            toy.springSpeed += (-95*toy.squash-9*toy.springSpeed)*dt
            toy.squash += toy.springSpeed*dt
            if toy.p.y >= ground {
                let impact = toy.v.dy
                toy.p.y = ground
                let restitution: CGFloat = toy.recipe.contains(.bean) ? (toy.heavy ? 0.52 : 0.82) : 0.21
                toy.v.dy = impact>55 ? -impact*restitution : 0
                if impact>90 {
                    toy.springSpeed = min(4.5,impact/145)
                    if sim.time-lastContact>0.16 {
                        PotionSound.shared.play(toy.recipe.contains(.bean) ? .boing : .plop,volume:Float(min(0.65,impact/720)))
                        lastContact = sim.time
                    }
                }
                if i==0 { toy.angle *= exp(-dt*8) }
            }
            if toy.p.x < 491+toy.radius || toy.p.x > 1014-toy.radius {
                toy.p.x = min(1014-toy.radius,max(491+toy.radius,toy.p.x))
                toy.v.dx *= -0.72
            }
            if toy.p.y < 119+toy.radius { toy.p.y = 119+toy.radius; toy.v.dy = abs(toy.v.dy)*0.57 }
            if hypot(toy.p.x-Self.bell.x,toy.p.y-Self.bell.y)<toy.radius+29 && sim.time-bellAt>0.55 && hypot(toy.v.dx,toy.v.dy)>80 {
                bellSpeed += toy.p.x<Self.bell.x ? 4 : -4
                bellAt = sim.time
                toy.v.dy = abs(toy.v.dy)*0.38
                Sound.shared.play(.ding)
            }
            if sample {
                toy.trail.append(toy.p)
                if toy.trail.count>10 { toy.trail.removeFirst() }
            }
            toys[i] = toy
        }
        collide()
    }

    private func collide() {
        for i in toys.indices {
            for j in toys.indices where j>i {
                let dx = toys[j].p.x-toys[i].p.x, dy = toys[j].p.y-toys[i].p.y
                let distance = max(0.01,hypot(dx,dy))
                let overlap = toys[i].radius+toys[j].radius-distance
                guard overlap>0 else { continue }
                let nx = dx/distance, ny = dy/distance
                let massI = toys[i].radius*(toys[i].heavy ? 3 : 1)
                let massJ = toys[j].radius*(toys[j].heavy ? 3 : 1)
                var share = massJ/(massI+massJ)
                if case .toy(let held) = grab { if held==i { share=0 }; if held==j { share=1 } }
                let speed = (toys[i].v.dx-toys[j].v.dx)*nx+(toys[i].v.dy-toys[j].v.dy)*ny
                let impulse = max(0,speed)*1.4
                toys[i].p.x -= nx*overlap*share
                toys[i].p.y -= ny*overlap*share
                toys[j].p.x += nx*overlap*(1-share)
                toys[j].p.y += ny*overlap*(1-share)
                toys[i].v.dx -= nx*impulse*share
                toys[i].v.dy -= ny*impulse*share
                toys[j].v.dx += nx*impulse*(1-share)
                toys[j].v.dy += ny*impulse*(1-share)
            }
        }
    }

    func toy(at p: CGPoint) -> Int? {
        toys.indices.reversed().first { hypot(toys[$0].p.x-p.x,toys[$0].p.y-p.y)<toys[$0].radius+24 }
    }

    func begin(_ p: CGPoint) {
        began=p; touch=p
        if let jar = BenchIngredient.allCases.first(where:{ hypot($0.center.x-p.x,$0.center.y-p.y)<54 }) { grab = .jar(jar) }
        else if hypot(p.x-Self.bottleSpot.x,p.y-Self.bottleSpot.y)<48 { grab = .cork }
        else if let i = toy(at:p) {
            if coatNext { coat(i); coatNext=false }
            grab = .toy(i)
        } else if (65...457).contains(p.x) && (300...690).contains(p.y) {
            grab = .stir
            sim.spoonHeld=true
        } else { grab = .idle }
    }

    func move(_ p: CGPoint, dt: CGFloat) {
        let before=touch
        touch=p
        switch grab {
        case .stir:
            sim.spoonTarget=CGPoint(x:max(390,min(630,512+(p.x-262)/0.77)),y:max(350,min(600,700+(p.y-700)/0.77)))
            let v = CGVector(dx:(p.x-before.x)/max(0.008,dt),dy:(p.y-before.y)/max(0.008,dt))
            sim.push(sim.spoonTarget,CGVector(dx:max(-360,min(360,v.dx)),dy:max(-360,min(360,v.dy))),radius:60)
        case .toy(let i):
            let next=CGPoint(x:max(491+toys[i].radius,min(1014-toys[i].radius,p.x)),y:max(145,min(Self.floor-toys[i].radius,p.y)))
            toys[i].v = CGVector(dx:(next.x-toys[i].p.x)/max(0.012,dt),dy:(next.y-toys[i].p.y)/max(0.012,dt))
            toys[i].p=next
        default: break
        }
    }

    func end(_ p: CGPoint, fling: CGVector) {
        switch grab {
        case .jar(let ingredient): select(ingredient)
        case .stir: sim.spoonHeld=false; brew()
        case .cork:
            if !chosen.isEmpty && chosen != brewed { brew() }
            if !brewed.isEmpty {
                if let i=toy(at:p) { coat(i); coatNext=false }
                else { coatNext=true }
            }
        case .toy(let i):
            let spring: CGFloat = toys[i].floating && toys[i].recipe.contains(.bean) ? max(0,toys[i].p.y-460)*4.2 : 0
            toys[i].v = CGVector(dx:max(-900,min(900,fling.dx)),dy:max(-1100,min(900,fling.dy-spring)))
            toys[i].spin=toys[i].v.dx/165
        default: break
        }
        grab = .idle
    }

    func rinse() {
        coatNext=false; chosen=[]; brewed=[]
        for i in toys.indices { toys[i].recipe=[] }
        sim.dr = sim.dr.map { _ in 0 }; sim.dg = sim.dr; sim.db = sim.dr; sim.da = sim.dr
        sim.version += 1
        GameStorage.save([BenchIngredient](),game:PotionSim.gameID,file:"toy-brew.json")
        PotionSound.shared.play(.splash)
    }
}
