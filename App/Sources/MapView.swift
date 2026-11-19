import SwiftUI

// MARK: - Sparkle Path map (the home screen)

enum ChestReward {
    case backdrop(Backdrop)
    case egg
    case stars(Int)
}

struct MapView: View {
    @EnvironmentObject var game: GameState
    let editAvatar: () -> Void

    @State private var play: Play? = nil
    @State private var showCloset = ProcessInfo.processInfo.arguments.contains("-demoBoutique")
    @State private var showHouse = ProcessInfo.processInfo.arguments.contains("-demoHouse")
    @State private var showShelf = false
    @State private var showEgg = false
    @State private var chest: ChestReward? = nil
    @State private var chestStop = 0
    @State private var finishedWorld: World? = nil
    @State private var pulse = false
    @State private var jarPulse = false
    @State private var hop = false
    @State private var nudge: Int? = nil
    @State private var buddyJump = false
    @State private var appeared = false

    private var current: Int { game.adventure.stop }

    var body: some View {
        GeometryReader { geo in
            let world = Adventure.world(at: current)
            let area = CGRect(x: 80, y: 130, width: geo.size.width - 170, height: geo.size.height - 165)
            ZStack {
                LinearGradient(colors: [world.top, world.bottom], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                decor(world, size: geo.size)
                FloatingSparkles().opacity(0.8)

                trail(area)
                landmark(world, area)

                ForEach(0..<Adventure.stopsPerWorld, id: \.self) { i in
                    let s = (current / Adventure.stopsPerWorld) * Adventure.stopsPerWorld + i
                    stopView(s)
                        .position(point(i, area))
                }

                token(area)

                topBar(world)
                    .frame(maxHeight: .infinity, alignment: .top)

                if let c = chest {
                    ChestView(reward: c) { closeChest(c) }
                        .transition(.opacity)
                        .zIndex(10)
                }
                if let w = finishedWorld {
                    WorldDoneView(finished: w, next: Adventure.world(at: current)) { closeWorldParty() }
                        .transition(.opacity)
                        .zIndex(11)
                }
                if showEgg {
                    HatchView(kind: game.nextGlimmie) { finishHatch() }
                        .transition(.opacity)
                        .zIndex(12)
                }
            }
        }
        .fullScreenCover(item: $play) { p in
            DesignCanvas { GameHost(play: p) { stars in finishPlay(p, stars: stars) } }
                .environmentObject(game)
        }
        .fullScreenCover(isPresented: $showCloset) {
            DesignCanvas { BoutiqueView(onClose: { showCloset = false; afterStep() }) }
                .environmentObject(game)
        }
        .fullScreenCover(isPresented: $showHouse) {
            DesignCanvas { HouseView { showHouse = false } }
                .environmentObject(game)
        }
        .fullScreenCover(isPresented: $showShelf) {
            DesignCanvas { ShelfView { showShelf = false } }
                .environmentObject(game)
        }
        .onAppear(perform: appear)
    }

    // MARK: Layout

    private func point(_ i: Int, _ area: CGRect) -> CGPoint {
        let s = Adventure.spots[i]
        return CGPoint(x: area.minX + s.x * area.width, y: area.minY + s.y * area.height)
    }

    private func trail(_ area: CGRect) -> some View {
        var pts = (0..<Adventure.stopsPerWorld).map { point($0, area) }
        let l = Adventure.landmarkSpot
        pts.append(CGPoint(x: area.minX + l.x * area.width, y: area.minY + l.y * area.height))
        var p = Path()
        p.move(to: pts[0])
        for i in 1..<pts.count {
            let mid = CGPoint(x: (pts[i - 1].x + pts[i].x) / 2, y: (pts[i - 1].y + pts[i].y) / 2)
            p.addQuadCurve(to: mid, control: pts[i - 1])
        }
        p.addLine(to: pts[pts.count - 1])
        let world = Adventure.world(at: current)
        return ZStack {
            p.stroke(Color.white.opacity(0.9), style: StrokeStyle(lineWidth: 46, lineCap: .round, lineJoin: .round))
            p.stroke(world.path, style: StrokeStyle(lineWidth: 34, lineCap: .round, lineJoin: .round))
            p.stroke(Color.white.opacity(0.85), style: StrokeStyle(lineWidth: 6, lineCap: .round, dash: [2, 22]))
        }
        .shadow(color: Theme.ink.opacity(0.15), radius: 6, y: 4)
        .allowsHitTesting(false)
    }

    private func landmark(_ world: World, _ area: CGRect) -> some View {
        let l = Adventure.landmarkSpot
        return Text(world.landmark)
            .font(.system(size: 120))
            .shadow(color: .white, radius: pulse ? 24 : 10)
            .scaleEffect(pulse ? 1.05 : 0.97)
            .position(x: area.minX + l.x * area.width, y: area.minY + l.y * area.height - 30)
            .onTapGesture {
                Sound.shared.play(.sparkle, volume: 0.6)
                Sound.shared.say("That's \(world.name)! Keep going to get there!")
            }
    }

    private func decor(_ world: World, size: CGSize) -> some View {
        let spots: [(CGFloat, CGFloat)] = [(0.04, 0.3), (0.96, 0.4), (0.97, 0.74), (0.24, 0.7), (0.86, 0.95), (0.4, 0.97)]
        return ZStack {
            ForEach(0..<min(spots.count, world.decor.count), id: \.self) { i in
                Text(world.decor[i])
                    .font(.system(size: 56))
                    .opacity(0.75)
                    .rotationEffect(.degrees(pulse ? 6 : -6))
                    .position(x: spots[i].0 * size.width, y: spots[i].1 * size.height)
            }
        }
        .allowsHitTesting(false)
    }

    private func stopView(_ s: Int) -> some View {
        let kind = Adventure.kind(at: s)
        let done = s < current
        let now = s == current
        let size: CGFloat = now ? 112 : 86
        return ZStack {
            Circle()
                .fill(done ? AnyShapeStyle(LinearGradient(colors: [Color(red: 1, green: 0.95, blue: 0.62), Theme.gold], startPoint: .top, endPoint: .bottom))
                           : AnyShapeStyle(now ? kind.color : Color.white.opacity(0.75)))
                .overlay(Circle().stroke(Color.white, lineWidth: now ? 7 : 4))
                .shadow(color: now ? kind.color : Theme.ink.opacity(0.2), radius: now ? (pulse ? 24 : 10) : 4, y: 3)
            Text(kind.emoji)
                .font(.system(size: now ? 56 : 40))
                .opacity(done || now ? 1 : 0.5)
            if done {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(Color(red: 0.3, green: 0.78, blue: 0.45))
                    .background(Circle().fill(Color.white).padding(2))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(now && pulse ? 1.08 : 1)
        .offset(x: nudge == s ? 12 : 0)
        .animation(.spring(response: 0.15, dampingFraction: 0.2), value: nudge)
        .onTapGesture { tapStop(s) }
    }

    private func token(_ area: CGRect) -> some View {
        let p = point(current % Adventure.stopsPerWorld, area)
        return ZStack(alignment: .bottomTrailing) {
            DollView(avatar: game.avatar, outfit: game.outfit, happy: hop)
                .frame(height: 170)
                .onTapGesture {
                    Sound.shared.play(.boing, volume: 0.5)
                    Sound.shared.say(["Let's go!", "Adventure time!", "Wheee!", "Tap the glowing circle!"].randomElement()!)
                    hopOnce()
                }
            GlimmieView(kind: game.buddy)
                .frame(width: 84, height: 84)
                .offset(x: 52, y: 6)
                .scaleEffect(buddyJump ? 1.2 : 1)
                .animation(.spring(response: 0.25, dampingFraction: 0.4), value: buddyJump)
                .onTapGesture(perform: nextBuddy)
        }
        .offset(y: hop ? -28 : 0)
        .animation(.spring(response: 0.25, dampingFraction: 0.45), value: hop)
        .position(x: p.x - 8, y: p.y - 112)
    }

    private func topBar(_ world: World) -> some View {
        HStack(spacing: 16) {
            CandyButton(symbol: "face.smiling", color: Color(red: 1, green: 0.85, blue: 0.92), size: 66) { editAvatar() }
            StarJar(stars: game.stars, pulse: jarPulse)
            Spacer()
            Text(world.name)
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: Theme.ink.opacity(0.5), radius: 0, x: 2, y: 2)
                .padding(.horizontal, 26).padding(.vertical, 10)
                .background(Capsule().fill(world.path).overlay(Capsule().stroke(Color.white, lineWidth: 4)))
                .onTapGesture { Sound.shared.say(world.name) }
            Spacer()
            closetButton
            CandyButton(symbol: "house.fill", color: Color(red: 1, green: 0.8, blue: 0.62), size: 66) { showHouse = true }
            CandyButton(symbol: "square.grid.2x2.fill", color: Theme.lilac, size: 66) { showShelf = true }
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
    }

    private var closetButton: some View {
        Button {
            Sound.shared.play(.tap, volume: 0.6)
            showCloset = true
        } label: {
            ZStack {
                Circle().fill(Color(red: 1, green: 0.7, blue: 0.86))
                    .overlay(Circle().fill(LinearGradient(colors: [.white.opacity(0.7), .clear], startPoint: .top, endPoint: .center)).padding(4))
                    .shadow(color: Theme.ink.opacity(0.25), radius: 6, y: 4)
                Art.image("I_dress_aline").resizable().aspectRatio(contentMode: .fit).padding(10)
            }
            .frame(width: 66, height: 66)
        }
        .buttonStyle(SquishStyle())
    }

    // MARK: Actions

    private func appear() {
        guard !appeared else { return }
        appeared = true
        Art.preload()
        withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { pulse = true }
        if let demo = demoPlay() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { start(stop: current, kind: demo, advances: false) }
            return
        }
        if game.eggWaiting {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { withAnimation { showEgg = true } }
            return
        }
        if showCloset || showHouse { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            Sound.shared.say(current == 0 ? "Let's go on a sparkle adventure! Tap the glowing circle to play!" : nextLine())
        }
    }

    /// `-demoPlay catchStars` (or dress, memory, bubbles, dance, chest) opens that stop, for screenshots.
    private func demoPlay() -> StopKind? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-demoPlay"), i + 1 < args.count else { return nil }
        return StopKind(rawValue: args[i + 1])
    }

    private func nextLine() -> String {
        let k = Adventure.kind(at: current)
        if k == .chest { return "A treasure chest! Tap it!" }
        return "Next up: " + k.title + "!"
    }

    private func tapStop(_ s: Int) {
        if s > current {
            nudge = s
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { nudge = nil }
            Sound.shared.play(.boing, volume: 0.5)
            Sound.shared.say("Not yet! Play the glowing one first!")
            return
        }
        let kind = Adventure.kind(at: s)
        if s < current, kind == .chest {
            Sound.shared.play(.tap, volume: 0.5)
            Sound.shared.say("You already opened this treasure!")
            return
        }
        start(stop: s, kind: kind, advances: s == current)
    }

    private func start(stop: Int, kind: StopKind, advances: Bool) {
        Sound.shared.play(.whoosh, volume: 0.7)
        if kind == .chest {
            chestStop = stop
            withAnimation { chest = reward(for: stop) }
        } else {
            play = Play(kind: kind, stop: stop, advances: advances)
        }
    }

    private func finishPlay(_ p: Play, stars: Int) {
        play = nil
        guard stars > 0 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            jarPulse = true
            Sound.shared.play(.ding)
            game.addStars(stars)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { jarPulse = false }
            if p.advances, p.stop == current { advance() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { afterStep() }
        }
    }

    private func advance() {
        Sound.shared.play(.pop)
        hopOnce()
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { game.adventure.stop += 1 }
    }

    /// What comes next after a game or chest: the egg if one is waiting, else a hint about the next stop.
    private func afterStep() {
        if game.eggWaiting {
            withAnimation { showEgg = true }
        } else {
            Sound.shared.say(nextLine(), interrupt: false)
        }
    }

    private func hopOnce() {
        hop = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { hop = false }
    }

    private func nextBuddy() {
        let owned = game.owned.sorted()
        guard let i = owned.firstIndex(of: game.buddy) else { return }
        let next = owned[(i + 1) % owned.count]
        game.adventure.buddy = next
        buddyJump = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { buddyJump = false }
        Sound.shared.play(.ding, volume: 0.7)
        Sound.shared.say(owned.count > 1 ? "Hi! I'm \(Glimmies.all[next].name)! Let's play!" : "I'm \(Glimmies.all[next].name)! Hatch more eggs to find my friends!")
    }

    private func reward(for stop: Int) -> ChestReward {
        if Adventure.isWorldEnd(stop), !game.eggWaiting, game.nextGlimmie != nil { return .egg }
        if let b = Backdrops.all.first(where: { !game.adventure.backdrops.contains($0.id) }) { return .backdrop(b) }
        return .stars(3)
    }

    private func closeChest(_ r: ChestReward) {
        switch r {
        case .backdrop(let b):
            if !game.adventure.backdrops.contains(b.id) { game.adventure.backdrops.append(b.id) }
            game.adventure.backdrop = b.id
        case .egg:
            game.eggWaiting = true
        case .stars(let n):
            game.addStars(n)
        }
        withAnimation { chest = nil }
        guard chestStop == current else { afterStep(); return }
        let worldDone = Adventure.isWorldEnd(current)
        let old = Adventure.world(at: current)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            advance()
            if worldDone {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { withAnimation { finishedWorld = old } }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { afterStep() }
            }
        }
    }

    private func closeWorldParty() {
        withAnimation { finishedWorld = nil }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { afterStep() }
    }

    private func finishHatch() {
        if let k = game.nextGlimmie {
            game.owned.append(k)
            game.adventure.buddy = k
        }
        game.eggWaiting = false
        withAnimation { showEgg = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            Sound.shared.say("Your new friend will play with you! " + nextLine(), interrupt: false)
        }
    }
}

// MARK: - Treasure chest

struct ChestView: View {
    let reward: ChestReward
    let onDone: () -> Void

    @State private var taps = 0
    @State private var wobble = 0.0
    @State private var open = false
    @State private var flash = false
    @State private var appear = false
    @State private var bursts = 0

    var body: some View {
        ZStack {
            Color(red: 0.25, green: 0.12, blue: 0.3).opacity(0.55).ignoresSafeArea()
            RadialGradient(colors: [Color.white.opacity(0.8), .clear], center: .center, startRadius: 10, endRadius: 380)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            if !open {
                VStack(spacing: 10) {
                    Text("🎁")
                        .font(.system(size: 230))
                        .rotationEffect(.degrees(wobble), anchor: .bottom)
                        .scaleEffect(appear ? 1 : 0.2)
                        .onTapGesture(perform: tapChest)
                    HStack(spacing: 14) {
                        ForEach(0..<3, id: \.self) { i in
                            Circle().fill(i < taps ? Theme.gold : Color.white.opacity(0.5))
                                .frame(width: 26, height: 26)
                        }
                    }
                }
                ForEach(0..<bursts, id: \.self) { _ in SparkleBurst(count: 12, radius: 200) }
            } else {
                VStack(spacing: 18) {
                    revealed
                        .transition(.scale(scale: 0.1).combined(with: .opacity))
                    CandyButton(symbol: "checkmark", color: Color(red: 0.6, green: 0.92, blue: 0.68), size: 96) { onDone() }
                }
                Confetti()
                SparkleBurst(count: 24, radius: 320)
            }
            Color.white.opacity(flash ? 0.95 : 0).ignoresSafeArea().allowsHitTesting(false)
        }
        .onAppear {
            Sound.shared.say("A treasure chest! Tap it three times!")
            withAnimation(.spring(response: 0.6, dampingFraction: 0.55)) { appear = true }
        }
    }

    @ViewBuilder private var revealed: some View {
        switch reward {
        case .backdrop(let b):
            VStack(spacing: 12) {
                BackdropView(backdrop: b)
                    .frame(width: 460, height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 34))
                    .overlay(RoundedRectangle(cornerRadius: 34).stroke(Color.white, lineWidth: 8))
                    .shadow(color: Theme.ink.opacity(0.4), radius: 16, y: 8)
                bigLabel(b.name)
            }
        case .egg:
            VStack(spacing: 12) {
                EggView(cracks: 0).scaleEffect(1.2)
                bigLabel("A magic egg!")
            }
        case .stars(let n):
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    ForEach(0..<n, id: \.self) { _ in
                        StarShape().fill(Theme.gold).overlay(StarShape().stroke(Color.white, lineWidth: 5))
                            .frame(width: 120, height: 120)
                            .shadow(color: Theme.gold, radius: 14)
                    }
                }
                bigLabel("Bonus stars!")
            }
        }
    }

    private func bigLabel(_ s: String) -> some View {
        Text(s)
            .font(.system(size: 54, weight: .heavy, design: .rounded))
            .foregroundColor(.white)
            .shadow(color: Theme.ink.opacity(0.6), radius: 6, y: 3)
    }

    private func shake(_ amp: Double) {
        withAnimation(.easeInOut(duration: 0.08)) { wobble = amp }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { withAnimation(.easeInOut(duration: 0.1)) { wobble = -amp } }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { withAnimation(.spring(response: 0.3, dampingFraction: 0.3)) { wobble = 0 } }
    }

    private func tapChest() {
        guard !open else { return }
        taps += 1
        bursts += 1
        Sound.shared.tapHaptic()
        shake(8 + Double(taps) * 5)
        Sound.shared.play(.crack, volume: 0.7)
        if taps < 3 {
            Sound.shared.say(taps == 1 ? "Again!" : "One more!")
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeIn(duration: 0.15)) { flash = true }
            Sound.shared.play(.hatch)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.5)) { open = true }
                withAnimation(.easeOut(duration: 0.6)) { flash = false }
                Sound.shared.play(.fanfare)
                switch reward {
                case .backdrop(let b): Sound.shared.say("Wow! A new stage! \(b.name)! Find it in your closet!")
                case .egg: Sound.shared.say("A magic egg! A new Glimmie is coming!")
                case .stars: Sound.shared.say("Bonus stars for your jar!")
                }
            }
        }
    }
}

// MARK: - World finished

struct WorldDoneView: View {
    let finished: World
    let next: World
    let onDone: () -> Void
    @State private var appear = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [next.top, next.bottom], startPoint: .top, endPoint: .bottom)
                .opacity(0.92)
                .ignoresSafeArea()
            VStack(spacing: 20) {
                HStack(spacing: 40) {
                    Text(finished.landmark).font(.system(size: 130))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 60, weight: .heavy))
                        .foregroundColor(.white)
                    Text(next.landmark).font(.system(size: 170))
                        .scaleEffect(appear ? 1 : 0.3)
                }
                Text(next.name)
                    .font(.system(size: 72, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: Theme.ink.opacity(0.6), radius: 0, x: 4, y: 4)
                CandyButton(symbol: "checkmark", color: Color(red: 0.6, green: 0.92, blue: 0.68), size: 100) { onDone() }
            }
            .scaleEffect(appear ? 1 : 0.7)
            Confetti()
        }
        .onAppear {
            Sound.shared.play(.fanfare)
            Sound.shared.say("Hooray! You finished \(finished.name)! Next stop: \(next.name)!")
            withAnimation(.spring(response: 0.6, dampingFraction: 0.55)) { appear = true }
        }
    }
}
