import SwiftUI
import AppKit

/// The transparent overlay that lives on the desktop: the animated Furever Dock
/// cat, its speech bubble, and quick actions.
struct PetOverlayView: View {

    @ObservedObject var store: Store
    @ObservedObject private var brain: PetBrain
    @ObservedObject private var art = CatArt.shared

    @State private var showActions = false
    @State private var hovering = false

    init(store: Store) {
        self.store = store
        self.brain = store.brain
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                if let text = store.bubbleText {
                    SpeechBubble(text: text, kind: store.bubbleKind)
                        .transition(.scale(scale: 0.6, anchor: .bottom).combined(with: .opacity))
                        .padding(.bottom, 10)
                        .zIndex(5)
                }

                ZStack {
                    if art.hasImages {
                        // Little flowers loop, Furever Dock-style, next to the cat.
                        FlowersView(art: art, size: 92)
                            .offset(x: -128, y: 44)

                        CatAnimationView(art: art, size: 300)
                            .onTapGesture { store.pet() }
                            .onHover { hovering = $0 }
                    } else {
                        missingArt
                    }

                    if hovering || showActions {
                        QuickActions(store: store, showActions: $showActions)
                            .offset(y: -8)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .zIndex(8)
                    }
                }
                .frame(height: 320)
            }
        }
        .frame(width: 400, height: 460)
        .onAppear {
            art.startClock()
            art.playFlowers()
            art.play(CatArt.kind(for: brain.activity))
        }
        .onReceive(NotificationCenter.default.publisher(for: .pcCatPetClicked)) { _ in
            store.pet()
        }
        .onReceive(brain.$activity.dropFirst().removeDuplicates()) { activity in
            art.play(CatArt.kind(for: activity))
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.80), value: store.bubbleText)
        .animation(.spring(response: 0.30, dampingFraction: 0.82), value: showActions)
    }

    private var missingArt: some View {
        VStack(spacing: 10) {
            Image(systemName: "pawprint")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("No cat art found")
                .font(.callout.weight(.medium))
            Text("Drop the .webp files into  local/illustrations  \nor use Settings → Art style.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(width: 240, height: 240)
    }
}

// MARK: - Speech bubble

struct SpeechBubble: View {
    let text: String
    let kind: Store.BubbleKind

    private var accent: Color {
        switch kind {
        case .happy: return Color(hex: 0xFFC46B)
        case .sad: return Color(hex: 0x9BB4D3)
        case .alert: return Color(hex: 0xF3A0A0)
        case .thought: return Color(hex: 0xC9C4F5)
        case .plain: return Color(hex: 0xF2F0EC)
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            if kind == .thought {
                Text("💭")
                    .font(.system(size: 12))
            }
            Text(text)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(accent.opacity(0.35))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.45), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.14), radius: 12, y: 4)
        .frame(maxWidth: 260, alignment: .leading)
    }
}

// MARK: - Quick actions

struct QuickActions: View {
    @ObservedObject var store: Store
    @Binding var showActions: Bool

    var body: some View {
        HStack(spacing: 8) {
            pill("🍽️", "Feed") { store.giveFood() }
            pill("💧", "Water") { store.giveWater() }
            pill("🧘", "Meditate") { store.meditate() }
            pill("🎾", "Play") { store.playTrick() }
            pill("🌙", "Nap") { store.nap() }
            pill("🤍", "Pet") { store.pet() }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.35), lineWidth: 1))
        )
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
    }

    private func pill(_ emoji: String, _ label: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(emoji).font(.system(size: 12))
                Text(label)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.primary.opacity(0.08)))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
