import Foundation
import SwiftUI

// MARK: - Activities

enum Activity: String, Codable, CaseIterable {
    case idle, sitting, sleeping, stretching, playing, eating, drinking, meditating

    var label: String {
        switch self {
        case .idle: return "loafing"
        case .sitting: return "sitting"
        case .sleeping: return "napping"
        case .stretching: return "stretching"
        case .playing: return "playing"
        case .eating: return "eating"
        case .drinking: return "drinking"
        case .meditating: return "meditating"
        }
    }
}

// MARK: - Memories

struct PetMemory: Codable, Identifiable {
    var id: UUID = UUID()
    var text: String
    var date: Date = Date()
}

// MARK: - Reminders

struct PetReminder: Codable, Identifiable {
    var id: UUID = UUID()
    var title: String
    var fireDate: Date
    var isFired: Bool = false
}

// MARK: - Settings

enum ArtStyle: String, Codable, CaseIterable, Identifiable {
    case illustrated, vector
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .illustrated: return "Illustrated (Furever Dock art)"
        case .vector: return "Vector cat"
        }
    }
}

struct AppSettings: Codable {
    var petName: String = "Mochi"
    var dailyRoutineEnabled: Bool = true
    var showReminders: Bool = true
    var soundEnabled: Bool = true
    var artStyle: ArtStyle = .illustrated
}

// MARK: - Color helpers

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }

    var hexValue: UInt32? {
        let c = NSColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        guard a > 0 else { return nil }
        return (UInt32(r * 255) << 16) | (UInt32(g * 255) << 8) | UInt32(b * 255)
    }

    func lighter(_ amount: Double) -> Color {
        let c = NSColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        return Color(.sRGB, red: r + (1 - r) * amount, green: g + (1 - g) * amount,
                     blue: b + (1 - b) * amount, opacity: a)
    }
}
