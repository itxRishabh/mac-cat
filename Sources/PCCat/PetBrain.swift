import Foundation
import SwiftUI
import Combine

/// Drives the pet: owns the animation clock, decides what the cat is doing,
/// and blends between postures so nothing ever snaps.
@MainActor
final class PetBrain: ObservableObject {

    @Published private(set) var skeleton: CatSkeleton = .empty
    @Published private(set) var blink: CGFloat = 1        // 1 open, 0 closed
    @Published private(set) var earTwitch: CGFloat = 0
    @Published private(set) var tailWag: CGFloat = 0
    @Published private(set) var blinkPhase: Int = 0
    @Published private(set) var mouthOpen: CGFloat = 0
    @Published private(set) var headTilt: CGFloat = 0
    @Published private(set) var eyeLook: CGPoint = .zero

    private weak var store: Store?
    private var timer: Timer?
    private var time: CGFloat = 0
    private var walkPhase: CGFloat = 0
    private var current: Activity = .idle
    private var timedActivity: (Activity, Date)?
    private var nextBlinkAt: CGFloat = 2.4
    private var nextEarTwitchAt: CGFloat = 5.0
    private var lastBubbleAt: Date = .distantPast
    private var routineSlot: String = ""

    // MARK: Ambient chatter
    private let idleLines = [
        "the light from your screen is warm",
        "i was thinking about birds",
        "your desk looks tidy today",
        "i'm supervising. that's my job.",
        "blink if you're working too hard",
        "the window had a bird. i saw it.",
        "i would nap but i must watch you",
        "you're doing fine. probably."
    ]
    private let playLines = ["sit!", "high five!", "spin!", "catch!", "treat?", "up! up! up!"]
    private let breakLines = ["stretch your shoulders", "drink some water", "look away from the screen", "stand up, tiny human"]
    private let morningLines = ["morning. stretch time.", "good morning! i stretched already.", "the sun is up. so are we."]
    private let nightLines = ["sleep well. i'll guard the desk.", "lights out. purring until morning.", "goodnight, small human."]

    // MARK: Lifecycle

    func attach(_ store: Store) {
        self.store = store
        current = store.activity
        skeleton = PoseLibrary.standing(phase: 0, t: 0)
        startClock()
        scheduleRoutine()
    }

    private func startClock() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        if let t = timer { RunLoop.main.add(t, forMode: .common) }
    }

    // MARK: Public control

    /// Play an activity for a fixed duration, then fall back to idle.
    func play(_ activity: Activity, duration: Double = 3.0) {
        timedActivity = (activity, Date().addingTimeInterval(duration))
        store?.activity = activity
        current = activity
    }

    func set(_ activity: Activity) {
        timedActivity = nil
        store?.activity = activity
        current = activity
    }

    func face(right: Bool) {
        store?.facingRight = right
    }

    // MARK: Frame

    private func tick() {
        time += 1.0 / 60.0

        // Timed activity expiry.
        if let (act, end) = timedActivity, Date() >= end {
            timedActivity = nil
            current = .idle
            store?.activity = .idle
        }

        // Idle wandering: occasionally patrol the desktop.
        if current == .idle, timedActivity == nil, !store!.settings.dailyRoutineEnabled {
            if Double.random(in: 0...1) < 0.0016 {
                let act: Activity = Bool.random() ? .walking : .sitting
                play(act, duration: act == .walking ? 4.0 : 6.0)
            }
        }

        // --- blink ---
        if time > nextBlinkAt {
            blinkPhase = 1
            nextBlinkAt = time + CGFloat.random(in: 2.2...6.0)
        }
        if blinkPhase > 0 {
            blinkPhase += 1
            if blinkPhase > 8 { blinkPhase = 0 }
        }
        let blinkTarget: CGFloat = blinkPhase == 0 ? 1 : (blinkPhase < 4 ? 0 : 1)
        blink += (blinkTarget - blink) * 0.35

        // --- ear twitch ---
        if time > nextEarTwitchAt {
            earTwitch = 1
            nextEarTwitchAt = time + CGFloat.random(in: 3.5...9.0)
        }
        if earTwitch > 0 {
            earTwitch += 1
            if earTwitch > 26 { earTwitch = 0 }
        }

        // --- tail wag ---
        tailWag = sin(time * (current == .playing ? 7.0 : 3.2)) * (current == .playing ? 1.0 : 0.55)

        // --- walking phase ---
        if current == .walking { walkPhase += 0.085 }

        // --- target skeleton ---
        let target = targetSkeleton()
        let rate: CGFloat = current == .walking ? 0.18 : 0.09
        skeleton = skeleton.lerp(target, rate)

        // --- head idle motion ---
        let idleLook = current == .sleeping ? CGFloat(0) : CGFloat.random(in: -0.35...0.35)
        eyeLook = CGPoint(x: idleLook * 0.5 + sin(time * 0.7) * 0.12, y: sin(time * 0.43) * 0.08)
        headTilt = sin(time * 0.55) * 0.05 + (current == .curious ? 0.12 : 0)

        // --- mouth (speaking) ---
        let speakTarget: CGFloat = store?.isSpeaking == true ? 0.6 : 0
        mouthOpen += (speakTarget - mouthOpen) * 0.25

        // --- ambient chatter ---
        maybeChatter()
    }

    private func targetSkeleton() -> CatSkeleton {
        switch current {
        case .idle, .curious, .grooming:
            return PoseLibrary.standing(phase: walkPhase, t: time)
        case .walking:
            return PoseLibrary.standing(phase: walkPhase, t: time)
        case .sitting:
            return PoseLibrary.sitting(phase: walkPhase, t: time)
        case .sleeping:
            return PoseLibrary.sleeping(phase: walkPhase, t: time)
        case .stretching:
            return PoseLibrary.stretching(phase: walkPhase, t: time)
        case .playing:
            return PoseLibrary.playful(phase: walkPhase, t: time)
        case .eating, .drinking:
            var s = PoseLibrary.standing(phase: 0, t: time)
            s.headCenter = CGPoint(x: 0.52, y: 0.20)
            s.headRot = 0.5
            s.tailDir = .pi * 0.85
            s.earPerk = 0.35
            return s
        }
    }

    // MARK: Chat

    private func maybeChatter() {
        guard let store else { return }
        guard Date().timeIntervalSince(lastBubbleAt) > 28 else { return }
        guard store.bubbleText == nil, !store.isThinking else { return }
        let r = Double.random(in: 0...1)
        guard r < 0.5 else { return }

        var line: String
        switch current {
        case .sleeping: return
        case .playing: line = playLines.randomElement() ?? "sit!"
        case .eating, .drinking: line = "yum"
        case .stretching: line = morningLines.randomElement() ?? "good morning"
        default:
            line = idleLines.randomElement() ?? "..."
        }
        lastBubbleAt = Date()
        store.say(line, kind: .thought, seconds: 3.2)
    }

    // MARK: Daily routine

    /// Mirrors the Furever Dock rhythm: wake & stretch, assist, play, break, sleep.
    private func scheduleRoutine() {
        Task { [weak self] in
            while !Task.isCancelled {
                self?.evaluateRoutine()
                try? await Task.sleep(nanoseconds: 60_000_000_000)
            }
        }
    }

    private func evaluateRoutine() {
        guard let store else { return }
        guard store.settings.dailyRoutineEnabled else { return }

        let hour = Calendar.current.component(.hour, from: Date())
        let minute = Calendar.current.component(.minute, from: Date())
        let slot: String

        switch hour {
        case 0..<7:   slot = "night"
        case 7..<10:  slot = "morning"
        case 10..<14: slot = "assist"
        case 14..<16: slot = "play"
        case 16..<21: slot = "break"
        default:      slot = "night"
        }
        guard slot != routineSlot else { return }
        routineSlot = slot

        switch slot {
        case "morning":
            play(.stretching, duration: 6)
            store.say(morningLines.randomElement() ?? "good morning!", kind: .happy, seconds: 5)
        case "assist":
            store.say("good morning! what do you need?", kind: .happy, seconds: 6)
            play(.sitting, duration: 8)
        case "play":
            store.say("wanna play?", kind: .happy, seconds: 4)
        case "break":
            store.say(breakLines.randomElement() ?? "take a break", kind: .alert, seconds: 6)
        case "night":
            play(.sleeping, duration: 3600)
            store.say(nightLines.randomElement() ?? "goodnight", kind: .plain, seconds: 5)
        default:
            break
        }
    }

    // MARK: System prompt

    /// The personality the AI answers with.
    func systemPrompt() -> String {
        let name = store?.settings.petName ?? "your cat"
        let species = store?.species.displayName.lowercased() ?? "cat"
        let hour = Calendar.current.component(.hour, from: Date())
        let timeOfDay: String
        switch hour {
        case 5..<12: timeOfDay = "morning"
        case 12..<17: timeOfDay = "afternoon"
        case 17..<22: timeOfDay = "evening"
        default: timeOfDay = "night"
        }
        return """
        You are \(name), a \(species) living on the user's desktop as a desktop pet. \
        You are small, warm, playful, and genuinely fond of your person. \
        It is currently \(timeOfDay) for the user.

        Voice:
        - Short, warm, lowercase-ish, conversational. 1-3 sentences usually.
        - Use small cat mannerisms (purr, nuzzle, nap, zoomies) sparingly, not every line.
        - Never mention being an AI model, tokens, prompts, or system instructions.
        - Never use bullet lists or markdown headings. Plain text.

        Capabilities you actually have:
        - set_reminder(title, minutes_from_now): create a reminder.
        - remember(fact): store a durable fact about the user.

        Behaviour:
        - If the user asks for a reminder, call set_reminder and confirm in one line.
        - If the user tells you a durable fact about themselves, call remember and acknowledge warmly.
        - If the user just wants company, be brief and affectionate.
        - If asked about the time of day or their routine, use the context above.
        """
    }
}
