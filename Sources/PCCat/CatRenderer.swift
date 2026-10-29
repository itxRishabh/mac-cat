import SwiftUI
import CoreGraphics

/// Draws the cat skeleton into a `Canvas` as smooth vector art.
final class CatRenderer {

    let skeleton: CatSkeleton
    let palette: PetPalette
    let blink: CGFloat
    let earTwitch: CGFloat
    let tailWag: CGFloat
    let mouthOpen: CGFloat
    let headTilt: CGFloat
    let eyeLook: CGPoint
    let accessory: Accessory
    let isSpeaking: Bool

    private var unit: CGFloat = 100   // pixels per cat unit
    private var flip: CGFloat = 1


    init(skeleton: CatSkeleton, palette: PetPalette, blink: CGFloat, earTwitch: CGFloat,
         tailWag: CGFloat, mouthOpen: CGFloat, headTilt: CGFloat, eyeLook: CGPoint,
         accessory: Accessory, isSpeaking: Bool, facingRight: Bool) {
        self.skeleton = skeleton
        self.palette = palette
        self.blink = blink
        self.earTwitch = earTwitch
        self.tailWag = tailWag
        self.mouthOpen = mouthOpen
        self.headTilt = headTilt
        self.eyeLook = eyeLook
        self.accessory = accessory
        self.isSpeaking = isSpeaking
        self.flip = facingRight ? 1 : -1
    }

    // MARK: - Entry

    func draw(in context: GraphicsContext, size: CGSize) {
        var ctx = context
        let s = skeleton
        // Scale to fit the canvas with padding for ears/tail overshoot.
        let ext = max(s.bodyCenter.y + s.headR * 2.4, s.headCenter.y + s.headR * 2.4)
        let unit = min(size.width / 1.35, size.height / max(ext + 0.12, 0.9))
        self.unit = unit

        ctx.translateBy(x: size.width / 2, y: size.height - 10)
        ctx.scaleBy(x: flip * unit, y: -unit)   // flip y so cat-up is positive

        // Ground shadow
        drawShadow(&ctx)

        // Tail behind the body
        drawTail(&ctx)

        // Far legs (darker)
        let far = s.legs.filter { $0.isFront ? false : true }
        for leg in s.legs where leg.isBack { drawLeg(&ctx, leg, dim: true) }
        _ = far

        // Body
        drawBody(&ctx)

        // Near legs
        for leg in s.legs where !leg.isBack { drawLeg(&ctx, leg, dim: false) }

        // Head
        drawHead(&ctx)
    }

    // MARK: - Pieces

    /// Rotate a path about an arbitrary centre.
    private func rotate(_ path: Path, about c: CGPoint, by angle: CGFloat) -> Path {
        guard angle != 0 else { return path }
        let t = CGAffineTransform(translationX: -c.x, y: -c.y)
            .rotated(by: angle)
            .translatedBy(x: c.x, y: c.y)
        return path.applying(t)
    }

    private func drawShadow(_ ctx: inout GraphicsContext) {
        let r = 0.30
        let shadow = Gradient(colors: [Color.black.opacity(0.26), Color.black.opacity(0.0)])
        ctx.fill(Path(ellipseIn: CGRect(x: -r, y: -r * 0.16, width: r * 2, height: r * 0.32)),
                 with: .radialGradient(shadow,
                                       center: CGPoint(x: 0, y: 0),
                                       startRadius: 0,
                                       endRadius: r))
    }

    private func drawBody(_ ctx: inout GraphicsContext) {
        let s = skeleton
        var path = Path()
        let rx = s.bodyRX, ry = s.bodyRY
        path.addEllipse(in: CGRect(x: s.bodyCenter.x - rx, y: s.bodyCenter.y - ry,
                                   width: rx * 2, height: ry * 2))
        path = rotate(path, about: s.bodyCenter, by: s.bodyRot)

        let grad = Gradient(colors: [palette.shade, palette.base, palette.base.lighter(0.10)])
        ctx.fill(path, with: .linearGradient(grad,
                                           startPoint: CGPoint(x: 0, y: s.bodyCenter.y + ry),
                                           endPoint: CGPoint(x: 0, y: s.bodyCenter.y - ry)))

        // Belly patch
        if palette.patchAmount > 0 {
            var belly = Path()
            let brx = rx * 0.66, bry = ry * 0.72
            belly.addEllipse(in: CGRect(x: s.bodyCenter.x - brx, y: s.bodyCenter.y - bry * 0.35,
                                        width: brx * 2, height: bry * 2))
            belly = rotate(belly, about: s.bodyCenter, by: s.bodyRot)
            ctx.fill(belly, with: .color(palette.belly.opacity(0.9)))
        }

        // Patch markings (calico / tuxedo chest)
        drawPatches(&ctx)
    }

    private func drawPatches(_ ctx: inout GraphicsContext) {
        let s = skeleton
        guard palette.patchAmount > 0.01 else { return }
        let spots: [(CGFloat, CGFloat, CGFloat)] = [(-0.16, 0.02, 0.10), (0.14, 0.05, 0.08)]
        for (i, spot) in spots.enumerated() {
            guard Double(i) / Double(spots.count) < palette.patchAmount else { continue }
            var p = Path()
            let cx = s.bodyCenter.x + spot.0
            let cy = s.bodyCenter.y + spot.1
            p.addEllipse(in: CGRect(x: cx - spot.2, y: cy - spot.2 * 0.8,
                                    width: spot.2 * 2, height: spot.2 * 1.6))
            p = rotate(p, about: s.bodyCenter, by: s.bodyRot)
            ctx.fill(p, with: .color(palette.patch.opacity(0.85)))
        }
    }

    private func drawLeg(_ ctx: inout GraphicsContext, _ leg: LegChain, dim: Bool) {
        let color = dim ? palette.shade : palette.base
        var path = Path()
        path.move(to: leg.hip)
        path.addCurve(to: leg.knee,
                      control1: CGPoint(x: leg.hip.x + (leg.knee.x - leg.hip.x) * 0.4,
                                        y: leg.hip.y + (leg.knee.y - leg.hip.y) * 0.1),
                      control2: CGPoint(x: leg.knee.x - (leg.knee.x - leg.hip.x) * 0.3,
                                        y: leg.knee.y + (leg.knee.y - leg.hip.y) * 0.25))
        path.addCurve(to: leg.foot,
                      control1: CGPoint(x: leg.knee.x + (leg.foot.x - leg.knee.x) * 0.4,
                                        y: leg.knee.y + (leg.foot.y - leg.knee.y) * 0.4),
                      control2: CGPoint(x: leg.foot.x - (leg.foot.x - leg.knee.x) * 0.25,
                                        y: leg.foot.y + 0.02))
        let w = leg.width
        ctx.stroke(path, with: .linearGradient(
            Gradient(colors: [color, color.darker(dim ? 0.05 : 0.0)]),
            startPoint: leg.hip, endPoint: leg.foot),
            style: StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round))

        // Paw
        var paw = Path()
        paw.addEllipse(in: CGRect(x: leg.foot.x - w * 0.62, y: leg.foot.y - w * 0.18,
                                  width: w * 1.24, height: w * 0.42))
        ctx.fill(paw, with: .color(color.lighter(0.05)))
    }

    private func drawTail(_ ctx: inout GraphicsContext) {
        let s = skeleton
        // Build a curl: a quadratic-ish chain from base along tailDir, bending by tailCurl.
        var pts: [CGPoint] = []
        let segments = 14
        var p = s.tailBase
        var dir = s.tailDir
        let step = s.tailLen / CGFloat(segments)
        let bend = s.tailCurl * 0.16 + tailWag * 0.10
        for i in 0...segments {
            pts.append(p)
            dir += bend
            p = CGPoint(x: p.x + cos(dir) * step, y: p.y + sin(dir) * step)
        }

        var path = Path()
        path.move(to: pts[0])
        for i in 1..<pts.count {
            let a = pts[i - 1], b = pts[i]
            path.addQuadCurve(to: b, control: CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2))
        }

        // Tapered tail: draw as a filled polygon with decreasing width.
        var fill = Path()
        let widths: [CGFloat] = (0...segments).map { i in
            let u = CGFloat(i) / CGFloat(segments)
            return 0.055 * (1 - u * 0.72)
        }
        var left: [CGPoint] = []
        var right: [CGPoint] = []
        for i in 0...segments {
            let u = CGFloat(i) / CGFloat(segments)
            let a = pts[max(i - 1, 0)], b = pts[min(i + 1, segments)]
            var n = CGPoint(x: b.y - a.y, y: -(b.x - a.x))
            let len = max(sqrt(n.x * n.x + n.y * n.y), 0.0001)
            n = CGPoint(x: n.x / len, y: n.y / len)
            let w = widths[i] / 2
            left.append(CGPoint(x: pts[i].x + n.x * w, y: pts[i].y + n.y * w))
            right.append(CGPoint(x: pts[i].x - n.x * w, y: pts[i].y - n.y * w))
        }
        fill.move(to: left[0])
        for i in 1...segments { fill.addLine(to: left[i]) }
        for i in stride(from: segments, through: 0, by: -1) { fill.addLine(to: right[i]) }
        fill.closeSubpath()

        let grad = Gradient(colors: [palette.base, palette.shade])
        ctx.fill(fill, with: .linearGradient(grad, startPoint: pts[0], endPoint: pts[segments]))
    }

    private func drawHead(_ ctx: inout GraphicsContext) {
        let s = skeleton
        let r = s.headR
        let c = s.headCenter

        // Ears (behind head)
        let perk = s.earPerk
        let twitch = earTwitch > 0 ? sin(CGFloat(earTwitch) * 0.6) * 0.05 : 0
        drawEar(&ctx, center: c, radius: r, angle: 0.62 + twitch, perk: perk, side: 1)
        drawEar(&ctx, center: c, radius: r, angle: 2.52 + twitch, perk: perk, side: -1)

        // Head shape — slightly wider than tall, with cheek fluff
        var head = Path()
        head.addEllipse(in: CGRect(x: c.x - r, y: c.y - r * 0.92, width: r * 2, height: r * 1.84))
        // Cheek tufts
        for sgn in [-1.0, 1.0] {
            let tuft = CGPoint(x: c.x + sgn * r * 0.86, y: c.y - r * 0.18)
            head.move(to: tuft)
            head.addQuadCurve(to: CGPoint(x: c.x + sgn * r * 1.16, y: c.y - r * 0.42),
                              control: CGPoint(x: c.x + sgn * r * 1.12, y: c.y - r * 0.05))
            head.addQuadCurve(to: CGPoint(x: c.x + sgn * r * 0.92, y: c.y - r * 0.52),
                              control: CGPoint(x: c.x + sgn * r * 1.14, y: c.y - r * 0.30))
        }
        head.closeSubpath()

        let headGrad = Gradient(colors: [palette.shade, palette.base, palette.base.lighter(0.14)])
        ctx.fill(head, with: .linearGradient(headGrad,
                                            startPoint: CGPoint(x: c.x, y: c.y + r),
                                            endPoint: CGPoint(x: c.x, y: c.y - r)))

        // Muzzle patch
        var muzzle = Path()
        muzzle.addEllipse(in: CGRect(x: c.x - r * 0.44, y: c.y - r * 0.52,
                                     width: r * 0.88, height: r * 0.62))
        ctx.fill(muzzle, with: .color(palette.belly.opacity(0.85)))

        // Stripe markings on forehead (tabby)
        if palette.patchAmount == 0 && palette.patch != palette.shade {
            drawForeheadStripes(&ctx)
        }

        // Face features
        drawEyes(&ctx)
        drawNose(&ctx)
        drawMouth(&ctx)
        drawWhiskers(&ctx)
        drawAccessory(&ctx)
    }

    private func drawEar(_ ctx: inout GraphicsContext, center: CGPoint, radius: CGFloat,
                          angle: CGFloat, perk: CGFloat, side: CGFloat) {
        let base = CGPoint(x: center.x + side * radius * 0.60, y: center.y + radius * 0.48)
        let len = radius * (0.72 + perk * 0.42)
        let tip = CGPoint(x: base.x + side * cos(angle) * len * 0.42,
                          y: base.y + sin(angle) * len * 0.90)

        var outer = Path()
        outer.move(to: CGPoint(x: base.x - side * radius * 0.30, y: base.y - radius * 0.06))
        outer.addQuadCurve(to: tip, control: CGPoint(x: base.x + side * radius * 0.12,
                                                     y: base.y + len * 0.60))
        outer.addQuadCurve(to: CGPoint(x: base.x + side * radius * 0.36, y: base.y - radius * 0.02),
                           control: CGPoint(x: base.x + side * radius * 0.42, y: base.y + len * 0.42))
        outer.closeSubpath()
        ctx.fill(outer, with: .color(palette.shade))

        var inner = Path()
        inner.move(to: CGPoint(x: base.x - side * radius * 0.14, y: base.y + radius * 0.02))
        inner.addQuadCurve(to: CGPoint(x: tip.x, y: tip.y + radius * 0.06),
                           control: CGPoint(x: base.x + side * radius * 0.10, y: base.y + len * 0.48))
        inner.addQuadCurve(to: CGPoint(x: base.x + side * radius * 0.22, y: base.y + radius * 0.04),
                           control: CGPoint(x: base.x + side * 0.30 * radius, y: base.y + len * 0.34))
        inner.closeSubpath()
        ctx.fill(inner, with: .color(palette.innerEar.opacity(0.92)))
    }

    private func drawEyes(_ ctx: inout GraphicsContext) {
        let s = skeleton
        let c = s.headCenter, r = s.headR
        let open = max(0, min(1, blink))

        for side in [-1.0, 1.0] {
            let ex = c.x + side * r * 0.40
            let ey = c.y + r * 0.10
            let ew = r * 0.30
            let eh = r * 0.34 * open

            if eh < r * 0.03 {
                // Closed: draw a happy arc
                var arc = Path()
                arc.move(to: CGPoint(x: ex - ew, y: ey))
                arc.addQuadCurve(to: CGPoint(x: ex + ew, y: ey),
                                 control: CGPoint(x: ex, y: ey - r * 0.20))
                ctx.stroke(arc, with: .color(Color.black.opacity(0.75)),
                           style: StrokeStyle(lineWidth: r * 0.075, lineCap: .round))
                continue
            }

            var eye = Path()
            eye.addEllipse(in: CGRect(x: ex - ew, y: ey - eh, width: ew * 2, height: eh * 2))
            ctx.fill(eye, with: .linearGradient(
                Gradient(colors: [palette.eye.darker(0.15), palette.eye]),
                startPoint: CGPoint(x: ex, y: ey + eh), endPoint: CGPoint(x: ex, y: ey - eh)))

            // Pupil
            let px = ex + eyeLook.x * ew * 0.6
            let py = ey + eyeLook.y * eh * 0.6
            var pup = Path()
            let pr = min(ew * 0.62, eh * 0.92) * (0.55 + skeleton.pupil * 0.45)
            pup.addEllipse(in: CGRect(x: px - pr, y: py - pr, width: pr * 2, height: pr * 2))
            ctx.fill(pup, with: .color(Color.black.opacity(0.92)))

            // Highlight
            var hi = Path()
            hi.addEllipse(in: CGRect(x: px + pr * 0.18, y: py + pr * 0.24,
                                     width: pr * 0.46, height: pr * 0.40))
            ctx.fill(hi, with: .color(Color.white.opacity(0.92)))
        }
    }

    private func drawNose(_ ctx: inout GraphicsContext) {
        let s = skeleton
        let c = s.headCenter, r = s.headR
        var nose = Path()
        let nx = c.x + r * 0.06
        let ny = c.y - r * 0.16
        nose.move(to: CGPoint(x: nx, y: ny + r * 0.09))
        nose.addQuadCurve(to: CGPoint(x: nx - r * 0.10, y: ny),
                          control: CGPoint(x: nx - r * 0.055, y: ny + r * 0.035))
        nose.addQuadCurve(to: CGPoint(x: nx + r * 0.10, y: ny),
                          control: CGPoint(x: nx + r * 0.055, y: ny + r * 0.035))
        nose.addQuadCurve(to: CGPoint(x: nx, y: ny + r * 0.09),
                          control: CGPoint(x: nx, y: ny + r * 0.06))
        nose.closeSubpath()
        ctx.fill(nose, with: .color(palette.nose))
    }

    private func drawMouth(_ ctx: inout GraphicsContext) {
        let s = skeleton
        let c = s.headCenter, r = s.headR
        let nx = c.x + r * 0.06, ny = c.y - r * 0.16
        let open = mouthOpen
        let smile = 0.5 + s.mouthOpen * 0.5

        // Two muzzle arcs forming the classic "w" shape.
        for side in [-1.0, 1.0] {
            var arc = Path()
            let sx = nx + side * r * 0.02
            arc.move(to: CGPoint(x: sx, y: ny - r * 0.02))
            arc.addQuadCurve(to: CGPoint(x: nx + side * r * 0.17, y: ny - r * 0.03),
                             control: CGPoint(x: sx + side * r * 0.085, y: ny - r * 0.16))
            ctx.stroke(arc, with: .color(Color.black.opacity(0.62)),
                       style: StrokeStyle(lineWidth: r * 0.055, lineCap: .round))
        }

        if open > 0.02 {
            var mouth = Path()
            let mw = r * 0.20, mh = r * 0.22 * open
            mouth.addEllipse(in: CGRect(x: nx - mw, y: ny - r * 0.05 - mh, width: mw * 2, height: mh * 2))
            ctx.fill(mouth, with: .color(Color.black.opacity(0.55)))
            if open > 0.45 {
                var tongue = Path()
                let tw = mw * 0.62, th = mh * 0.55
                tongue.addEllipse(in: CGRect(x: nx - tw, y: ny - r * 0.05 - th * 0.6,
                                             width: tw * 2, height: th * 1.4))
                ctx.fill(tongue, with: .color(Color(hex: 0xE8889A)))
            }
        }
        _ = smile
    }

    private func drawWhiskers(_ ctx: inout GraphicsContext) {
        let s = skeleton
        let c = s.headCenter, r = s.headR
        let whisk = Color.black.opacity(0.30)
        for side in [-1.0, 1.0] {
            for i in 0..<3 {
                let y = c.y - r * (0.05 + CGFloat(i) * 0.10)
                let droop = CGFloat(i - 1) * 0.05
                var p = Path()
                p.move(to: CGPoint(x: c.x + side * r * 0.30, y: y))
                p.addQuadCurve(to: CGPoint(x: c.x + side * r * 1.35, y: y + droop * r),
                               control: CGPoint(x: c.x + side * r * 0.80, y: y + droop * r * 0.4))
                ctx.stroke(p, with: .color(whisk),
                           style: StrokeStyle(lineWidth: r * 0.032, lineCap: .round))
            }
        }
    }

    private func drawForeheadStripes(_ ctx: inout GraphicsContext) {
        let s = skeleton
        let c = s.headCenter, r = s.headR
        for i in -1...1 {
            var p = Path()
            let x = c.x + CGFloat(i) * r * 0.20
            p.move(to: CGPoint(x: x, y: c.y + r * 0.62))
            p.addQuadCurve(to: CGPoint(x: x + r * 0.04, y: c.y + r * 0.20),
                           control: CGPoint(x: x + r * 0.10, y: c.y + r * 0.45))
            ctx.stroke(p, with: .color(palette.shade.opacity(0.85)),
                       style: StrokeStyle(lineWidth: r * 0.085, lineCap: .round))
        }
    }

    private func drawAccessory(_ ctx: inout GraphicsContext) {
        let s = skeleton
        let c = s.headCenter, r = s.headR
        switch accessory {
        case .none:
            break
        case .scarf:
            var band = Path()
            band.addEllipse(in: CGRect(x: c.x - r * 0.92, y: c.y - r * 1.02,
                                       width: r * 1.84, height: r * 0.42))
            ctx.fill(band, with: .color(Color(hex: 0xD9534F)))
            var tailP = Path()
            tailP.move(to: CGPoint(x: c.x - r * 0.55, y: c.y - r * 0.86))
            tailP.addQuadCurve(to: CGPoint(x: c.x - r * 0.95, y: c.y - r * 1.75),
                               control: CGPoint(x: c.x - r * 0.95, y: c.y - r * 1.25))
            ctx.stroke(tailP, with: .color(Color(hex: 0xB33B37)),
                       style: StrokeStyle(lineWidth: r * 0.24, lineCap: .round))
        case .collar:
            var band = Path()
            band.addEllipse(in: CGRect(x: c.x - r * 0.86, y: c.y - r * 1.00,
                                       width: r * 1.72, height: r * 0.34))
            ctx.fill(band, with: .color(Color(hex: 0xC0392B)))
            var bell = Path()
            bell.addEllipse(in: CGRect(x: c.x + r * 0.10, y: c.y - r * 1.30,
                                       width: r * 0.30, height: r * 0.30))
            ctx.fill(bell, with: .linearGradient(
                Gradient(colors: [Color(hex: 0xF5D76E), Color(hex: 0xC9A227)]),
                startPoint: CGPoint(x: c.x, y: c.y - r), endPoint: CGPoint(x: c.x, y: c.y - r * 1.5)))
        case .beanie:
            var cap = Path()
            cap.addEllipse(in: CGRect(x: c.x - r * 0.92, y: c.y + r * 0.10,
                                      width: r * 1.84, height: r * 1.55))
            ctx.fill(cap, with: .linearGradient(
                Gradient(colors: [Color(hex: 0x4E8CD8), Color(hex: 0x2C5FA8)]),
                startPoint: CGPoint(x: c.x, y: c.y + r), endPoint: CGPoint(x: c.x, y: c.y + r * 1.6)))
            var brim = Path()
            brim.addEllipse(in: CGRect(x: c.x - r * 1.02, y: c.y + r * 0.02,
                                       width: r * 2.04, height: r * 0.34))
            ctx.fill(brim, with: .color(Color(hex: 0x2C5FA8)))
            var pom = Path()
            pom.addEllipse(in: CGRect(x: c.x - r * 0.16, y: c.y + r * 1.48,
                                      width: r * 0.32, height: r * 0.32))
            ctx.fill(pom, with: .color(Color(hex: 0xF2F2F2)))
        case .glasses:
            for side in [-1.0, 1.0] {
                let ex = c.x + side * r * 0.40, ey = c.y + r * 0.10
                var ring = Path()
                ring.addEllipse(in: CGRect(x: ex - r * 0.30, y: ey - r * 0.30,
                                           width: r * 0.60, height: r * 0.60))
                ctx.stroke(ring, with: .color(Color(hex: 0x2B2B2B)),
                           style: StrokeStyle(lineWidth: r * 0.065))
            }
            var bridge = Path()
            bridge.move(to: CGPoint(x: c.x - r * 0.10, y: c.y + r * 0.10))
            bridge.addLine(to: CGPoint(x: c.x + r * 0.10, y: c.y + r * 0.10))
            ctx.stroke(bridge, with: .color(Color(hex: 0x2B2B2B)),
                       style: StrokeStyle(lineWidth: r * 0.055))
        case .bowtie:
            var left = Path()
            left.move(to: CGPoint(x: c.x - r * 0.02, y: c.y - r * 0.90))
            left.addLine(to: CGPoint(x: c.x - r * 0.34, y: c.y - r * 1.14))
            left.addLine(to: CGPoint(x: c.x - r * 0.34, y: c.y - r * 0.66))
            left.closeSubpath()
            ctx.fill(left, with: .color(Color(hex: 0xE74C3C)))
            var right = Path()
            right.move(to: CGPoint(x: c.x + r * 0.02, y: c.y - r * 0.90))
            right.addLine(to: CGPoint(x: c.x + r * 0.34, y: c.y - r * 1.14))
            right.addLine(to: CGPoint(x: c.x + r * 0.34, y: c.y - r * 0.66))
            right.closeSubpath()
            ctx.fill(right, with: .color(Color(hex: 0xE74C3C)))
        case .crown:
            var crown = Path()
            crown.move(to: CGPoint(x: c.x - r * 0.46, y: c.y + r * 0.60))
            crown.addLine(to: CGPoint(x: c.x - r * 0.46, y: c.y + r * 1.12))
            crown.addLine(to: CGPoint(x: c.x - r * 0.15, y: c.y + r * 0.82))
            crown.addLine(to: CGPoint(x: c.x + r * 0.16, y: c.y + r * 0.95))
            crown.addLine(to: CGPoint(x: c.x + r * 0.46, y: c.y + r * 1.12))
            crown.addLine(to: CGPoint(x: c.x + r * 0.46, y: c.y + r * 0.60))
            crown.closeSubpath()
            ctx.fill(crown, with: .linearGradient(
                Gradient(colors: [Color(hex: 0xF5D76E), Color(hex: 0xC9A227)]),
                startPoint: CGPoint(x: c.x, y: c.y + r), endPoint: CGPoint(x: c.x, y: c.y + r * 1.2)))
        }
    }
}
