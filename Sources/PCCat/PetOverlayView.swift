import SwiftUI
import AppKit

/// The transparent overlay that lives on the desktop: cat, speech bubble,
/// quick actions and the chat panel.
struct PetOverlayView: View {

    @ObservedObject var store: Store
    @ObservedObject private var brain: PetBrain
    var onClose: () -> Void

    @State private var chatOpen = false
    @State private var showActions = false
    @State private var hovering = false
    @State private var dragOffset: CGSize = .zero
    @State private var bounce: CGFloat = 0

    init(store: Store, onClose: @escaping () -> Void) {
        self.store = store
        self.onClose = onClose
        self.brain = store.brain
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Chat panel floats above the pet when opened.
            if chatOpen {
                ChatPanel(store: store)
                    .frame(width: 380, height: 520)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }

            VStack(spacing: 0) {
                if let text = store.bubbleText {
                    SpeechBubble(text: text, kind: store.bubbleKind)
                        .transition(.scale(scale: 0.6, anchor: .bottom).combined(with: .opacity))
                        .padding(.bottom, 10)
                        .zIndex(5)
                }

                ZStack {
                    CatCanvas(brain: brain, store: store)
                        .frame(width: 260, height: 260)
                        .scaleEffect(store.settings.scale)
                        .offset(y: bounce)
                        .shadow(color: .black.opacity(0.10), radius: 12, y: 8)
                        .onTapGesture { store.pet() }
                        .onHover { hovering = $0 }

                    if hovering || showActions {
                        QuickActions(store: store, showActions: $showActions)
                            .offset(y: -6)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .zIndex(8)
                    }
                }
                .frame(height: 260)
            }
            .offset(dragOffset)
        }
        .frame(width: 400, height: 700)
        .onReceive(NotificationCenter.default.publisher(for: .pcCatOpenChat)) { _ in
            withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) { chatOpen = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: .pcCatPetClicked)) { _ in
            withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) { chatOpen.toggle() }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.80), value: store.bubbleText)
        .animation(.spring(response: 0.30, dampingFraction: 0.82), value: chatOpen)
        .animation(.spring(response: 0.30, dampingFraction: 0.82), value: showActions)
    }
}

// MARK: - Canvas host

/// Bridges the 60fps skeleton into SwiftUI's Canvas.
struct CatCanvas: View {
    @ObservedObject var brain: PetBrain
    @ObservedObject var store: Store

    var body: some View {
        Canvas(rendersAsynchronously: false) { ctx, size in
            let renderer = CatRenderer(
                skeleton: brain.skeleton,
                palette: store.species.palette,
                blink: brain.blink,
                earTwitch: brain.earTwitch,
                tailWag: brain.tailWag,
                mouthOpen: brain.mouthOpen,
                headTilt: brain.headTilt,
                eyeLook: brain.eyeLook,
                accessory: store.accessory,
                isSpeaking: store.isThinking,
                facingRight: store.facingRight
            )
            renderer.draw(in: ctx, size: size)
        }
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
                .foregroundStyle(kind == .happy || kind == .alert || kind == .thought ? Color.primary : Color.primary)
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

    private let tricks = ["Sit", "High Five", "Spin"]

    var body: some View {
        HStack(spacing: 8) {
            Button {
                store.giveFood()
            } label: { pill("🍽️", "Feed") }

            Button {
                store.giveWater()
            } label: { pill("💧", "Water") }

            ForEach(tricks, id: \.self) { trick in
                Button {
                    store.playTrick(trick)
                } label: { pill("🎾", trick) }
            }

            Button {
                store.pet()
            } label: { pill("🤍", "Pet") }
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

    private func pill(_ emoji: String, _ label: String) -> some View {
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
}
