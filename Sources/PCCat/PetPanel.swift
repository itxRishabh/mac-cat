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

        let hosting = NSHostingView(rootView: PetOverlayView(store: AppDelegateBridge.shared.store,
                                                            onClose: { [weak self] in self?.orderOut(nil) }))
        hosting.frame = contentRect
        hosting.autoresizingMask = [.width, .height]
        hosting.wantsLayer = true
        hosting.layer?.isOpaque = false
        contentView = hosting

        if let saved = UserDefaults.standard.string(forKey: "PCCatPanelFrame") {
            let parts = saved.split(separator: ",").compactMap { Double($0) }
            if parts.count == 4 {
                setFrame(NSRect(x: parts[0], y: parts[1], width: parts[2], height: parts[3]), display: true)
                return
            }
        }
        positionBottomRight()
    }

    private func positionBottomRight() {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = frame.size
        let origin = NSPoint(x: visible.maxX - size.width - 40,
                             y: visible.minY + 40)
        setFrameOrigin(origin)
    }

    // MARK: Dragging

    override func mouseDown(with event: NSEvent) {
        guard let view = contentView else { return }
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
            // Treated as a click on the pet.
            NotificationCenter.default.post(name: .pcCatPetClicked, object: nil)
        }
        isDragging = false
        saveFrame()
    }

    private func saveFrame() {
        let f = frame
        UserDefaults.standard.set("\(f.origin.x),\(f.origin.y),\(f.size.width),\(f.size.height)",
                                  forKey: "PCCatPanelFrame")
    }
}

extension Notification.Name {
    static let pcCatPetClicked = Notification.Name("pcCat.petClicked")
}
