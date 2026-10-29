import AppKit
import SwiftUI

// MARK: - App entry

@main
struct PCCatApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    init() {
        // Self-test: `PCCat --check-art` decodes every bundled animation and
        // reports frame counts / loop durations, then exits.
        if CommandLine.arguments.contains("--check-art") {
            checkArt()
            exit(0)
        }
    }

    private func checkArt() {
        // Bundled resources first, then the repo-local folder walk.
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
        let names = ["hero-cat.webp", "morning-cat.webp", "play-cat.webp",
                     "break-cat.webp", "sleep-cat.webp", "flowers.gif"]
        print("Searching \(dirs.count) directories")
        for name in names {
            var found: URL?
            for d in dirs where FileManager.default.fileExists(atPath: d.appendingPathComponent(name).path) {
                found = d.appendingPathComponent(name)
                break
            }
            guard let url = found else { print("  \(name): MISSING"); continue }
            let anim = decodeWebpFrames(url, maxDim: 480)
            if let anim {
                let mem = Double(anim.frames.count) * 480.0 * 480.0 * 4.0
                print("  \(name): \(anim.frames.count) frames, \(String(format: "%.1f", anim.total))s loop, ~\(Int(mem / 1024 / 1024)) MB decoded")
            } else {
                print("  \(name): decode FAILED")
            }
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
        buildStatusItem()
        checkReminders()
        NotificationCenter.default.addObserver(
            self, selector: #selector(petClicked),
            name: .pcCatPetClicked, object: nil)
        // The cat walks itself onto the desk.
        showPanel()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    // MARK: Panel

    /// Show the cat with a walk-in from the nearest screen edge.
    func showPanel() {
        if let panel { panel.walkIn(); return }
        let p = PetPanel(contentRect: NSRect(x: 0, y: 0, width: 400, height: 460))
        panel = p
        p.walkIn()
    }

    /// The cat is clicked → it walks away and hides.
    @objc func petClicked() {
        panel?.walkOut()
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
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit PCCat", action: #selector(quit), keyEquivalent: "q")
        for m in menu.items { m.target = self }
        item.menu = menu
    }

    @objc func showCat() { showPanel() }
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
