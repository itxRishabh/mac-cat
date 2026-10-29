import Foundation
import SwiftUI
import AppKit

// MARK: - Pet species & palette

enum PetSpecies: String, Codable, CaseIterable, Identifiable {
    case tuxedo, ginger, tabby, siamese, calico, midnight, cream, snow

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .tuxedo: return "Tuxedo"
        case .ginger: return "Ginger"
        case .tabby: return "Silver Tabby"
        case .siamese: return "Siamese"
        case .calico: return "Calico"
        case .midnight: return "Midnight"
        case .cream: return "Caramel Cream"
        case .snow: return "Snowball"
        }
    }

    var blurb: String {
        switch self {
        case .tuxedo: return "Formalwear, permanently. A gentleman."
        case .ginger: return "Loud, warm, and convinced the chair belongs to them."
        case .tabby: return "Classic stripes. Thinks they're a tiger."
        case .siamese: return "Elegant, opinionated, and extremely vocal."
        case .calico: return "Limited edition. Every single one of them."
        case .midnight: return "Stands out only in low light."
        case .cream: return "Soft, warm, and mildly caffeinated."
        case .snow: return "White, round, and hard to locate on a white desk."
        }
    }

    var palette: PetPalette {
        switch self {
        case .tuxedo:
            return PetPalette(base: Color(hex: 0xF7F5F2), shade: Color(hex: 0x24242C),
                              belly: Color(hex: 0xFFFFFF), innerEar: Color(hex: 0xF2A7B4),
                              nose: Color(hex: 0x3A2A33), eye: Color(hex: 0x2E6F4E),
                              patch: Color(hex: 0x24242C), patchAmount: 0.0)
        case .ginger:
            return PetPalette(base: Color(hex: 0xF0A45C), shade: Color(hex: 0xC97530),
                              belly: Color(hex: 0xFBEBD6), innerEar: Color(hex: 0xF4A8B0),
                              nose: Color(hex: 0xE08A8A), eye: Color(hex: 0x8FB93F),
                              patch: Color(hex: 0xC97530), patchAmount: 0.0)
        case .tabby:
            return PetPalette(base: Color(hex: 0xA9A6B5), shade: Color(hex: 0x6E6B7E),
                              belly: Color(hex: 0xE7E5EE), innerEar: Color(hex: 0xE0A8AE),
                              nose: Color(hex: 0xD08F95), eye: Color(hex: 0xC9A227),
                              patch: Color(hex: 0x6E6B7E), patchAmount: 0.0)
        case .siamese:
            return PetPalette(base: Color(hex: 0xEFE3D2), shade: Color(hex: 0x6B4E3D),
                              belly: Color(hex: 0xF8F1E6), innerEar: Color(hex: 0xD89A9E),
                              nose: Color(hex: 0xC98D8D), eye: Color(hex: 0x4FA3D1),
                              patch: Color(hex: 0x6B4E3D), patchAmount: 0.0)
        case .calico:
            return PetPalette(base: Color(hex: 0xFAF7F2), shade: Color(hex: 0xE0913F),
                              belly: Color(hex: 0xFFFFFF), innerEar: Color(hex: 0xF2A7B4),
                              nose: Color(hex: 0xD98F95), eye: Color(hex: 0x8A6A3B),
                              patch: Color(hex: 0x2E2E38), patchAmount: 0.55)
        case .midnight:
            return PetPalette(base: Color(hex: 0x3B3B48), shade: Color(hex: 0x1E1E28),
                              belly: Color(hex: 0x4E4E5C), innerEar: Color(hex: 0x7A4A57),
                              nose: Color(hex: 0x2A2028), eye: Color(hex: 0xD8B44A),
                              patch: Color(hex: 0x1E1E28), patchAmount: 0.0)
        case .cream:
            return PetPalette(base: Color(hex: 0xF3E1C3), shade: Color(hex: 0xD9BC93),
                              belly: Color(hex: 0xFCF4E4), innerEar: Color(hex: 0xF0B0AE),
                              nose: Color(hex: 0xD89A96), eye: Color(hex: 0x6E9B3D),
                              patch: Color(hex: 0xD9BC93), patchAmount: 0.0)
        case .snow:
            return PetPalette(base: Color(hex: 0xFAFBFD), shade: Color(hex: 0xE4E7EF),
                              belly: Color(hex: 0xFFFFFF), innerEar: Color(hex: 0xF5B6BE),
                              nose: Color(hex: 0xF0A7AE), eye: Color(hex: 0x76A8DE),
                              patch: Color(hex: 0xE4E7EF), patchAmount: 0.0)
        }
    }
}

struct PetPalette: Codable {
    var base: Color
    var shade: Color
    var belly: Color
    var innerEar: Color
    var nose: Color
    var eye: Color
    var patch: Color
    var patchAmount: Double

    // Codable support for Color via hex
    enum CodingKeys: String, CodingKey {
        case base, shade, belly, innerEar, nose, eye, patch, patchAmount
    }

    init(base: Color, shade: Color, belly: Color, innerEar: Color, nose: Color,
         eye: Color, patch: Color, patchAmount: Double) {
        self.base = base; self.shade = shade; self.belly = belly
        self.innerEar = innerEar; self.nose = nose; self.eye = eye
        self.patch = patch; self.patchAmount = patchAmount
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func col(_ k: CodingKeys) throws -> Color {
            let h = try c.decode(UInt32.self, forKey: k)
            return Color(hex: h)
        }
        base = try col(.base); shade = try col(.shade); belly = try col(.belly)
        innerEar = try col(.innerEar); nose = try col(.nose); eye = try col(.eye)
        patch = try col(.patch); patchAmount = try c.decode(Double.self, forKey: .patchAmount)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        func hex(_ color: Color) -> UInt32 { color.hexValue ?? 0x000000 }
        try c.encode(hex(base), forKey: .base)
        try c.encode(hex(shade), forKey: .shade)
        try c.encode(hex(belly), forKey: .belly)
        try c.encode(hex(innerEar), forKey: .innerEar)
        try c.encode(hex(nose), forKey: .nose)
        try c.encode(hex(eye), forKey: .eye)
        try c.encode(hex(patch), forKey: .patch)
        try c.encode(patchAmount, forKey: .patchAmount)
    }
}

// MARK: - Accessories

enum Accessory: String, Codable, CaseIterable, Identifiable {
    case none, scarf, collar, beanie, glasses, bowtie, crown

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "No accessory"
        case .scarf: return "Knit scarf"
        case .collar: return "Collar & bell"
        case .beanie: return "Beanie"
        case .glasses: return "Round glasses"
        case .bowtie: return "Bow tie"
        case .crown: return "Tiny crown"
        }
    }
}

// MARK: - Activities

enum Activity: String, Codable, CaseIterable {
    case idle, walking, sitting, sleeping, stretching, playing, eating, drinking, curious, grooming

    var label: String {
        switch self {
        case .idle: return "loafing"
        case .walking: return "patrolling"
        case .sitting: return "sitting"
        case .sleeping: return "napping"
        case .stretching: return "stretching"
        case .playing: return "playing"
        case .eating: return "eating"
        case .drinking: return "drinking"
        case .curious: return "watching you"
        case .grooming: return "grooming"
        }
    }
}

// MARK: - Chat

struct ChatMessage: Codable, Identifiable {
    var id: UUID = UUID()
    var role: String        // "user" | "assistant"
    var text: String
    var date: Date = Date()
}

// MARK: - Memory

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
    var recurringMinutes: Int? = nil
}

// MARK: - Settings

struct AppSettings: Codable {
    var apiKey: String = ""
    var model: String = "claude-sonnet-5-5"
    var petName: String = "Mochi"
    var dailyRoutineEnabled: Bool = true
    var showReminders: Bool = true
    var launchAtLogin: Bool = false
    var scale: Double = 1.0
    var soundEnabled: Bool = true
    var giphyEnabled: Bool = true
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

    /// Mix toward white.
    func lighter(_ amount: Double) -> Color {
        let c = NSColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        return Color(.sRGB, red: r + (1 - r) * amount, green: g + (1 - g) * amount,
                     blue: b + (1 - b) * amount, opacity: a)
    }

    /// Mix toward black.
    func darker(_ amount: Double) -> Color {
        let c = NSColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        return Color(.sRGB, red: r * (1 - amount), green: g * (1 - amount),
                     blue: b * (1 - amount), opacity: a)
    }
}
