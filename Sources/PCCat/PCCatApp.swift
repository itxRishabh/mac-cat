import AppKit
import SwiftUI

// MARK: - App entry

@main
struct PCCatApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    init() {
        // Headless render harness: `PCCat --render-tests <dir>`
        let args = CommandLine.arguments
        if let idx = args.firstIndex(of: "--render-tests") {
            let dir = idx + 1 < args.count ? args[idx + 1] : "./renderout"
            MainActor.assumeIsolated {
                RenderTests.run(outputDir: dir)
            }
            exit(0)
        }
    }

    var body: some Scene {
        Settings {
            SettingsHostView()
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About PCCat") { AboutPanel.show() }
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: PetPanel?
    private var statusItem: NSStatusItem?
    var store: Store { AppDelegateBridge.shared.store }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        showPanel()
        buildStatusItem()
        checkReminders()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    // MARK: Panel

    func showPanel() {
        if let panel { panel.orderFrontRegardless(); return }
        let p = PetPanel(contentRect: NSRect(x: 0, y: 0, width: 400, height: 800))
        panel = p
        p.orderFrontRegardless()
    }

    @MainActor
    func buildStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "PCCat")
            button.image?.isTemplate = true
        }
        let menu = NSMenu()
        menu.addItem(withTitle: "Show \(store.settings.petName)", action: #selector(showCat), keyEquivalent: "")
        menu.addItem(withTitle: "Chat", action: #selector(openChat), keyEquivalent: "")
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit PCCat", action: #selector(quit), keyEquivalent: "q")
        for m in menu.items { m.target = self }
        item.menu = menu
    }

    @objc func showCat() { showPanel() }
    @objc func openChat() {
        showPanel()
        NotificationCenter.default.post(name: .pcCatOpenChat, object: nil)
    }
    @objc func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
    @objc func quit() { NSApp.terminate(nil) }

    private func checkReminders() {
        Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.store.checkReminders() }
        }
    }
}

extension Notification.Name {
    static let pcCatOpenChat = Notification.Name("pcCat.openChat")
}

/// Bridges the SwiftUI `Settings` scene to the shared store.
struct SettingsHostView: View {
    @StateObject private var store = AppDelegateBridge.shared.store
    var body: some View {
        SettingsView(store: store)
    }
}

/// Holds the one shared Store for both the panel and the settings window.
@MainActor
final class AppDelegateBridge {
    static let shared = AppDelegateBridge()
    let store = Store()
}

enum AboutPanel {
    static func show() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "PCCat"
        alert.informativeText = """
        A desktop companion that lives on your screen.

        Version 1.0
        """
        alert.runModal()
    }
}
