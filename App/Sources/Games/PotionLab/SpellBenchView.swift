import SwiftUI

struct SpellBenchView: View {
    let exit: () -> Void
    @State private var bench = SpellBench()
    @State private var laboratory = ProcessInfo.processInfo.arguments.contains("-potionDemo")
    @State private var touching = false
    @State private var eventTime = Date()
    @State private var tip = "Choose a spell ingredient"

    var body: some View {
        if laboratory {
            PotionLabView(exit: { laboratory = false })
        } else {
            GeometryReader { geo in
                let map = PMap(size:geo.size)
                ZStack {
                    TimelineView(.animation(minimumInterval:1.0/30)) { timeline in
                        Canvas(opaque:true) { ctx, _ in
                            bench.step(timeline.date)
                            PotionPainter.drawBackdrop(ctx,map:map,sim:bench.sim)
                            var g=ctx
                            g.translateBy(x:map.ox,y:map.oy)
                            g.scaleBy(x:map.s,y:map.s)
                            SpellBenchArt.draw(g,bench)
                        }
                    }.contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance:0).onChanged { value in
                        let p=map.design(value.location), now=Date()
                        if !touching { touching=true; bench.begin(p) }
                        else { bench.move(p,dt:CGFloat(now.timeIntervalSince(eventTime))) }
                        eventTime=now
                    }.onEnded { value in
                        let p=map.design(value.location), end=map.design(value.predictedEndLocation)
                        bench.end(p,fling:CGVector(dx:(end.x-p.x)*4,dy:(end.y-p.y)*4))
                        touching=false
                        tip = bench.coatNext ? "Touch a toy to enchant it" : (bench.chosen.isEmpty ? "Choose a spell ingredient" : (bench.chosen != bench.brewed ? "Swirl the flask" : "Pull and release the toy"))
                    })
                    ZStack {
                        HomeButton(action:exit).position(x:60,y:55)
                        Text(tip).font(.system(size:23,weight:.bold,design:.rounded))
                            .padding(.vertical,10).padding(.horizontal,18)
                            .foregroundStyle(Theme.ink).background(.ultraThinMaterial,in:Capsule())
                            .position(x:450,y:53).allowsHitTesting(false)
                        PlayPrompt(title:"Unicorn lab",actionSymbol:"arrow.right",action:{ laboratory=true }) {
                            Image(systemName:"sparkles")
                        }.position(x:869,y:54)
                        Button {
                            bench.rinse(); tip="Choose a spell ingredient"
                        } label: {
                            Label("Rinse",systemImage:"drop.fill").font(.system(size:20,weight:.bold,design:.rounded))
                                .padding(13).background(.white,in:Capsule())
                        }.buttonStyle(Squish()).position(x:916,y:763)
                    }.frame(width:1024,height:834).scaleEffect(map.s)
                        .position(x:geo.size.width/2,y:geo.size.height/2)
                }
            }.ignoresSafeArea()
        }
    }
}

enum SpellBenchArt {
    static func draw(_ g: GraphicsContext, _ b: SpellBench) {
        let t=CGFloat(b.sim.time)
        var flask=g
        flask.translateBy(x:262,y:700)
        flask.scaleBy(x:0.77,y:0.77)
        flask.translateBy(x:-512,y:-700)
        PotionPainter.benchFlask(flask,b.sim,liquid:b.liquid,time:t)
        for ingredient in BenchIngredient.allCases {
            jar(g,ingredient,selected:b.chosen.contains(ingredient),time:t)
        }
        if let (ingredient,at)=b.poured {
            let k=CGFloat(b.sim.time-at)/0.52
            if k>=0 && k<1 {
                let x=ingredient.center.x+(262-ingredient.center.x)*k
                let y=ingredient.center.y+(350-ingredient.center.y)*k-220*sin(k * .pi)
                bead(g,ingredient,center:CGPoint(x:x,y:y),scale:0.8)
            }
        }
        bell(g,b)
        for (i,toy) in b.toys.enumerated() { drawToy(g,toy,index:i,time:t) }
        let tint=b.brewed.reduce(RGB(0.76,0.92,1)) { $0.mix($1.color,0.67) }
        var center=SpellBench.bottleSpot
        var angle: CGFloat=0
        if case .cork=b.grab { center=CGPoint(x:b.touch.x,y:b.touch.y-23); angle = -0.48 }
        let bottle=PotionBottle(id:1,r:tint.r,g:tint.g,b:tint.b,fill:b.brewed.isEmpty ? 0 : 0.82,
                                shape:PBottleShape.round.rawValue,kind:nil,magic:[:],glow:b.coatNext ? 0.9 : 0.36,sparkle:0.65)
        PotionBottlePainter.draw(g,bottle:bottle,center:center,angle:angle,scale:1.05,time:t)
        for (j,ingredient) in b.brewed.enumerated() {
            bead(g,ingredient,center:CGPoint(x:center.x+CGFloat(j*19)-CGFloat((b.brewed.count-1)*9),y:center.y+6),scale:0.44)
        }
        if case .jar(let ingredient)=b.grab { bead(g,ingredient,center:b.touch,scale:1.15) }
        for (j,ingredient) in b.chosen.enumerated() {
            bead(g,ingredient,center:CGPoint(x:239+CGFloat(j)*46,y:754),scale:1)
        }
        let age=CGFloat(b.sim.time-b.appliedAt)
        if age>=0 && age<0.8 {
            for i in 0..<14 {
                let a=CGFloat(i)*2.399
                let r=28+age*115
                let c=CGPoint(x:b.applied.x+cos(a)*r,y:b.applied.y+sin(a)*r-age*24)
                g.fill(star(c,r:2+4*(1-age)),with:.color(Theme.lemon.opacity(1-Double(age))))
            }
        }
    }

    static func jar(_ g: GraphicsContext,_ ingredient: BenchIngredient,selected: Bool,time:CGFloat) {
        let c=ingredient.center
        let art: PIngredient = ingredient == .berry ? .berries : (ingredient == .bean ? .petals : .frost)
        PotionPainter.jar(g,art,center:c,angle:0,scale:0.9,time:time) { jar, spot in
            bead(jar,ingredient,center:spot,scale:0.46)
        }
        let badge=CGRect(x:c.x-23,y:c.y-4,width:46,height:38)
        g.fill(Path(roundedRect:badge,cornerRadius:12),with:.color(selected ? Theme.lemon : Theme.cream))
        g.stroke(Path(roundedRect:badge,cornerRadius:12),with:.color(Color(hex:0xA2774E)),lineWidth:2)
        bead(g,ingredient,center:CGPoint(x:c.x,y:c.y+15),scale:0.78)
        g.draw(Text(ingredient.label).font(.system(size:14,weight:.bold,design:.rounded)).foregroundColor(Theme.ink),
               at:CGPoint(x:c.x,y:280))
    }

    static func bead(_ g: GraphicsContext,_ ing: BenchIngredient,center:CGPoint,scale:CGFloat) {
        var c=g; c.translateBy(x:center.x,y:center.y); c.scaleBy(x:scale,y:scale)
        var p=Path()
        switch ing {
        case .berry: p.addEllipse(in:CGRect(x:-13,y:-13,width:26,height:27))
        case .bean:
            p.move(to:CGPoint(x:-14,y:4))
            p.addQuadCurve(to:CGPoint(x:8,y:-13),control:CGPoint(x:-21,y:-15))
            p.addQuadCurve(to:CGPoint(x:10,y:6),control:CGPoint(x:25,y:-13))
            p.addQuadCurve(to:CGPoint(x:-14,y:4),control:CGPoint(x:-5,y:23))
        case .stone:
            p.addLines([CGPoint(x:-17,y:7),CGPoint(x:-13,y:-6),CGPoint(x:1,y:-14),CGPoint(x:13,y:-9),CGPoint(x:17,y:7),CGPoint(x:7,y:13),CGPoint(x:-12,y:12)])
            p.closeSubpath()
        }
        c.fill(p,with:.linearGradient(Gradient(colors:[ing.color.mix(RGB(1,1,1),0.58).c(),ing.color.c(),ing.color.mul(0.62,0.64,0.74).c()]),
                                      startPoint:CGPoint(x:-7,y:-13),endPoint:CGPoint(x:6,y:14)))
        c.stroke(p,with:.color(Theme.ink.opacity(0.65)),lineWidth:1.7)
        c.fill(Path(ellipseIn:CGRect(x:-7,y:-7,width:8,height:4)),with:.color(.white.opacity(0.76)))
    }

    static func star(_ c:CGPoint,r:CGFloat)->Path {
        var p=Path()
        for j in 0..<10 {
            let a=CGFloat(j) * .pi/5 - .pi/2, d=j.isMultiple(of:2) ? r : r*0.48
            let point=CGPoint(x:c.x+cos(a)*d,y:c.y+sin(a)*d)
            if j==0 { p.move(to:point) } else { p.addLine(to:point) }
        }
        p.closeSubpath()
        return p
    }

    static func drawToy(_ g:GraphicsContext,_ toy:BenchToy,index:Int,time:CGFloat) {
        let lift=max(0,SpellBench.floor-toy.radius-toy.p.y)
        let shadow=toy.radius*(1.05-min(0.61,lift/480))
        g.fill(Path(ellipseIn:CGRect(x:toy.p.x-shadow,y:SpellBench.floor-7,width:2*shadow,height:12)),
               with:.color(Theme.ink.opacity(Double(0.21-min(0.14,lift/2200)))))
        if !toy.recipe.isEmpty {
            for (j,p) in toy.trail.enumerated() where j.isMultiple(of:2) {
                let r=CGFloat(j+1)*0.42
                g.fill(star(CGPoint(x:p.x+sin(CGFloat(j)*2)*toy.radius*0.38,y:p.y),r:r),
                       with:.color((toy.recipe.last?.color.c() ?? Theme.lilac).opacity(0.51)))
            }
        }
        var c=g; c.translateBy(x:toy.p.x,y:toy.p.y)
        c.rotate(by:.radians(Double(toy.angle)))
        let squash=max(-0.24,min(0.32,toy.squash))
        c.scaleBy(x:1+squash,y:1/(1+squash))
        if index==0 {
            c.scaleBy(x:2.14,y:2.14)
            c.translateBy(x:0,y:19)
            var frog=GVisitor(kind:.frog,p:.zero,facing:1)
            frog.state = .staying; frog.seed=3
            GardenVisitorPainter.draw(c,frog,time:time,night:0)
        } else {
            let face=star(.zero,r:toy.radius)
            var shadow=c; shadow.translateBy(x:1,y:4)
            shadow.fill(face,with:.color(Color(hex:0x965C34)))
            c.fill(face,with:.linearGradient(Gradient(colors:[Color(hex:0xFFF4B7),Theme.lemon,Color(hex:0xE8A54A)]),
                                            startPoint:CGPoint(x:0,y:-toy.radius),endPoint:CGPoint(x:9,y:toy.radius)))
            c.stroke(face,with:.color(Color(hex:0xBA8242)),lineWidth:2)
            c.clip(to:face)
            for j in 0..<4 {
                var grain=Path()
                grain.move(to:CGPoint(x:-toy.radius,y:CGFloat(j*8)-15))
                grain.addQuadCurve(to:CGPoint(x:toy.radius,y:CGFloat(j*8)-18),control:CGPoint(x:2,y:CGFloat(j*8)-8))
                c.stroke(grain,with:.color(.brown.opacity(0.2)),lineWidth:1.2)
            }
        }
        if toy.floating {
            let r=toy.radius+9+sin(time*3)*1.4
            let bubble=Path(ellipseIn:CGRect(x:toy.p.x-r,y:toy.p.y-r,width:r*2,height:r*2))
            g.fill(bubble,with:.radialGradient(Gradient(colors:[.clear,.white.opacity(0.04),Theme.sky.opacity(0.35)]),
                                               center:toy.p,startRadius:r*0.42,endRadius:r))
            g.stroke(bubble,with:.color(.white.opacity(0.72)),lineWidth:2.2)
            g.fill(Path(ellipseIn:CGRect(x:toy.p.x-r*0.56,y:toy.p.y-r*0.72,width:r*0.42,height:r*0.14)),with:.color(.white.opacity(0.83)))
        }
    }

    static func bell(_ g:GraphicsContext,_ b:SpellBench) {
        let anchor = CGPoint(x:SpellBench.bell.x,y:SpellBench.bell.y-98)
        var bracket = Path()
        bracket.move(to:CGPoint(x:725,y:253)); bracket.addLine(to:CGPoint(x:725,y:219))
        bracket.addQuadCurve(to:anchor,control:CGPoint(x:717,y:208))
        g.stroke(bracket,with:.color(Color(hex:0x86663C)),style:StrokeStyle(lineWidth:8,lineCap:.round))
        var c=g
        c.translateBy(x:anchor.x,y:anchor.y)
        c.rotate(by:.radians(Double(b.bellAngle)))
        var string=Path(); string.move(to:.zero); string.addLine(to:CGPoint(x:0,y:74))
        c.stroke(string,with:.color(Color(hex:0x815732)),lineWidth:3)
        var bell=Path(); bell.move(to:CGPoint(x:-29,y:108))
        bell.addQuadCurve(to:CGPoint(x:-17,y:81),control:CGPoint(x:-17,y:95))
        bell.addQuadCurve(to:CGPoint(x:17,y:81),control:CGPoint(x:0,y:51))
        bell.addQuadCurve(to:CGPoint(x:29,y:108),control:CGPoint(x:16,y:95))
        bell.closeSubpath()
        c.fill(bell,with:.linearGradient(Gradient(colors:[.brown,Theme.lemon,.white,Color(hex:0xD89C3E)]),
                                         startPoint:CGPoint(x:-29,y:80),endPoint:CGPoint(x:29,y:100)))
        c.stroke(bell,with:.color(Color(hex:0x98602E)),lineWidth:2)
        c.fill(Path(ellipseIn:CGRect(x:-28,y:104,width:56,height:8)),with:.color(Color(hex:0x9C6732)))
        c.fill(Path(ellipseIn:CGRect(x:-5,y:104,width:10,height:12)),with:.color(Theme.lemon))
        let age=CGFloat(b.sim.time-b.bellAt)
        if age>=0 && age<0.9 {
            for i in 0..<7 {
                let a=CGFloat(i)*2.39,r=38+age*65
                c.fill(star(CGPoint(x:cos(a)*r,y:95+sin(a)*r),r:5*(1-age)),with:.color(Theme.lemon))
            }
        }
    }
}
