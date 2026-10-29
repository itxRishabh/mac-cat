import Foundation
import CoreGraphics

// MARK: - Joints

/// One limb, expressed as a two-segment chain (hip → knee → foot).
struct LegChain {
    var hip: CGPoint
    var knee: CGPoint
    var foot: CGPoint
    var width: CGFloat
    var isFront: Bool
    var isBack: Bool

    static func lerp(_ a: LegChain, _ b: LegChain, _ t: CGFloat) -> LegChain {
        func p(_ x: CGPoint, _ y: CGPoint) -> CGPoint {
            CGPoint(x: x.x + (y.x - x.x) * t, y: y.y + (y.y - x.y) * t)
        }
        return LegChain(hip: p(a.hip, b.hip), knee: p(a.knee, b.knee), foot: p(a.foot, b.foot),
                        width: a.width + (b.width - a.width) * t,
                        isFront: t < 0.5 ? a.isFront : b.isFront,
                        isBack: t < 0.5 ? a.isBack : b.isBack)
    }
}

/// Complete pose of the cat in "cat units". y is UP-positive; origin is on the
/// ground between the paws, x+ points in the direction the cat faces.
struct CatSkeleton {
    var bodyCenter: CGPoint = .zero
    var bodyRX: CGFloat = 0.30
    var bodyRY: CGFloat = 0.175
    var bodyRot: CGFloat = 0
    var headCenter: CGPoint = .zero
    var headR: CGFloat = 0.155
    var headRot: CGFloat = 0
    var headYaw: CGFloat = 0        // -1 (away) .. 1 (toward viewer)
    var headTilt: CGFloat = 0
    var tailBase: CGPoint = .zero
    var tailDir: CGFloat = .pi * 0.75
    var tailCurl: CGFloat = 0.6
    var tailLen: CGFloat = 0.44
    var legs: [LegChain] = []
    var earPerk: CGFloat = 0.5      // 0 folded .. 1 alert
    var eyeOpen: CGFloat = 1
    var pupil: CGFloat = 0.55
    var mouthOpen: CGFloat = 0
    var tongue: CGFloat = 0
    var squash: CGFloat = 1
    var bodyLift: CGFloat = 0      // 0 grounded .. 1 airborne (pounce)

    static let empty = CatSkeleton()

    func lerp(_ o: CatSkeleton, _ t: CGFloat) -> CatSkeleton {
        func p(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
            CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
        }
        func f(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * t }
        var s = CatSkeleton()
        s.bodyCenter = p(bodyCenter, o.bodyCenter)
        s.bodyRX = f(bodyRX, o.bodyRX); s.bodyRY = f(bodyRY, o.bodyRY)
        s.bodyRot = f(bodyRot, o.bodyRot)
        s.headCenter = p(headCenter, o.headCenter)
        s.headR = f(headR, o.headR); s.headRot = f(headRot, o.headRot)
        s.headYaw = f(headYaw, o.headYaw); s.headTilt = f(headTilt, o.headTilt)
        s.tailBase = p(tailBase, o.tailBase)
        s.tailDir = f(tailDir, o.tailDir); s.tailCurl = f(tailCurl, o.tailCurl)
        s.tailLen = f(tailLen, o.tailLen)
        s.legs = zip(legs, o.legs).map { LegChain.lerp($0, $1, t) }
        if legs.count != o.legs.count { s.legs = t < 0.5 ? legs : o.legs }
        s.earPerk = f(earPerk, o.earPerk); s.eyeOpen = f(eyeOpen, o.eyeOpen)
        s.pupil = f(pupil, o.pupil); s.mouthOpen = f(mouthOpen, o.mouthOpen)
        s.tongue = f(tongue, o.tongue); s.squash = f(squash, o.squash)
        s.bodyLift = f(bodyLift, o.bodyLift)
        return s
    }
}

// MARK: - Pose library

/// Static skeletons for each postural family. The animator blends between them.
enum PoseLibrary {

    static func standing(phase: CGFloat, t: CGFloat) -> CatSkeleton {
        var s = CatSkeleton.empty
        let bob = sin(t * 2.0) * 0.006
        s.bodyCenter = CGPoint(x: 0, y: 0.40 + bob)
        s.bodyRX = 0.30; s.bodyRY = 0.175; s.bodyRot = 0
        s.headCenter = CGPoint(x: 0.40, y: 0.60 + bob)
        s.headR = 0.155
        s.tailBase = CGPoint(x: -0.29, y: 0.44)
        s.tailDir = .pi * 0.72
        s.tailCurl = 0.55
        s.tailLen = 0.46
        s.legs = fourLegs(phase: phase, spread: 1.0, bend: 0.0)
        s.earPerk = 0.65
        s.eyeOpen = 1
        return s
    }

    static func sitting(phase: CGFloat, t: CGFloat) -> CatSkeleton {
        var s = CatSkeleton.empty
        let bob = sin(t * 1.8) * 0.005
        s.bodyCenter = CGPoint(x: -0.02, y: 0.28 + bob)
        s.bodyRX = 0.27; s.bodyRY = 0.245; s.bodyRot = -0.16
        s.headCenter = CGPoint(x: 0.29, y: 0.63 + bob)
        s.headR = 0.16
        s.tailBase = CGPoint(x: -0.20, y: 0.10)
        s.tailDir = -0.35
        s.tailCurl = 0.75
        s.tailLen = 0.44
        // Folded haunches + straight front legs.
        s.legs = [
            LegChain(hip: CGPoint(x: 0.16, y: 0.30), knee: CGPoint(x: 0.17, y: 0.16),
                     foot: CGPoint(x: 0.18, y: 0.0), width: 0.055, isFront: true, isBack: false),
            LegChain(hip: CGPoint(x: 0.10, y: 0.30), knee: CGPoint(x: 0.11, y: 0.16),
                     foot: CGPoint(x: 0.12, y: 0.0), width: 0.052, isFront: true, isBack: false),
            LegChain(hip: CGPoint(x: -0.15, y: 0.14), knee: CGPoint(x: -0.28, y: 0.10),
                     foot: CGPoint(x: -0.30, y: 0.0), width: 0.085, isFront: false, isBack: true),
            LegChain(hip: CGPoint(x: -0.09, y: 0.16), knee: CGPoint(x: -0.22, y: 0.11),
                     foot: CGPoint(x: -0.24, y: 0.0), width: 0.080, isFront: false, isBack: true)
        ]
        s.earPerk = 0.7
        s.eyeOpen = 1
        return s
    }

    static func sleeping(phase: CGFloat, t: CGFloat) -> CatSkeleton {
        var s = CatSkeleton.empty
        let breathe = sin(t * 0.9) * 0.010
        s.bodyCenter = CGPoint(x: 0.0, y: 0.15 + breathe)
        s.bodyRX = 0.34; s.bodyRY = 0.155; s.bodyRot = 0.02
        s.headCenter = CGPoint(x: 0.30, y: 0.15 + breathe)
        s.headR = 0.155
        s.headRot = 0.12
        s.tailBase = CGPoint(x: -0.30, y: 0.14)
        s.tailDir = -0.2
        s.tailCurl = 0.9
        s.tailLen = 0.42
        // Tucked legs — small folded stubs under the body.
        s.legs = [
            LegChain(hip: CGPoint(x: 0.22, y: 0.11), knee: CGPoint(x: 0.30, y: 0.05),
                     foot: CGPoint(x: 0.34, y: 0.0), width: 0.055, isFront: true, isBack: false),
            LegChain(hip: CGPoint(x: 0.14, y: 0.11), knee: CGPoint(x: 0.22, y: 0.05),
                     foot: CGPoint(x: 0.26, y: 0.0), width: 0.052, isFront: true, isBack: false),
            LegChain(hip: CGPoint(x: -0.16, y: 0.11), knee: CGPoint(x: -0.10, y: 0.05),
                     foot: CGPoint(x: -0.04, y: 0.0), width: 0.070, isFront: false, isBack: true),
            LegChain(hip: CGPoint(x: -0.08, y: 0.11), knee: CGPoint(x: -0.02, y: 0.05),
                     foot: CGPoint(x: 0.04, y: 0.0), width: 0.068, isFront: false, isBack: true)
        ]
        s.earPerk = 0.12
        s.eyeOpen = 0
        s.pupil = 0.2
        return s
    }

    static func stretching(phase: CGFloat, t: CGFloat) -> CatSkeleton {
        var s = CatSkeleton.empty
        s.bodyCenter = CGPoint(x: -0.06, y: 0.36)
        s.bodyRX = 0.36; s.bodyRY = 0.15; s.bodyRot = 0.10
        s.headCenter = CGPoint(x: 0.46, y: 0.30)
        s.headR = 0.15
        s.headRot = -0.12
        s.tailBase = CGPoint(x: -0.34, y: 0.36)
        s.tailDir = .pi * 0.55
        s.tailCurl = 0.35
        s.tailLen = 0.48
        // Front legs reaching far forward, rear pushed back and high.
        s.legs = [
            LegChain(hip: CGPoint(x: 0.18, y: 0.32), knee: CGPoint(x: 0.42, y: 0.16),
                     foot: CGPoint(x: 0.60, y: 0.0), width: 0.055, isFront: true, isBack: false),
            LegChain(hip: CGPoint(x: 0.12, y: 0.32), knee: CGPoint(x: 0.36, y: 0.16),
                     foot: CGPoint(x: 0.54, y: 0.0), width: 0.052, isFront: true, isBack: false),
            LegChain(hip: CGPoint(x: -0.26, y: 0.34), knee: CGPoint(x: -0.32, y: 0.18),
                     foot: CGPoint(x: -0.34, y: 0.0), width: 0.075, isFront: false, isBack: true),
            LegChain(hip: CGPoint(x: -0.18, y: 0.34), knee: CGPoint(x: -0.24, y: 0.18),
                     foot: CGPoint(x: -0.26, y: 0.0), width: 0.072, isFront: false, isBack: true)
        ]
        s.earPerk = 0.55
        s.eyeOpen = 0.35
        return s
    }

    /// Standing upright on the hind legs, front paws raised — used for "playing".
    static func playful(phase: CGFloat, t: CGFloat) -> CatSkeleton {
        var s = CatSkeleton.empty
        let hop = abs(sin(t * 5.0)) * 0.03
        s.bodyCenter = CGPoint(x: 0.02, y: 0.50 + hop)
        s.bodyRX = 0.24; s.bodyRY = 0.20; s.bodyRot = -0.05
        s.headCenter = CGPoint(x: 0.24, y: 0.82 + hop)
        s.headR = 0.155
        s.tailBase = CGPoint(x: -0.20, y: 0.48)
        s.tailDir = .pi * 0.45
        s.tailCurl = 0.8
        s.tailLen = 0.42
        s.legs = [
            LegChain(hip: CGPoint(x: 0.14, y: 0.54), knee: CGPoint(x: 0.26, y: 0.66),
                     foot: CGPoint(x: 0.30, y: 0.78), width: 0.052, isFront: true, isBack: false),
            LegChain(hip: CGPoint(x: 0.06, y: 0.54), knee: CGPoint(x: 0.16, y: 0.68),
                     foot: CGPoint(x: 0.18, y: 0.80), width: 0.050, isFront: true, isBack: false),
            LegChain(hip: CGPoint(x: -0.10, y: 0.36), knee: CGPoint(x: -0.11, y: 0.18),
                     foot: CGPoint(x: -0.12, y: 0.0), width: 0.080, isFront: false, isBack: true),
            LegChain(hip: CGPoint(x: -0.02, y: 0.36), knee: CGPoint(x: -0.03, y: 0.18),
                     foot: CGPoint(x: -0.04, y: 0.0), width: 0.078, isFront: false, isBack: true)
        ]
        s.earPerk = 1.0
        s.eyeOpen = 1
        s.pupil = 0.75
        s.bodyLift = hop
        return s
    }

    /// Four legs with a walk-cycle phase applied.
    static func fourLegs(phase: CGFloat, spread: CGFloat, bend: CGFloat) -> [LegChain] {
        func leg(hipX: CGFloat, hipY: CGFloat, offset: CGFloat, width: CGFloat,
                 front: Bool, back: Bool) -> LegChain {
            let p = phase + offset
            let swing = sin(p) * 0.055 * spread
            let lift = max(0, sin(p)) * 0.030 * spread
            let kneeX = hipX + swing * 0.5
            let kneeY = hipY * 0.5 + bend * 0.06
            let footX = hipX + swing
            let footY = lift
            return LegChain(hip: CGPoint(x: hipX, y: hipY), knee: CGPoint(x: kneeX, y: kneeY),
                            foot: CGPoint(x: footX, y: footY), width: width,
                            isFront: front, isBack: back)
        }
        return [
            leg(hipX: 0.20, hipY: 0.36, offset: 0, width: 0.055, front: true, back: false),
            leg(hipX: 0.13, hipY: 0.36, offset: .pi, width: 0.052, front: true, back: false),
            leg(hipX: -0.20, hipY: 0.36, offset: .pi, width: 0.075, front: false, back: true),
            leg(hipX: -0.13, hipY: 0.36, offset: 0, width: 0.072, front: false, back: true)
        ]
    }
}
