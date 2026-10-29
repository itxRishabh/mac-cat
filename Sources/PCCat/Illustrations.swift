import AppKit
import SwiftUI
import ImageIO
import QuartzCore

/// A decoded multi-frame animation. One Furever Dock WebP = one animation.
final class CatAnimation {
    let frames: [CGImage]
    let total: TimeInterval
    private let startTimes: [Double]

    init(frames: [CGImage], delays: [Double]) {
        self.frames = frames
        var t: TimeInterval = 0
        var starts: [Double] = []
        for d in delays { starts.append(t); t += d }
        self.startTimes = starts
        self.total = t
    }

    /// Frame index at time `t` into the loop.
    func index(at t: TimeInterval) -> Int {
        guard !startTimes.isEmpty, total > 0 else { return 0 }
        let looped = t.truncatingRemainder(dividingBy: total)
        var lo = 0, hi = startTimes.count - 1
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            if startTimes[mid] <= looped { lo = mid } else { hi = mid - 1 }
        }
        return lo
    }
}

// MARK: - Global decoders (nonisolated, safe to run off-main)

/// Decode every frame of a multi-frame WebP/GIF, downscaled to `maxDim`.
func decodeWebpFrames(_ url: URL, maxDim: CGFloat) -> CatAnimation? {
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    let count = CGImageSourceGetCount(src)
    guard count > 1 else {
        guard let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
        let frame = downscaleImage(img, maxDim: maxDim)
        return CatAnimation(frames: [frame, frame], delays: [1.0, 1.0])
    }

    var frames: [CGImage] = []
    var delays: [Double] = []
    frames.reserveCapacity(count)
    delays.reserveCapacity(count)

    for i in 0..<count {
        guard let raw = CGImageSourceCreateImageAtIndex(src, i, nil) else { continue }
        frames.append(downscaleImage(raw, maxDim: maxDim))

        // Animated WebP exposes a per-frame "DelayTime"; GIF uses kCGImagePropertyGIFDelayTime.
        var delay = 0.08
        if let props = CGImageSourceCopyPropertiesAtIndex(src, i, nil) as? [CFString: Any] {
            if let webp = props["{WebP}" as CFString] as? [CFString: Any] {
                for (k, v) in webp {
                    let key = String(k)
                    if key.lowercased().contains("delay"),
                       let d = v as? Double, d > 0.015, d < 2.0 {
                        delay = d
                        break
                    }
                }
            } else if let gif = props[kCGImagePropertyGIFDictionary] as? [CFString: Any],
                      let d = gif[kCGImagePropertyGIFDelayTime] as? Double, d > 0.015 {
                delay = d
            }
        }
        delays.append(delay)
    }
    guard frames.count > 1 else { return nil }
    return CatAnimation(frames: frames, delays: delays)
}

/// Downscale a CGImage so its longest edge is at most `maxDim`.
func downscaleImage(_ img: CGImage, maxDim: CGFloat) -> CGImage {
    let w = img.width, h = img.height
    let scale = maxDim / CGFloat(max(w, h))
    guard scale < 1 else { return img }
    let nw = max(1, Int(CGFloat(w) * scale))
    let nh = max(1, Int(CGFloat(h) * scale))
    let cs = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(data: nil, width: nw, height: nh,
                              bitsPerComponent: 8, bytesPerRow: 0,
                              space: cs,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        return img
    }
    ctx.interpolationQuality = .high
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: nw, height: nh))
    return ctx.makeImage() ?? img
}

// MARK: - The player

/// Loads & plays the local Furever Dock illustration animations
/// (animated WebP cats + flowers GIF).
@MainActor
final class CatArt: ObservableObject {

    enum Kind: String, CaseIterable {
        case hero = "hero-cat"
        case morning = "morning-cat"
        case play = "play-cat"
        case meditating = "break-cat"
        case sleep = "sleep-cat"

        var file: String { rawValue + ".webp" }
    }

    static let shared = CatArt()

    @Published private(set) var currentFrame: CGImage?
    @Published private(set) var flowersFrame: CGImage?
    @Published private(set) var sourceDescription: String = ""
    @Published private(set) var activeKind: Kind = .hero
    /// Flip the cat horizontally (true = mirror). Set when walking left.
    @Published private(set) var flipHorizontally = false

    private var cache: [Kind: CatAnimation] = [:]
    private var flowers: CatAnimation?
    private var clock: TimeInterval = 0
    private var clockTimer: Timer?
    private var pending: Set<Kind> = []
    private var flowersPending = false
    private var recentlyUsed: [Kind] = []

    private init() {
        scan()
    }

    // MARK: - Activity mapping

    static func kind(for activity: Activity) -> Kind {
        switch activity {
        case .sleeping: return .sleep
        case .stretching: return .morning
        case .playing: return .play
        case .meditating: return .meditating
        default: return .hero
        }
    }

    /// Switch which animation plays.
    func play(_ kind: Kind) {
        activeKind = kind
        clock = 0
        currentFrame = cache[kind]?.frames.first
        ensure(kind)
    }

    /// Mirror the cat horizontally — true = walk left, false = walk right.
    func setFlip(_ left: Bool) {
        flipHorizontally = left
    }

    func playFlowers() {
        ensureFlowers()
    }

    /// Re-scan the search folders (e.g. after the user drops files in).
    func rescan() {
        scan()
        for kind in Kind.allCases { ensure(kind) }
        ensureFlowers()
    }

    // MARK: - Playback clock

    /// 30fps clock advancing the active cat + flowers frames.
    func startClock() {
        guard clockTimer == nil else { return }
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.tick()
            }
        }
        timer.tolerance = 0.02
        RunLoop.main.add(timer, forMode: .common)
        clockTimer = timer
    }

    private var lastTick = CACurrentMediaTime()

    private func tick() {
        let now = CACurrentMediaTime()
        clock += now - lastTick
        lastTick = now

        if let anim = cache[activeKind] {
            let idx = anim.index(at: clock)
            if anim.frames[idx] !== currentFrame {
                currentFrame = anim.frames[idx]
            }
        }
        if let f = flowers {
            let idx = f.index(at: clock)
            if f.frames[idx] !== flowersFrame {
                flowersFrame = f.frames[idx]
            }
        }
    }

    func stopClock() {
        clockTimer?.invalidate()
        clockTimer = nil
    }

    // MARK: - Directory discovery

    var hasImages: Bool { !sourceDescription.isEmpty }

    private func scan() {
        for dir in Self.directoryCandidates() {
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent(Kind.hero.file).path) {
                sourceDescription = dir.path
                return
            }
        }
        sourceDescription = ""
    }

    static func directoryCandidates() -> [URL] {
        var dirs: [URL] = []
        if let res = Bundle.main.resourceURL?.appendingPathComponent("illustrations", isDirectory: true) {
            dirs.append(res)
        }
        var dir = Bundle.main.bundleURL
        for _ in 0..<9 {
            dirs.append(dir.appendingPathComponent("local/illustrations", isDirectory: true))
            let up = dir.deletingLastPathComponent()
            if up.path == dir.path { break }
            dir = up
        }
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        dirs.append(support.appendingPathComponent("PCCat/illustrations", isDirectory: true))
        return dirs
    }

    private func locate(_ kind: Kind) -> URL? {
        for dir in Self.directoryCandidates() {
            let url = dir.appendingPathComponent(kind.file)
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        return nil
    }

    private func locateFlowers() -> URL? {
        for dir in Self.directoryCandidates() {
            let url = dir.appendingPathComponent("flowers.gif")
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        return nil
    }

    // MARK: - Decoding (off main thread)

    private func ensure(_ kind: Kind) {
        if cache[kind] != nil || pending.contains(kind) { return }
        guard let url = locate(kind) else { return }
        pending.insert(kind)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let anim = decodeWebpFrames(url, maxDim: 480)
            guard let self else { return }
            Task { @MainActor in
                self.pending.remove(kind)
                guard let anim else { return }
                self.cache[kind] = anim
                self.recentlyUsed.append(kind)
                self.evictIfNeeded()
                if self.activeKind == kind {
                    self.currentFrame = anim.frames[0]
                }
            }
        }
    }

    private func ensureFlowers() {
        guard flowers == nil, !flowersPending else { return }
        guard let url = locateFlowers() else { return }
        flowersPending = true
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let anim = decodeWebpFrames(url, maxDim: 320)
            guard let self else { return }
            Task { @MainActor in
                self.flowersPending = false
                guard let anim else { return }
                self.flowers = anim
                self.flowersFrame = anim.frames[0]
            }
        }
    }

    private func evictIfNeeded() {
        guard cache.count > 2 else { return }
        if let oldest = recentlyUsed.first(where: { $0 != activeKind }) {
            cache[oldest] = nil
            recentlyUsed.removeAll { $0 == oldest }
        }
    }
}

// MARK: - SwiftUI views

/// Plays the current activity's Furever Dock animation.
struct CatAnimationView: View {
    @ObservedObject var art: CatArt
    var size: CGFloat = 300

    var body: some View {
        ZStack {
            Ellipse()
                .fill(Color.black.opacity(0.09))
                .frame(width: size * 0.62, height: size * 0.12)
                .blur(radius: 8)
                .offset(y: size * 0.42)

            if let frame = art.currentFrame {
                Image(decorative: frame, scale: 2)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .scaleEffect(x: art.flipHorizontally ? -1 : 1, y: 1, anchor: .center)
            } else {
                ProgressView().controlSize(.small)
            }
        }
    }
}

/// Loops the flowers GIF beside the cat.
struct FlowersView: View {
    @ObservedObject var art: CatArt
    var size: CGFloat = 96

    var body: some View {
        ZStack {
            if let frame = art.flowersFrame {
                Image(decorative: frame, scale: 2)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
            }
        }
        .frame(width: size, height: size)
    }
}
