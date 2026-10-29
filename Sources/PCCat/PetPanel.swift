import AppKit
import SwiftUI

/// A transparent, non-activating, always-on-top floating panel that hosts the pet.
final class PetPanel: NSPanel {

    private var dragOrigin: NSPoint = .zero
    private var mouseDownOrigin: NSPoint = .zero
    private var isDragging = false

    init(contentRect: NSRect) {
        super.init(contentRect: contentRect,
                   styleMask: [.borderless, .nonactivatingPanel, .resizable],
                   backing: .buffered,
                   defer: false)

        isFloatingPanel = true
        level = .floating
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isMovableByWindowBackground = false
        animationBehavior = .utilityWindow
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        acceptsMouseMovedEvents = true

        let hosting = NSHostingView(rootView: PetOverlayView(store: AppDelegateBridge.shared.store))
        hosting.frame = contentRect
        hosting.autoresizingMask = [.width, .height]
        hosting.wantsLayer = true
        hosting.layer?.isOpaque = false
        contentView = hosting

        // Positioning is owned by the app delegate (walk-in animation).
    }

    // MARK: Dragging

    override func mouseDown(with event: NSEvent) {
        guard contentView != nil else { return }
        dragOrigin = frame.origin
        mouseDownOrigin = NSEvent.mouseLocation
        isDragging = false
        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        let now = NSEvent.mouseLocation
        let dx = now.x - mouseDownOrigin.x
        let dy = now.y - mouseDownOrigin.y
        if !isDragging && (abs(dx) > 3 || abs(dy) > 3) { isDragging = true }
        guard isDragging else { return }
        setFrameOrigin(NSPoint(x: dragOrigin.x + dx, y: dragOrigin.y + dy))
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        if !isDragging {
            // Treated as a click on the pet → it walks away.
            NotificationCenter.default.post(name: .pcCatPetClicked, object: nil)
        }
        isDragging = false
    }

    // MARK: - Walking

    /// Walk in from the left or right screen edge to the resting spot
    /// (bottom-centre of the main screen). The panel appears off-screen first
    /// and eases into place, so the cat never "pops".
    @discardableResult
    func walkIn() -> Bool {
        guard let screen = NSScreen.main else { orderFrontRegardless(); return false }
        let visible = screen.visibleFrame
        let targetX = visible.midX - frame.width / 2
        let targetY = visible.minY + 40

        let fromLeft = Bool.random()
        let startX = fromLeft ? visible.minX - frame.width : visible.maxX
        setFrameOrigin(NSPoint(x: startX, y: targetY))
        orderFrontRegardless()
        CatArt.shared.setFlip(fromLeft)   // face the direction of travel
        animateFrameOrigin(to: NSPoint(x: targetX, y: targetY), duration: kWalkDuration)
        return true
    }

    /// Walk off-screen to the nearer edge, then hide the panel.
    @discardableResult
    func walkOut() -> Bool {
        guard let screen = NSScreen.main else { orderOut(nil); return false }
        let visible = screen.visibleFrame
        let exitLeft = frame.midX < visible.midX
        CatArt.shared.setFlip(exitLeft)
        let target: NSPoint = exitLeft
            ? NSPoint(x: visible.minX - frame.width, y: frame.origin.y)
            : NSPoint(x: visible.maxX, y: frame.origin.y)
        animateFrameOrigin(to: target, duration: kWalkDuration) { [weak self] in
            self?.orderOut(nil)
        }
        return true
    }

    private var walkTimer: Timer?
    private var walkFrom: NSPoint = .zero
    private var walkTo: NSPoint = .zero
    private var walkStart: Date = .distantPast
    private var walkDuration: Double = 1

    /// Ease-in/out interpolation for the walk.
    private func easeInOut(_ t: Double) -> Double {
        t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
    }

    private func animateFrameOrigin(to origin: NSPoint, duration: Double,
                                    completion: (() -> Void)? = nil) {
        walkTimer?.invalidate()
        walkFrom = frame.origin
        walkTo = origin
        walkStart = Date()
        walkDuration = duration
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            let t = min(1.0, Date().timeIntervalSince(self.walkStart) / self.walkDuration)
            let e = self.easeInOut(t)
            let x = self.walkFrom.x + (self.walkTo.x - self.walkFrom.x) * e
            let y = self.walkFrom.y + (self.walkTo.y - self.walkFrom.y) * e
            self.setFrameOrigin(NSPoint(x: x, y: y))
            if t >= 1.0 {
                timer.invalidate()
                self.walkTimer = nil
                completion?()
            }
        }
        timer.tolerance = 0.016
        RunLoop.main.add(timer, forMode: .common)
        walkTimer = timer
    }
}

extension Notification.Name {
    static let pcCatPetClicked = Notification.Name("pcCat.petClicked")
}
