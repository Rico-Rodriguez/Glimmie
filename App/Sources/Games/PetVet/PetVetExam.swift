import Combine
import SwiftUI

// MARK: - Exam room

/// Where the patient sits inside the 1024 x 834 stage.
struct VetLayout {
    let size: CGSize
    static let k: CGFloat = 0.86
    static let bottomMargin: CGFloat = 50
    var patient: CGSize { CGSize(width: 600 * VetLayout.k, height: 660 * VetLayout.k) }
    var origin: CGPoint { CGPoint(x: size.width / 2 - patient.width / 2, y: size.height - patient.height - VetLayout.bottomMargin) }
    func toRoom(_ p: CGPoint) -> CGPoint { CGPoint(x: origin.x + p.x * VetLayout.k, y: origin.y + p.y * VetLayout.k) }
    func toPatient(_ p: CGPoint) -> CGPoint { CGPoint(x: (p.x - origin.x) / VetLayout.k, y: (p.y - origin.y) / VetLayout.k) }
}

private enum VetRightTab: String, CaseIterable {
    case washBandage
    case pamper
}

private struct VetParticle: Identifiable {
    enum Kind { case prop(String), sparkle(Color), heart(Color), drop, confetti(Color) }
    let id = UUID()
    let kind: Kind
    let pos: CGPoint
    let vel: CGVector
    let born: Date
    let life: Double
    var gravity: CGFloat = 0
    var spin: Double = 0
    var scale: CGFloat = 1
}

struct VetExamView: View {
    @ObservedObject var clinic: VetClinic
    let animal: String
    let onExit: () -> Void
    let onBack: () -> Void

    static let examTools: [VetTool] = [
        .thermometer, .stethoscope, .syrup, .tissue,
        .icepack, .toothbrush, .cream, .tweezers,
    ]
    static let washBandageTools: [VetTool] = [
        .sponge, .shower, .towel, .comb,
        .brush, .swab, .bandage, .wrap,
    ]
    static let pamperTools: [VetTool] = [
        .treat, .bow, .spray, .feather,
    ]

    /// Boost applied during `AutoTool.work` (1.3s) so even `.hold(1.6)` and `.rub(240)` complete on a single tap.
    static let autoHoldBoost: Double = 1.65
    static let autoRubBoost: CGFloat = 1.25

    @State private var visit: VetVisit
    @State private var stickers: [VetSticker]
    @State private var tool: VetTool?
    @State private var finger: CGPoint = .zero
    @State private var lastTip: CGPoint?
    @State private var consumed = false
    /// A tool tapped on a tray: tapping the patient runs it on that spot, tapping elsewhere puts it down.
    @State private var picked: VetTool?
    @State private var pickedDragging = false
    @State private var auto = AutoTool()
    @State private var dragFrom: CGPoint?
    @State private var usedThisDrag = false
    @State private var reaction: VetFace?
    @State private var reactionUntil = Date.distantPast
    @State private var bounceAt = Date.distantPast
    @State private var bounceAmp: CGFloat = 0.05
    @State private var particles: [VetParticle] = []
    @State private var healedAt: Date?
    @State private var nextSneeze = Date().addingTimeInterval(2.5)
    @State private var working: Int?
    @State private var workingUntil = Date.distantPast
    @State private var bowColor = Int.random(in: 0..<6)
    @State private var lastFx: [String: Date] = [:]
    @State private var rightTab: VetRightTab
    @State private var hintTool: VetTool?
    @State private var hintToolUntil = Date.distantPast
    @State private var peelingIndex: Int?
    @State private var peelingOffset: CGSize = .zero
    @State private var bareTouchActive = false
    @State private var showBook = false
    @State private var bellPulse = false
    @State private var effects: VetFX

    private let timer = Timer.publish(every: 1.0 / 30, on: .main, in: .common).autoconnect()
    private let stageSize = CGSize(width: GameChromeLayout.width, height: GameChromeLayout.height)

    init(clinic: VetClinic, animal: String, onExit: @escaping () -> Void, onBack: @escaping () -> Void) {
        self.clinic = clinic
        self.animal = animal
        self.onExit = onExit
        self.onBack = onBack
        let initialVisit = clinic.visit(animal)
        _visit = State(initialValue: initialVisit)
        _stickers = State(initialValue: clinic.stickers(animal))
        _rightTab = State(initialValue: initialVisit.healed ? .pamper : .washBandage)
        let f = VetFX()
        if let a = VetArt.shared.animals[animal] { f.setUp(a) }
        _effects = State(initialValue: f)
    }

    private var layout: VetLayout { VetLayout(size: stageSize) }

    var body: some View {
        ZStack {
            GameStage(background: {
                Canvas { ctx, s in VetDraw.room("exam", size: s, in: ctx) }
            }) {
                ZStack {
                    TimelineView(.animation(minimumInterval: 1.0 / 60, paused: showBook)) { tl in
                        Canvas { ctx, _ in draw(ctx, now: tl.date) }
                    }
                    .allowsHitTesting(false)

                    bareHandLayer

                    if let pk = picked {
                        pickedToolLayer(pk)
                    }

                    HStack(alignment: .center) {
                        leftExamTray
                        Spacer()
                        rightToolsTray
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 96)
                    .padding(.bottom, VetLayout.bottomMargin)

                    GameTopBar(
                        gameID: PetVetGame.id,
                        showStickerBook: true,
                        showCoins: true,
                        onExit: {
                            save()
                            onExit()
                        },
                        onStickerBook: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                showBook = true
                            }
                        },
                        center: {
                            ailmentHearts
                        },
                        trailing: {
                            HStack(spacing: 12) {
                                newCheckupButton
                                lobbyButton
                            }
                        }
                    )

                    StickerToast(game: PetVetGame.id, target: GameChromeLayout.stickerTarget)

                    if let t = tool, let art = VetArt.shared.tools[t] {
                        heldToolView(tool: t, art: art)
                    }
                }
                .frame(width: GameChromeLayout.width, height: GameChromeLayout.height)
                .coordinateSpace(name: "exam")
                .coinPurse(game: PetVetGame.id)
            }

            if showBook {
                StickerBookView(game: PetVetGame.id) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showBook = false
                    }
                }
                .transition(.opacity)
                .zIndex(5)
            }
        }
        .ignoresSafeArea()
        .defersSystemGestures(on: .bottom)
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("-vetFX") {
                effects.demo(toRoom: layout.toRoom)
            }
            holdDemoTool(layout)
            withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                bellPulse = true
            }
        }
        .onReceive(timer) { _ in
            guard !showBook else { return }
            tick()
        }
        .onDisappear {
            if auto.running { auto.cancel() }
            save()
        }
    }

    private func pickedToolLayer(_ pk: VetTool) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("exam"))
                    .onChanged { v in
                        if !pickedDragging && !ToolTap.isTap(v.translation) {
                            pickedDragging = true
                        }
                        if pickedDragging {
                            if auto.running { auto.cancel() }
                            drag(pk, v.location)
                        }
                    }
                    .onEnded { v in
                        if pickedDragging {
                            drop(pk, v.location)
                        } else {
                            autoDo(pk, at: v.location)
                        }
                        pickedDragging = false
                    }
            )
    }

    // MARK: Bare-hand tickle & peelable bows/bandages

    private var bareHandLayer: some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("exam"))
                    .onChanged { v in
                        if !bareTouchActive {
                            bareTouchActive = true
                            let pt = layout.toPatient(v.location)
                            peelingIndex = hitStickerIndex(at: pt)
                            peelingOffset = .zero
                        }
                        if peelingIndex != nil {
                            peelingOffset = v.translation
                        }
                    }
                    .onEnded { v in
                        let idx = peelingIndex
                        peelingIndex = nil
                        peelingOffset = .zero
                        bareTouchActive = false

                        if let idx, stickers.indices.contains(idx) {
                            peelSticker(at: idx, dragTranslation: v.translation)
                            return
                        }
                        let pt = layout.toPatient(v.location)
                        if ToolTap.isTap(v.translation), VetExamView.onPatient(pt) {
                            tickle()
                        }
                    }
            )
    }

    private func hitStickerIndex(at pt: CGPoint) -> Int? {
        for idx in stickers.indices.reversed() {
            let s = stickers[idx]
            if hypot(s.point.x - pt.x, s.point.y - pt.y) <= 56 {
                return idx
            }
        }
        return nil
    }

    private func peelSticker(at idx: Int, dragTranslation: CGSize) {
        let removed = stickers.remove(at: idx)
        clinic.setStickers(stickers, for: animal)
        VetSound.shared.play(.pluck, volume: 0.6)
        Sound.shared.play(.pop, volume: 0.5)
        Sound.shared.tap()
        bounce(0.04)
        let origin = layout.toRoom(removed.point)
        let roomPos = CGPoint(x: origin.x + dragTranslation.width, y: origin.y + dragTranslation.height)
        let throwX: CGFloat = abs(dragTranslation.width) > 12 ? dragTranslation.width * 2.2 : (removed.point.x < 300 ? -130 : 130)
        spawn(.prop(removed.prop), at: roomPos, vel: CGVector(dx: throwX, dy: -260), life: 1.1, gravity: 640, spin: 260, scale: CGFloat(removed.scale))
        burst(at: roomPos, count: 6, colors: [.white, Theme.lemon, Theme.pink])
    }

    // MARK: Top bar controls

    private var newCheckupButton: some View {
        let healed = visit.healed
        return RoundButton(
            symbol: "bell.fill",
            tint: healed ? Color(hex: 0xF5A623) : Theme.mint,
            size: GameChromeLayout.buttonSize
        ) {
            startNewCheckup()
        }
        .scaleEffect(healed && bellPulse ? 1.09 : 1)
        .accessibilityLabel("New Checkup")
    }

    private var lobbyButton: some View {
        Button {
            Sound.shared.play(.whoosh, volume: 0.6)
            Sound.shared.tap()
            save()
            onBack()
        } label: {
            Image(systemName: "pawprint.fill")
                .font(.system(size: GameChromeLayout.buttonSize * 0.42, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: GameChromeLayout.buttonSize, height: GameChromeLayout.buttonSize)
                .background(Circle().fill(Color(hex: 0x6CCB8B)))
                .overlay(Circle().stroke(.white, lineWidth: 4.5))
                .shadow(color: Theme.ink.opacity(0.24), radius: 6, y: 4)
        }
        .buttonStyle(Squish())
        .accessibilityLabel("Waiting Room")
    }

    private func startNewCheckup() {
        if auto.running { auto.cancel() }
        tool = nil
        picked = nil
        pickedDragging = false
        lastTip = nil
        consumed = false
        healedAt = nil
        hintTool = nil
        effects.endDrag()
        visit = clinic.startNewVisit(for: animal)
        stickers = clinic.stickers(animal)
        withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
            rightTab = .washBandage
        }
        Sound.shared.play(.ding, volume: 0.65)
        VetSound.shared.play(.hop, volume: 0.65)
        Sound.shared.tap()
        bounce(0.08)
        react(.oh, 0.7)
        burst(at: layout.toRoom(CGPoint(x: 300, y: 260)), count: 10, colors: [.white, Theme.mint, Theme.lemon])
    }

    private var ailmentHearts: some View {
        GameTrayCard(cornerRadius: 26, paddingH: 14, paddingV: 8) {
            HStack(spacing: 12) {
                ForEach(visit.ailments, id: \.self) { ailment in
                    ailmentChip(ailment)
                }
            }
        }
    }

    private func ailmentChip(_ ailment: VetAilment) -> some View {
        let spots = visit.spots.filter { $0.ailment == ailment }
        let isHealed = spots.allSatisfy(\.healed)
        let singleSpot = spots.count == 1
        let pipCount = singleSpot ? ailment.steps.count : spots.count

        return HStack(spacing: 6) {
            ZStack {
                if isHealed {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Theme.pink)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    VetPropPicture(prop: ailment.icon)
                        .frame(width: 28, height: 28)
                }
            }
            .frame(width: 28, height: 28)
            .scaleEffect(isHealed ? 1.08 : 1)
            .animation(.spring(response: 0.32, dampingFraction: 0.5), value: isHealed)

            HStack(spacing: 4) {
                ForEach(0..<pipCount, id: \.self) { i in
                    Circle()
                        .fill(pipColor(index: i, spots: spots, singleSpot: singleSpot, isHealed: isHealed))
                        .frame(width: 8, height: 8)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(isHealed ? Theme.blush.opacity(0.45) : Color.white.opacity(0.85))
        )
    }

    private func pipColor(index i: Int, spots: [VetSpot], singleSpot: Bool, isHealed: Bool) -> Color {
        if isHealed { return Theme.pink }
        if singleSpot, let s = spots.first {
            if i < s.stage { return Theme.pink }
            if i == s.stage && s.progress > 0.05 { return Theme.mint }
            return Theme.ink.opacity(0.18)
        }
        guard spots.indices.contains(i) else { return Theme.ink.opacity(0.18) }
        let s = spots[i]
        if s.healed { return Theme.pink }
        if s.stage > 0 || s.progress > 0.05 { return Theme.mint }
        return Theme.ink.opacity(0.18)
    }

    // MARK: Compact grouped trays

    private var activeHintTool: VetTool? {
        Date() < hintToolUntil ? hintTool : nil
    }

    private func orderedTools(_ base: [VetTool], needed: Set<VetTool>, hinted: VetTool?) -> [VetTool] {
        base.enumerated()
            .sorted { a, b in
                let rankA = (a.element == hinted ? 0 : (needed.contains(a.element) ? 1 : 2))
                let rankB = (b.element == hinted ? 0 : (needed.contains(b.element) ? 1 : 2))
                if rankA != rankB { return rankA < rankB }
                return a.offset < b.offset
            }
            .map(\.element)
    }

    private var leftExamTray: some View {
        let needed = visit.neededTools
        let hinted = activeHintTool
        let sorted = orderedTools(Self.examTools, needed: needed, hinted: hinted)
        let hasNeeded = sorted.contains { needed.contains($0) || $0 == hinted }

        return GameTrayCard(cornerRadius: 30, paddingH: 10, paddingV: 10) {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "stethoscope")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(hasNeeded ? Theme.pink : Theme.ink.opacity(0.6))
                    if hasNeeded {
                        Circle()
                            .fill(Theme.pink)
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Capsule().fill(hasNeeded ? Theme.blush.opacity(0.55) : Color.white.opacity(0.85)))

                toolGrid(sorted, columns: 2, tileSize: 74, needed: needed, hinted: hinted)
            }
        }
    }

    private var rightToolsTray: some View {
        let needed = visit.neededTools
        let hinted = activeHintTool
        let washNeeded = Self.washBandageTools.contains { needed.contains($0) || $0 == hinted }
        let items = rightTab == .washBandage
            ? orderedTools(Self.washBandageTools, needed: needed, hinted: hinted)
            : Self.pamperTools
        let tileSize: CGFloat = rightTab == .pamper ? 80 : 74

        return GameTrayCard(cornerRadius: 30, paddingH: 10, paddingV: 10) {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    rightTabButton(.washBandage, symbol: "bandage.fill", badge: washNeeded && rightTab != .washBandage)
                    rightTabButton(.pamper, symbol: "sparkles", badge: false)
                }
                .padding(4)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.blush.opacity(0.35)))

                toolGrid(items, columns: 2, tileSize: tileSize, needed: needed, hinted: hinted)
                    .id(rightTab)
                    .transition(.opacity)
            }
        }
    }

    private func rightTabButton(_ tab: VetRightTab, symbol: String, badge: Bool) -> some View {
        let selected = rightTab == tab
        return Button {
            guard rightTab != tab else { return }
            Sound.shared.play(.pop, volume: 0.55)
            Sound.shared.tap()
            withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                rightTab = tab
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(selected ? .white : Theme.ink.opacity(0.65))
                    .frame(width: 68, height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(selected ? Theme.pink : Color.white)
                    )
                if badge {
                    Circle()
                        .fill(Theme.pink)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                        .frame(width: 12, height: 12)
                        .offset(x: 3, y: -3)
                }
            }
        }
        .buttonStyle(Squish())
    }

    private func toolGrid(_ tools: [VetTool], columns: Int, tileSize: CGFloat, needed: Set<VetTool>, hinted: VetTool?) -> some View {
        let rowCount = (tools.count + columns - 1) / columns
        return VStack(spacing: 8) {
            ForEach(0..<rowCount, id: \.self) { row in
                HStack(spacing: 8) {
                    let start = row * columns
                    let end = min(tools.count, start + columns)
                    ForEach(Array(tools[start..<end]), id: \.self) { t in
                        VetToolTile(
                            tool: t,
                            size: tileSize,
                            needed: needed.contains(t),
                            hinted: hinted == t,
                            lifted: tool == t,
                            picked: picked == t,
                            onDrag: { p in
                                if auto.running { auto.cancel() }
                                if tool == nil { dragFrom = p }
                                drag(t, p)
                            },
                            onEnd: { shelfEnd(t, $0) }
                        )
                    }
                }
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.78), value: tools)
    }

    private func heldToolView(tool t: VetTool, art: VetToolArt) -> some View {
        let tip = tipRoom
        let over = toolOverPatient
        let side: CGFloat = over ? 168 : 176
        let s: CGFloat = side / 140
        let turn = t == .shower ? 0 : FingerLift.turn(tip: art.tip, center: CGPoint(x: 70, y: 70), finger: finger, lifted: tip)
        let dx = (70 - art.tip.x) * s
        let dy = (70 - art.tip.y) * s
        let c = CGFloat(cos(turn))
        let sn = CGFloat(sin(turn))
        return VetToolPicture(tool: t)
            .frame(width: side, height: side)
            .rotationEffect(.radians(turn))
            .opacity(over ? FingerLift.seeThrough : 1)
            .shadow(color: Theme.ink.opacity(over ? 0.12 : 0.25), radius: 8, y: 8)
            .animation(.easeOut(duration: 0.15), value: over)
            .position(x: tip.x + dx * c - dy * sn, y: tip.y + dx * sn + dy * c)
            .allowsHitTesting(false)
    }

    // MARK: Dragging & Tap-to-Use

    static func tipLift(_ t: VetTool?) -> CGFloat { t == .shower ? FingerLift.pour : FingerLift.tool }

    private var tipRoom: CGPoint {
        FingerLift.point(finger, lift: VetExamView.tipLift(tool), bottom: stageSize.height, width: stageSize.width)
    }

    private var toolOverPatient: Bool { VetExamView.onPatient(layout.toPatient(tipRoom)) }

    static func onPatient(_ tip: CGPoint) -> Bool {
        hypot(tip.x - 300, tip.y - 262) < 170 || (abs(tip.x - 300) < 150 && tip.y > 330 && tip.y < 650)
    }

    private func drag(_ t: VetTool, _ p: CGPoint) {
        guard !consumed else { return }
        if tool == nil {
            tool = t
            usedThisDrag = false
            lastTip = nil
            Sound.shared.play(.tap, volume: 0.6)
            Sound.shared.tap()
        }
        finger = p
    }

    private func shelfEnd(_ t: VetTool, _ p: CGPoint) {
        let tap = dragFrom.map { ToolTap.isTap(CGSize(width: p.x - $0.x, height: p.y - $0.y)) } ?? false
        dragFrom = nil
        guard tap, tool == t else { drop(t, p); return }
        tool = nil
        lastTip = nil
        consumed = false
        effects.endDrag()
        picked = picked == t ? nil : t
        Sound.shared.play(.pop, volume: 0.6)
    }

    /// Runs a picked tool on the tapped spot, or gently unpicks it if tapping backdrop / non-matching patient area.
    private func autoDo(_ t: VetTool, at p: CGPoint) {
        let pt = layout.toPatient(p)
        let onPat = VetExamView.onPatient(pt)

        // Check if there is a matching active spot for this tool
        let matchingSpots = visit.spots.filter { $0.step?.tool == t }
        let nearestMatch = matchingSpots.min {
            hypot($0.target.x - pt.x, $0.target.y - pt.y) < hypot($1.target.x - pt.x, $1.target.y - pt.y)
        }

        if let s = nearestMatch {
            let dist = hypot(s.target.x - pt.x, s.target.y - pt.y)
            if onPat || dist <= 165 {
                let targetRoom = layout.toRoom(s.target)
                runAuto(t, targetRoom: targetRoom)
                return
            }
        }

        // Tapping empty exam backdrop always puts the picked tool down cleanly.
        guard onPat else {
            picked = nil
            Sound.shared.play(.flip, volume: 0.4)
            return
        }

        // Syrup waiting for thermometer/stethoscope gently nudges without being consumed.
        if t == .syrup, let prereq = visit.syrupPrerequisite {
            nudgeSyrupPrerequisite(prereq, now: Date())
            return
        }

        // Pamper tools (plus extra bandages when healed) work wherever tapped on the patient.
        if t == .treat {
            let mouth = VetArt.shared.animals[animal]?.mouth ?? CGPoint(x: 300, y: 334)
            runAuto(t, targetRoom: layout.toRoom(mouth))
            return
        }
        if t == .bow {
            let onHead = hypot(pt.x - 300, pt.y - 250) < 185
            if onHead {
                runAuto(t, targetRoom: p)
                return
            }
        }
        if t == .spray || t == .feather || (t == .bandage && visit.healed) {
            runAuto(t, targetRoom: p)
            return
        }

        // No active spot matches this tool: gently unpick so bare-hand tickle is always accessible!
        picked = nil
        tickle()
    }

    private func runAuto(_ t: VetTool, targetRoom: CGPoint) {
        let f = FingerLift.finger(for: targetRoom, lift: VetExamView.tipLift(t), bottom: stageSize.height, width: stageSize.width)
        auto.run(
            from: CGPoint(x: f.x + 70, y: f.y + 90),
            to: f,
            step: { q in drag(t, q) },
            end: { q in drop(t, q) }
        )
    }

    private func drop(_ t: VetTool, _ p: CGPoint) {
        defer {
            tool = nil
            lastTip = nil
            consumed = false
            effects.endDrag()
        }
        guard !consumed, tool == t else { return }
        finger = p
        let tip = layout.toPatient(tipRoom)
        let onHead = hypot(tip.x - 300, tip.y - 250) < 175
        let onBody = onHead || (abs(tip.x - 300) < 140 && tip.y > 330 && tip.y < 640)
        if t == .bow && onHead {
            addSticker(VetSticker(prop: "bow\(bowColor)", x: tip.x, y: tip.y, scale: 0.85, rotation: Double.random(in: -18...18)))
            bowColor = (bowColor + 1) % 6
            react(.wow, 1.0)
            clinic.unlock(.bowStylist)
        } else if t == .bandage && onBody && !usedThisDrag {
            addSticker(VetSticker(prop: "bandage", x: tip.x, y: tip.y, scale: 0.7, rotation: Double.random(in: -30...30)))
            react(.giggle, 0.8)
        } else {
            Sound.shared.play(.flip, volume: 0.4)
        }
    }

    private func holdDemoTool(_ L: VetLayout) {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-vetHold"), i + 1 < args.count, let t = VetTool(rawValue: args[i + 1]) else { return }
        let spot = visit.spots.first { $0.step?.tool == t } ?? visit.spots.first
        let at = L.toRoom(spot?.target ?? CGPoint(x: 300, y: 420))
        tool = t
        let f = FingerLift.finger(for: at, lift: VetExamView.tipLift(t), bottom: L.size.height, width: L.size.width)
        finger = CGPoint(x: f.x + 6, y: f.y + 4)
    }

    private func addSticker(_ s: VetSticker) {
        stickers.append(s)
        effects.pressSticker(at: s.point)
        if stickers.count > 12 { stickers.removeFirst(stickers.count - 12) }
        clinic.setStickers(stickers, for: animal)
        VetSound.shared.play(.sticker)
        bounce(0.05)
        burst(at: layout.toRoom(s.point), count: 6, colors: [.white, Theme.lemon, Theme.pink])
    }

    private func nudgeSyrupPrerequisite(_ prereq: VetTool, now: Date) {
        hintTool = prereq
        hintToolUntil = now.addingTimeInterval(2.6)
        if fx("prereq", 0.9) {
            Sound.shared.play(.boing, volume: 0.42)
            Sound.shared.tap()
            bounce(0.045)
            react(.oh, 0.55)
            let mouth = VetArt.shared.animals[animal]?.mouth ?? CGPoint(x: 300, y: 334)
            burst(at: layout.toRoom(mouth), count: 5, colors: [Theme.sky, Theme.lemon, .white])
        }
    }

    // MARK: The game loop

    private func tick() {
        let now = Date()
        if !particles.isEmpty { particles.removeAll { now.timeIntervalSince($0.born) > $0.life } }

        if visit.has(.cold) && tool == nil && now > nextSneeze {
            nextSneeze = now.addingTimeInterval(Double.random(in: 5...8))
            react(.sneeze, 0.7)
            VetSound.shared.play(.sneeze, volume: 0.7)
            bounce(0.08)
            spawn(.prop("drip"), at: layout.toRoom(CGPoint(x: 312, y: 330)), vel: CGVector(dx: 30, dy: -60), life: 0.9, gravity: 500, scale: 0.6)
        }

        guard let t = tool, !consumed else { return }
        let tip = layout.toPatient(tipRoom)
        let rawMoved = min(40, lastTip.map { hypot(tip.x - $0.x, tip.y - $0.y) } ?? 0)
        let step = lastTip.map { CGVector(dx: tip.x - $0.x, dy: tip.y - $0.y) } ?? .zero
        lastTip = tip
        effects.mudSpots = visit.spots.filter { $0.ailment == .mud && !$0.healed }.map(\.point)
        effects.emit(
            t,
            tip: tip,
            room: tipRoom,
            step: step,
            toRoom: layout.toRoom,
            mouth: VetArt.shared.animals[animal]?.mouth ?? CGPoint(x: 300, y: 334),
            mud: effects.mudSpots
        )

        let effectiveDT = auto.running ? (1.0 / 30) * Self.autoHoldBoost : (1.0 / 30)
        let effectiveMoved = auto.running ? rawMoved * Self.autoRubBoost : rawMoved
        let events = visit.use(t, at: tip, moved: effectiveMoved, dt: effectiveDT)
        if events.isEmpty {
            play(t, tip: tip, moved: rawMoved, now: now)
        } else {
            usedThisDrag = true
            for e in events { handle(e, tool: t, tip: tip, now: now) }
            clinic.update(visit)
        }
    }

    private func handle(_ e: VetVisit.Event, tool t: VetTool, tip: CGPoint, now: Date) {
        let room = layout.toRoom(tip)
        switch e {
        case .working(let id, _):
            working = id
            workingUntil = now.addingTimeInterval(0.25)
            let a = visit.spots.first { $0.id == id }?.ailment
            if a?.stings == true {
                react(.ouch, 0.35)
                VetSound.shared.play(.ouch, volume: 0.5, gap: 1.4)
            } else {
                switch t {
                case .toothbrush: react(.brushing, 0.3)
                case .thermometer: react(.oh, 0.3)
                case .stethoscope, .icepack: react(.blinkSmile, 0.3)
                default: react(.giggle, 0.3)
                }
            }
            switch t {
            case .sponge, .cream, .swab, .toothbrush:
                VetSound.shared.play(.scrub, volume: 0.6, gap: 0.22)
            case .shower:
                VetSound.shared.play(.splash, volume: 0.6, gap: 0.5)
            case .comb, .brush, .tissue:
                VetSound.shared.play(.swish, volume: 0.6, gap: 0.28)
            case .stethoscope:
                VetSound.shared.play(.heartbeat, gap: 0.9)
                if fx("hb", 0.9) { emitHeartbeat(at: room) }
            case .icepack:
                VetSound.shared.play(.brr, volume: 0.65, gap: 0.65)
                if fx("chill", 0.45) {
                    spawn(.sparkle(Theme.sky), at: room, vel: CGVector(dx: .random(in: -55...55), dy: -75), life: 0.7, scale: 0.9)
                }
            default:
                break
            }
        case .stepDone(let id, let ailment, let step):
            guard let s = visit.spots.first(where: { $0.id == id }) else { break }
            let at = layout.toRoom(ailment.steps[step].anchor.map(VetAnchors.point) ?? s.point)
            bounce(0.06)
            burst(at: at, count: 8)
            switch t {
            case .tweezers:
                VetSound.shared.play(.pluck)
                spawn(.prop("thorn"), at: at, vel: CGVector(dx: s.point.x < 300 ? -160 : 160, dy: -380), life: 1.2, gravity: 700, spin: 400, scale: 0.8)
                react(.ouch, 0.4)
            case .bandage:
                VetSound.shared.play(.sticker)
                effects.pressSticker(at: s.point)
            case .thermometer:
                VetSound.shared.play(.beep)
            case .icepack:
                VetSound.shared.play(.brr, volume: 0.7)
                Sound.shared.play(.sparkle, volume: 0.6)
            case .syrup:
                VetSound.shared.play(.nom)
                react(.yum, 1.0)
            case .shower:
                VetSound.shared.play(.splash)
            case .wrap:
                VetSound.shared.play(.zip)
                effects.wrap(id)
            case .stethoscope:
                VetSound.shared.play(.heartbeat)
                if VetDraw.hasHeartScope { emitHeartbeat(at: at) }
            case .comb:
                VetSound.shared.play(.bugjump)
                spawn(.prop(["bug", "bugGreen", "bugPink"][id % 3]), at: at,
                      vel: CGVector(dx: s.point.x < 300 ? -320 : 320, dy: -520), life: 1.4, gravity: 900, spin: 200, scale: 0.6)
            case .brush:
                VetSound.shared.play(.swish)
                spawn(.prop(["leaf", "leafGold", "leafRed"][id % 3]), at: at,
                      vel: CGVector(dx: s.point.x < 300 ? -200 : 200, dy: -200), life: 1.8, gravity: 260, spin: 160, scale: 0.8)
            case .sponge:
                Sound.shared.play(.bubble, volume: 0.7)
            default:
                Sound.shared.play(.ding, volume: 0.5)
            }
            if picked == t && !t.isPamper && !visit.neededTools.contains(t) {
                picked = nil
            }
        case .spotHealed(let id, let ailment):
            if let s = visit.spots.first(where: { $0.id == id }) {
                let at = layout.toRoom(s.point)
                for i in 0..<3 {
                    spawn(.heart([Theme.pink, Color(hex: 0xFF6F96), Theme.lilac][i]), at: at,
                          vel: CGVector(dx: Double(i - 1) * 60, dy: -150 - Double(i) * 30), life: 1.1, scale: 0.9)
                }
            }
            Sound.shared.play(.sparkle, volume: 0.6)
            if reaction != .yum { react(.giggle, 0.9) }
            switch ailment {
            case .mud: clinic.unlock(.sparkleBath)
            case .toothache: clinic.unlock(.sweetTooth)
            case .tummy: clinic.unlock(.tummyHero)
            case .cold, .scrape, .sprain, .thorns: clinic.unlock(.gentleDoctor)
            default: break
            }
        case .allHealed:
            healedAt = now
            picked = nil
            clinic.completeVisit(for: animal, visit: visit, coinOrigin: CGPoint(x: 512, y: 360))
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                rightTab = .pamper
            }
            react(.wow, 2.6)
            bounce(0.1)
            VetSound.shared.play(.healed)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { Sound.shared.play(.fanfare, volume: 0.7) }
            confetti()
        }
    }

    /// Tools that aren't needed right now still do something nice.
    private func play(_ t: VetTool, tip: CGPoint, moved: CGFloat, now: Date) {
        let a = VetArt.shared.animals[animal]
        let mouth = a?.mouth ?? CGPoint(x: 300, y: 334)
        let nearMouth = hypot(tip.x - mouth.x, tip.y - mouth.y) < 70
        guard VetExamView.onPatient(tip) else { return }
        let room = layout.toRoom(tip)
        let rubbing = moved > 2
        switch t {
        case .syrup:
            if let prereq = visit.syrupPrerequisite {
                // Never prematurely consume syrup when thermometer/stethoscope is still needed first.
                if nearMouth {
                    nudgeSyrupPrerequisite(prereq, now: now)
                } else {
                    react(.oh, 0.3)
                }
            } else if nearMouth {
                consumed = true
                tool = nil
                VetSound.shared.play(.nom)
                react(.yum, 1.3)
                bounce(0.07)
                for i in 0..<4 {
                    spawn(.heart([Theme.pink, Color(hex: 0xFF6F96)][i % 2]), at: layout.toRoom(mouth),
                          vel: CGVector(dx: Double(i) * 40 - 60, dy: -160), life: 1.2, scale: 0.8)
                }
            } else {
                react(.oh, 0.3)
            }
        case .treat:
            if nearMouth {
                consumed = true
                tool = nil
                VetSound.shared.play(.nom)
                effects.crumbs(at: layout.toRoom(mouth))
                react(.yum, 1.3)
                bounce(0.07)
                clinic.unlock(.sweetTooth)
                for i in 0..<4 {
                    spawn(.heart([Theme.pink, Color(hex: 0xFF6F96)][i % 2]), at: layout.toRoom(mouth),
                          vel: CGVector(dx: Double(i) * 40 - 60, dy: -160), life: 1.2, scale: 0.8)
                }
            } else {
                react(.oh, 0.3)
            }
        case .feather:
            if rubbing {
                react(.giggle, 0.6)
                VetSound.shared.play(.giggle, volume: 0.6, gap: 1.0)
                if fx("wig", 0.5) { bounce(0.04) }
            }
        case .brush, .towel, .comb:
            if rubbing {
                react(.blinkSmile, 0.5)
                VetSound.shared.play(.swish, volume: 0.5, gap: 0.35)
                if fx("spk", 0.15) { spawn(.sparkle(.white), at: room, vel: CGVector(dx: .random(in: -60...60), dy: -80), life: 0.6, scale: 0.8) }
            }
        case .sponge:
            if rubbing {
                react(.giggle, 0.4)
                VetSound.shared.play(.scrub, volume: 0.5, gap: 0.25)
            }
        case .shower:
            react(.giggle, 0.4)
            VetSound.shared.play(.splash, volume: 0.5, gap: 0.5)
        case .spray:
            react(.wow, 0.6)
            VetSound.shared.play(.spray, volume: 0.5, gap: 0.45)
            if fx("spr", 0.08) {
                spawn(.sparkle([Theme.lemon, Theme.pink, .white, Theme.lilac].randomElement()!), at: room,
                      vel: CGVector(dx: .random(in: -120...120), dy: .random(in: -140...(-20))), life: 0.9, scale: .random(in: 0.6...1.2))
            }
        case .stethoscope:
            react(.blinkSmile, 0.4)
            VetSound.shared.play(.heartbeat, volume: 0.8, gap: 0.9)
            if fx("hb", 0.9) { emitHeartbeat(at: room) }
        case .thermometer, .toothbrush:
            react(nearMouth ? (t == .toothbrush ? .brushing : .oh) : .oh, 0.3)
            if nearMouth && t == .toothbrush && rubbing {
                VetSound.shared.play(.scrub, volume: 0.5, gap: 0.25)
                if fx("spk", 0.2) { spawn(.sparkle(.white), at: room, vel: CGVector(dx: .random(in: -50...50), dy: -60), life: 0.6) }
            }
        case .icepack:
            react(.blinkSmile, 0.4)
            VetSound.shared.play(.brr, volume: 0.55, gap: 0.85)
            if fx("chillPlay", 0.55) {
                spawn(.sparkle(Theme.sky), at: room, vel: CGVector(dx: .random(in: -45...45), dy: -65), life: 0.65, scale: 0.75)
            }
        case .tissue, .cream, .swab, .wrap, .tweezers, .bandage, .bow:
            react(.oh, 0.3)
        }
    }

    private func tickle() {
        react(.giggle, 0.8)
        VetSound.shared.play(.giggle, volume: 0.6, gap: 0.6)
        VetSound.shared.play(.hop, volume: 0.4, gap: 0.3)
        bounce(0.07)
        let p = layout.toRoom(CGPoint(x: 300, y: 200))
        spawn(.heart(Theme.pink), at: p, vel: CGVector(dx: .random(in: -60...60), dy: -140), life: 1.0)
    }

    // MARK: Effects helpers

    private func react(_ f: VetFace, _ secs: Double) {
        reaction = f
        reactionUntil = Date().addingTimeInterval(secs)
    }

    private func bounce(_ amp: CGFloat) {
        bounceAt = Date()
        bounceAmp = amp
    }

    private func fx(_ key: String, _ gap: Double) -> Bool {
        let now = Date()
        if let t = lastFx[key], now.timeIntervalSince(t) < gap { return false }
        lastFx[key] = now
        return true
    }

    private func spawn(_ k: VetParticle.Kind, at p: CGPoint, vel: CGVector, life: Double, gravity: CGFloat = 0,
                       spin: Double = 0, scale: CGFloat = 1) {
        particles.append(VetParticle(kind: k, pos: p, vel: vel, born: Date(), life: life, gravity: gravity, spin: spin, scale: scale))
        if particles.count > 160 { particles.removeFirst(particles.count - 160) }
    }

    private func emitHeartbeat(at room: CGPoint) {
        spawn(.heart(Theme.pink), at: room, vel: CGVector(dx: 0, dy: -90), life: 0.9, scale: 1.1)
        guard VetDraw.hasHeartScope else { return }
        spawn(.heart(Theme.lilac), at: room, vel: CGVector(dx: -54, dy: -115), life: 1.0, scale: 0.85)
        spawn(.heart(Color(hex: 0xFF6FA8)), at: room, vel: CGVector(dx: 54, dy: -115), life: 1.0, scale: 0.85)
        let cols: [Color] = [.white, Theme.lemon, Theme.pink, Theme.lilac]
        for i in 0..<4 {
            let dx = CGFloat(i - 1) * 38 - 18
            spawn(.sparkle(cols[i]), at: room, vel: CGVector(dx: dx, dy: -135 - CGFloat(i % 2) * 28), life: 0.85, scale: 0.9)
        }
    }

    private func burst(at p: CGPoint, count: Int, colors: [Color] = [.white, Theme.lemon, Theme.pink, Theme.mint]) {
        for i in 0..<count {
            let a = Double(i) / Double(count) * 2 * .pi
            spawn(.sparkle(colors[i % colors.count]), at: p, vel: CGVector(dx: cos(a) * 170, dy: sin(a) * 170 - 40),
                  life: 0.7, scale: 0.7 + CGFloat(i % 3) * 0.25)
        }
    }

    private func confetti() {
        let colors = [Theme.pink, Theme.lemon, Theme.mint, Theme.sky, Theme.lilac, Theme.peach]
        for i in 0..<46 {
            let x = stageSize.width * CGFloat.random(in: 0.2...0.8)
            spawn(.confetti(colors[i % colors.count]), at: CGPoint(x: x, y: stageSize.height * 0.45),
                  vel: CGVector(dx: .random(in: -260...260), dy: .random(in: -760...(-380))), life: 2.4, gravity: 620,
                  spin: .random(in: -600...600), scale: .random(in: 0.8...1.3))
        }
        burst(at: layout.toRoom(CGPoint(x: 300, y: 260)), count: 14)
    }

    private func save() {
        clinic.update(visit)
        clinic.setStickers(stickers, for: animal)
    }

    // MARK: Drawing

    private func face(_ now: Date) -> VetFace {
        if let r = reaction, now < reactionUntil { return r }
        let t = now.timeIntervalSinceReferenceDate
        var f: VetFace
        if visit.healed {
            f = (healedAt.map { now.timeIntervalSince($0) < 4 } ?? false) ? .wow : .calm
            if t.truncatingRemainder(dividingBy: 7) < 1.2 { f = .giggle }
        } else if visit.has(.cold) || visit.has(.tummy) {
            f = .poorly
        } else {
            f = .sad
        }
        if tool != nil && !visit.healed { f = VetFace(eyes: "open", mouth: f.mouth, brows: f.brows) }
        if f.eyes == "open" || f.eyes == "sad" || f.eyes == "sparkle" {
            if t.truncatingRemainder(dividingBy: 3.7) < 0.13 { f.eyes = "blink" }
        }
        return f
    }

    private func draw(_ ctx: GraphicsContext, now: Date) {
        let art = VetArt.shared
        guard let a = art.animals[animal] else { return }
        let L = layout
        let t = now.timeIntervalSinceReferenceDate
        effects.step(to: t, toPatient: L.toPatient, toRoom: L.toRoom, floorY: L.toRoom(CGPoint(x: 300, y: 648)).y)

        var sy: CGFloat = 1 + 0.012 * CGFloat(sin(t * 2.4))
        var sx: CGFloat = 1
        let db = now.timeIntervalSince(bounceAt)
        if db < 1.4 {
            let b = bounceAmp * CGFloat(sin(db * 18) * exp(-db * 4.5))
            sy += b
            sx -= b * 0.6
        }
        var dx: CGFloat = 0
        var dy: CGFloat = 0
        if visit.has(.cold) && t.truncatingRemainder(dividingBy: 3.2) < 0.5 { dx = 2.5 * sin(t * 60) }
        if let h = healedAt {
            let dh = now.timeIntervalSince(h)
            if dh < 2.6 { dy = -CGFloat(abs(sin(dh * 7.4)) * 60 * exp(-dh * 1.1)) }
        }

        var g = ctx
        g.translateBy(x: L.origin.x, y: L.origin.y)
        g.scaleBy(x: VetLayout.k, y: VetLayout.k)
        g.fill(Path(ellipseIn: CGRect(x: 300 - 190 * (1 - dy / 160), y: 622, width: 380 * (1 - dy / 160), height: 40)),
               with: .color(Theme.ink.opacity(0.12)))
        effects.drawPuddle(g, floor: CGPoint(x: 300, y: 642), t: t)

        var p = g
        p.translateBy(x: 300 + dx, y: 640 + dy)
        if abs(effects.lean) > 0.01 { p.rotate(by: .degrees(effects.lean)) }
        p.scaleBy(x: sx, y: sy)
        p.translateBy(x: -300, y: -640)

        var look = CGVector.zero
        if tool != nil {
            let tip = L.toPatient(tipRoom)
            let v = CGVector(dx: tip.x - 300, dy: tip.y - a.eye.y)
            let n = max(1, hypot(v.dx, v.dy))
            look = CGVector(dx: v.dx / n * 6, dy: v.dy / n * 5)
        }

        VetPatientPainter.draw(a, face: face(now), look: look, in: p, overlay: { c in
            for (idx, s) in stickers.enumerated() {
                let isPeeling = peelingIndex == idx
                let offsetX = isPeeling ? peelingOffset.width / VetLayout.k : 0
                let offsetY = isPeeling ? peelingOffset.height / VetLayout.k : 0
                let pt = CGPoint(x: s.point.x + offsetX, y: s.point.y + offsetY)
                let scale = CGFloat(s.scale) * effects.pressScale(at: s.point, t: t) * (isPeeling ? 1.14 : 1)
                let rot = s.rotation + (isPeeling ? Double(offsetX) * 0.14 : 0)
                VetDraw.prop(s.prop, at: pt, scale: scale, rotation: rot, in: c)
            }
            drawSpots(c, t: t, now: now)
            effects.drawOnFur(c, t: t)
        }, top: { c in
            drawFaceTop(c, a: a, t: t)
        })

        drawTargetsAndProgress(p, t: t)

        if let h = healedAt, now.timeIntervalSince(h) < 3.5 {
            let dh = now.timeIntervalSince(h)
            let s = CGFloat(min(1, dh * 3)) * (1 + 0.05 * CGFloat(sin(dh * 6)))
            VetDraw.prop("medal", at: L.toRoom(CGPoint(x: 470, y: 120)), scale: 1.3 * s,
                         rotation: 8 * sin(dh * 3), opacity: min(1, (3.5 - dh) * 2), in: ctx)
        }

        drawParticles(ctx, now: now)
        effects.drawInRoom(ctx, t: t)
    }

    /// Draws pulsing target rings (for picked OR dragged tools), mouth guide cues, and live radial progress arcs.
    private func drawTargetsAndProgress(_ p: GraphicsContext, t: Double) {
        let activeTool = tool ?? picked
        let pulse = CGFloat(1 + 0.11 * sin(t * 7))

        // Subtle mouth cue when stage-1 cold/tummy/toothache is waiting at the mouth.
        let mouthStage1 = visit.spots.first {
            !$0.healed && $0.stage == 1 && $0.step?.anchor == "mouth"
        }
        if let ms = mouthStage1, activeTool == nil {
            let m = ms.target
            let r = 34 * (1 + 0.08 * CGFloat(sin(t * 4.5)))
            let halo = Path(ellipseIn: CGRect(x: m.x - r, y: m.y - r, width: r * 2, height: r * 2))
            p.stroke(halo, with: .color(Theme.pink.opacity(0.45)), style: StrokeStyle(lineWidth: 3.5, lineCap: .round, dash: [8, 8], dashPhase: CGFloat(t * 18)))
            StorybookArt.sparkle(p, at: CGPoint(x: m.x + r * 0.78, y: m.y - r * 0.65), radius: 7, color: Theme.lemon, opacity: 0.85)
        }

        // Target rings whenever a tool is dragged OR picked on a tray.
        if let tl = activeTool {
            for s in visit.spots where s.step?.tool == tl {
                let c = s.target
                let isMouthStep = s.step?.anchor == "mouth"
                let baseR: CGFloat = isMouthStep ? 52 : 46
                let r = baseR * pulse
                let ring = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
                if isMouthStep {
                    p.fill(ring, with: .color(Theme.blush.opacity(0.22)))
                }
                p.stroke(ring, with: .color(.white.opacity(0.95)), style: StrokeStyle(lineWidth: 7, lineCap: .round, dash: [14, 12], dashPhase: CGFloat(t * 30)))
                p.stroke(ring, with: .color(Theme.pink.opacity(0.85)), style: StrokeStyle(lineWidth: 3.5, lineCap: .round, dash: [14, 12], dashPhase: CGFloat(t * 30)))

                // If the step happens at the mouth instead of the original spot (tummy/toothache/cold), draw a gentle dotted guide arc to the mouth.
                if isMouthStep && hypot(s.point.x - c.x, s.point.y - c.y) > 20 {
                    var guide = Path()
                    guide.move(to: s.point)
                    let mid = CGPoint(x: (s.point.x + c.x) * 0.5 + (s.point.x <= 300 ? -34 : 34), y: (s.point.y + c.y) * 0.5)
                    guide.addQuadCurve(to: c, control: mid)
                    p.stroke(guide, with: .color(.white.opacity(0.9)), style: StrokeStyle(lineWidth: 6, lineCap: .round, dash: [8, 12], dashPhase: CGFloat(-t * 28)))
                    p.stroke(guide, with: .color(Theme.pink.opacity(0.75)), style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [8, 12], dashPhase: CGFloat(-t * 28)))
                }
            }
        }

        // Crisp circular radial progress arcs on any spot being actively healed.
        for s in visit.spots where !s.healed && s.progress > 0.01 {
            let c = s.target
            let pr = min(1.0, max(0.0, s.progress))
            let rad: CGFloat = 54
            let track = Path(ellipseIn: CGRect(x: c.x - rad, y: c.y - rad, width: rad * 2, height: rad * 2))
            p.stroke(track, with: .color(.white.opacity(0.82)), style: StrokeStyle(lineWidth: 10))

            var arc = Path()
            let startAngle = -Double.pi / 2
            let endAngle = startAngle + 2 * Double.pi * pr
            arc.addArc(center: c, radius: rad, startAngle: .radians(startAngle), endAngle: .radians(endAngle), clockwise: false)
            let arcColor = pr > 0.72 ? Theme.pink : Theme.mint
            p.stroke(arc, with: .color(arcColor), style: StrokeStyle(lineWidth: 7, lineCap: .round))

            let tipX = c.x + CGFloat(cos(endAngle)) * rad
            let tipY = c.y + CGFloat(sin(endAngle)) * rad
            let dot = Path(ellipseIn: CGRect(x: tipX - 5.5, y: tipY - 5.5, width: 11, height: 11))
            StorybookArt.fillAndStroke(p, dot, fill: .white, stroke: Theme.pink, width: 2.5)
        }
    }

    private func drawSpots(_ c: GraphicsContext, t: Double, now: Date) {
        for s in visit.spots {
            let p = s.point
            let busy = working == s.id && now < workingUntil
            let jig: CGFloat = busy ? CGFloat(sin(t * 50)) * 2 : 0
            let pr = CGFloat(min(1, s.progress))
            switch s.ailment {
            case .mud:
                if s.stage == 0 {
                    VetDraw.prop("mud", at: p, scale: 0.85, opacity: Double(1 - pr * 0.6), in: c)
                    VetFX.drawLather(c, at: p, amount: pr * 0.9, mud: Double(1 - pr) * 0.8, t: t)
                } else if s.stage == 1 {
                    VetFX.drawLather(c, at: CGPoint(x: p.x, y: p.y + pr * 30), amount: (1 - pr) * (1 + jig * 0.02), mud: 0.12 * Double(1 - pr), t: t)
                }
            case .thorns:
                if !s.healed {
                    VetDraw.prop("thorn", at: CGPoint(x: p.x + jig, y: p.y - 6), scale: 0.75,
                                 rotation: (p.x < 300 ? -22 : 22) + (busy ? 8 * sin(t * 30) : 0), in: c)
                }
            case .scrape:
                if s.healed {
                    VetDraw.prop("bandage", at: p, scale: 0.68 * effects.pressScale(at: p, t: now.timeIntervalSinceReferenceDate), rotation: Double((s.id * 37) % 50 - 25), in: c)
                } else {
                    VetDraw.prop("scrapeClean", at: p, scale: 0.8, in: c)
                    if s.stage == 0 { VetDraw.prop("scrape", at: p, scale: 0.8, opacity: Double(1 - pr * 0.9), in: c) }
                }
            case .cold:
                if !s.healed {
                    VetDraw.prop("rednose", at: VetAnchors.point("nose"), scale: 0.9 + 0.05 * CGFloat(sin(t * 3)), in: c)
                }
            case .toothache:
                if s.stage == 0 {
                    VetDraw.prop("swelling", at: p, scale: 0.8 + 0.04 * CGFloat(sin(t * 5)) - pr * 0.25, in: c)
                } else if s.stage == 1 {
                    VetDraw.prop("swelling", at: p, scale: 0.45, opacity: 0.8, in: c)
                }
            case .fleas:
                if !s.healed {
                    let hop = -abs(CGFloat(sin(t * 5 + Double(s.id)))) * 10
                    VetDraw.prop(["bug", "bugGreen", "bugPink"][s.id % 3], at: CGPoint(x: p.x + jig * 3, y: p.y + hop),
                                 scale: 0.58, rotation: 10 * sin(t * 3 + Double(s.id)), in: c)
                }
            case .rash:
                if !s.healed { VetDraw.prop("rash", at: p, scale: 0.75, opacity: Double(1 - pr * 0.8), in: c) }
            case .tummy:
                if !s.healed {
                    VetDraw.prop("swirl", at: p, scale: s.stage == 0 ? 0.85 : 0.55, rotation: t * 90, opacity: s.stage == 0 ? 1 : 0.6, in: c)
                }
            case .sprain:
                if s.healed {
                    VetFX.drawWrap(c, at: p, started: effects.wraps[s.id], t: t)
                } else {
                    VetDraw.prop("bump", at: p, scale: (s.stage == 0 ? 0.8 : 0.5) + 0.06 * CGFloat(sin(t * 6)), in: c)
                }
            case .leaves:
                if !s.healed {
                    VetDraw.prop(["leaf", "leafGold", "leafRed"][s.id % 3], at: CGPoint(x: p.x + jig * 2, y: p.y),
                                 scale: 0.8, rotation: 8 * sin(t * 2 + Double(s.id)), in: c)
                }
            }
        }
    }

    private func drawFaceTop(_ c: GraphicsContext, a: VetAnimal, t: Double) {
        if visit.has(.cold) {
            let n = VetAnchors.point("nose")
            let bob = CGFloat(sin(t * 2.2)) * 4
            VetDraw.prop("drip", at: CGPoint(x: n.x + 16, y: n.y + 24 + bob), scale: 0.7 + 0.08 * CGFloat(sin(t * 2.2)), in: c)
            VetDraw.prop("chill", at: CGPoint(x: 300, y: 262), scale: 1, opacity: 0.6 + 0.3 * sin(t * 4), in: c)
        }
        for s in visit.spots where s.ailment == .toothache && s.stage == 1 && s.progress > 0.05 {
            VetDraw.prop("bubbles", at: CGPoint(x: a.mouth.x + 30, y: a.mouth.y + 12), scale: 0.3 + CGFloat(s.progress) * 0.35, opacity: 0.9, in: c)
        }
    }

    private func drawParticles(_ ctx: GraphicsContext, now: Date) {
        for q in particles {
            let age = now.timeIntervalSince(q.born)
            guard age >= 0, age < q.life else { continue }
            let tt = CGFloat(age)
            let x = q.pos.x + q.vel.dx * tt
            let y = q.pos.y + q.vel.dy * tt + 0.5 * q.gravity * tt * tt
            let fade = min(1, (q.life - age) / 0.3)
            var g = ctx
            g.opacity = fade
            g.translateBy(x: x, y: y)
            g.rotate(by: .degrees(q.spin * age))
            switch q.kind {
            case .prop(let name):
                VetDraw.prop(name, at: .zero, scale: q.scale, in: g)
            case .sparkle(let col):
                let seed = Double(abs(q.id.hashValue % 997)) / 97
                let flicker = CGFloat(0.55 + 0.45 * abs(sin(age * 15 + seed)))
                let r = 13 * q.scale * (1 - tt * 0.4) * flicker
                let glow = r * 1.9
                g.fill(Path(ellipseIn: CGRect(x: -glow, y: -glow, width: glow * 2, height: glow * 2)),
                       with: .radialGradient(Gradient(colors: [col.opacity(0.45), col.opacity(0)]), center: .zero, startRadius: 0, endRadius: glow))
                g.rotate(by: .degrees(age * 140 + seed * 30))
                g.fill(Twinkle().path(in: CGRect(x: -r, y: -r, width: r * 2, height: r * 2)), with: .color(col))
                g.fill(Path(ellipseIn: CGRect(x: -r * 0.22, y: -r * 0.22, width: r * 0.44, height: r * 0.44)), with: .color(.white))
            case .heart(let col):
                let r = 16 * q.scale * (0.6 + min(0.4, tt))
                let hp = VetExamView.heart(r)
                g.fill(hp, with: .color(col))
                g.stroke(hp, with: .color(.white), lineWidth: 3)
            case .drop:
                let r = 6 * q.scale
                g.fill(Path(ellipseIn: CGRect(x: -r * 0.7, y: -r, width: r * 1.4, height: r * 2)), with: .color(Color(hex: 0x8EC5FF)))
            case .confetti(let col):
                g.fill(Path(roundedRect: CGRect(x: -7 * q.scale, y: -4 * q.scale, width: 14 * q.scale, height: 8 * q.scale), cornerRadius: 2),
                       with: .color(col))
            }
        }
    }

    static func heart(_ s: CGFloat) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: s * 0.95))
        p.addCurve(to: CGPoint(x: -s, y: -s * 0.25), control1: CGPoint(x: -s * 0.2, y: s * 0.75), control2: CGPoint(x: -s, y: s * 0.25))
        p.addCurve(to: CGPoint(x: 0, y: -s * 0.5), control1: CGPoint(x: -s, y: -s * 0.75), control2: CGPoint(x: -s * 0.45, y: -s * 0.95))
        p.addCurve(to: CGPoint(x: s, y: -s * 0.25), control1: CGPoint(x: s * 0.45, y: -s * 0.95), control2: CGPoint(x: s, y: -s * 0.75))
        p.addCurve(to: CGPoint(x: 0, y: s * 0.95), control1: CGPoint(x: s, y: s * 0.25), control2: CGPoint(x: s * 0.2, y: s * 0.75))
        p.closeSubpath()
        return p
    }
}

// MARK: - Unified tool tile (single crisp Theme.pink ring, zero double-border collision)

private struct VetToolTile: View {
    let tool: VetTool
    let size: CGFloat
    let needed: Bool
    let hinted: Bool
    let lifted: Bool
    let picked: Bool
    let onDrag: (CGPoint) -> Void
    let onEnd: (CGPoint) -> Void

    var body: some View {
        let highlighted = (picked || needed || hinted) && !lifted
        let pulsing = (needed || hinted) && !picked && !lifted
        let fillTint: Color = picked && !lifted
            ? Theme.blush.opacity(0.65)
            : (VetArt.shared.tools[tool]?.tint ?? .white)

        GameDockTile(
            size: size,
            selected: highlighted,
            pulsing: pulsing,
            tint: fillTint,
            cornerRadius: 22
        ) {
            ZStack(alignment: .topTrailing) {
                VetToolPicture(tool: tool)
                    .padding(8)
                if picked && !lifted {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(Theme.pink))
                        .padding(5)
                } else if (needed || hinted) && !lifted {
                    Image(systemName: "sparkle")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(hinted ? Theme.pink : Theme.lemon)
                        .shadow(color: Theme.ink.opacity(0.28), radius: 1)
                        .padding(6)
                }
            }
        }
        .opacity(lifted ? 0.35 : 1)
        .scaleEffect(lifted ? 0.92 : 1)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named("exam"))
                .onChanged { onDrag($0.location) }
                .onEnded { onEnd($0.location) }
        )
    }
}
