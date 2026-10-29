import SwiftUI
import AppKit
import Foundation

/// Floating chat card that lives above the pet on the desktop.
struct ChatPanel: View {

    @ObservedObject var store: Store

    /// Optional host-provided collapse handler. When nil the panel posts the
    /// "pcCat.petClicked" notification, which the overlay uses to toggle the
    /// chat closed.
    var onClose: (() -> Void)? = nil

    @State private var draft: String = ""
    @FocusState private var composerFocused: Bool

    /// Card metrics — 12pt spacing scale, 14px corner radius.
    private let cornerRadius: CGFloat = 14
    private let spacing: CGFloat = 12
    private let accent = Color(hex: 0x7B61FF)

    private var panelWidth: CGFloat { 380 }
    private var panelHeight: CGFloat { 520 }

    // MARK: - Root

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.5)
            messages
            Divider().opacity(0.5)
            composer
        }
        .frame(width: panelWidth, height: panelHeight)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            avatar

            VStack(alignment: .leading, spacing: 2) {
                Text(store.settings.petName)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                HStack(spacing: 5) {
                    statusDot
                    Text(store.isThinking ? "thinking…" : "online")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 4)

            Button {
                collapsePanel()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(6)
                    .background(Circle().fill(Color.primary.opacity(0.07)))
            }
            .buttonStyle(.plain)
            .help("Collapse chat")
        }
        .padding(.horizontal, spacing)
        .padding(.vertical, 10)
    }

    private var avatar: some View {
        let palette = store.species.palette
        return ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [palette.base, palette.shade.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Circle()
                .strokeBorder(palette.shade.opacity(0.5), lineWidth: 1)
            Text("🐈‍⬛")
                .font(.system(size: 16))
                .foregroundStyle(palette.shade)
        }
        .frame(width: 32, height: 32)
        .overlay(alignment: .bottomTrailing) {
            Circle()
                .fill(store.isThinking ? Color.orange : Color.green)
                .frame(width: 8, height: 8)
                .overlay(Circle().strokeBorder(.white.opacity(0.9), lineWidth: 1.5))
                .offset(x: 2, y: 2)
        }
    }

    @ViewBuilder
    private var statusDot: some View {
        if store.isThinking {
            PulsingDot(color: Color.orange)
        } else {
            Circle()
                .fill(Color.green)
                .frame(width: 6, height: 6)
        }
    }

    // MARK: - Messages

    /// Changes when the chat grows *or* when the last reply streams new text.
    private var chatActivity: String {
        guard let last = store.chat.last else { return "empty" }
        return "\(store.chat.count)-\(last.id)-\(last.text.count)"
    }

    @ViewBuilder
    private var messages: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: spacing) {
                    if store.chat.isEmpty {
                        emptyState
                    } else {
                        ForEach(store.chat) { message in
                            bubble(for: message)
                                .id(message.id)
                        }
                        if store.isThinking {
                            thinkingRow
                        }
                    }
                }
                .padding(spacing)
            }
            .onChange(of: chatActivity) { _, _ in
                if let last = store.chat.last {
                    withAnimation(.easeOut(duration: 0.25)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .onAppear {
                if let last = store.chat.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    private func bubble(for message: ChatMessage) -> some View {
        let isUser = message.role == "user"
        // The pet's current mood tints only its most recent reply.
        let tone = isLatestAssistant(message) ? toneColor : nil
        return HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 40) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 3) {
                Text(message.text)
                    .font(.callout)
                    .foregroundStyle(isUser ? Color.white : Color.primary)
                    .multilineTextAlignment(isUser ? .trailing : .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(isUser ? accent : Color.primary.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                    .fill(tone?.opacity(0.22) ?? .clear)
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(isUser ? .clear : (tone?.opacity(0.55) ?? Color.primary.opacity(0.06)),
                                          lineWidth: 1)
                    )

                Text(message.date.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 4)
            }

            if !isUser { Spacer(minLength: 40) }
        }
    }

    private func isLatestAssistant(_ message: ChatMessage) -> Bool {
        guard message.role != "user" else { return false }
        return store.chat.last(where: { $0.role != "user" })?.id == message.id
    }

    /// Maps the pet's current bubble mood onto a subtle chat tint.
    private var toneColor: Color? {
        switch store.bubbleKind {
        case .happy: return Color(hex: 0xFFC46B)
        case .sad: return Color(hex: 0x9BB4D3)
        case .alert: return Color(hex: 0xF3A0A0)
        case .thought: return Color(hex: 0xC9C4F5)
        case .plain: return nil
        }
    }

    private var thinkingRow: some View {
        HStack(spacing: 6) {
            ThinkingDots(color: Color.secondary)
            Text("\(store.settings.petName) is thinking…")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: spacing) {
            Text("Hi, I'm \(store.settings.petName).")
                .font(.system(size: 16, weight: .semibold, design: .rounded))

            Text("I can answer your questions, set reminders on your Mac, and remember little things about you for next time.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                Text("TRY ASKING")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.tertiary)
                    .tracking(1.0)

                suggestionChip("What should I work on today?")
                suggestionChip("Remind me to stretch in 25 minutes")
                suggestionChip("Remember that I prefer tea over coffee")
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 6)
    }

    private func suggestionChip(_ text: String) -> some View {
        Button {
            store.send(text: text)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.caption2)
                    .foregroundStyle(accent)
                Text(text)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Composer

    private var composer: some View {
        HStack(spacing: 8) {
            TextField("Say something…", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.callout)
                .lineLimit(1...4)
                .focused($composerFocused)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.primary.opacity(0.07))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
                )
                .onSubmit(send)

            Button(action: send) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(canSend ? accent : Color.secondary.opacity(0.4)))
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .help("Send")
        }
        .padding(.horizontal, spacing)
        .padding(.vertical, 10)
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Actions

    private func send() {
        guard canSend else { return }
        store.send(text: draft)
        draft = ""
    }

    private func collapsePanel() {
        // The host owns the collapse animation.
        if let onClose {
            onClose()
        } else {
            // Raw name so this file does not depend on the overlay's declarations.
            NotificationCenter.default.post(name: Notification.Name("pcCat.petClicked"), object: nil)
        }
    }
}

// MARK: - Animations

/// A small dot that pulses while the pet is thinking.
private struct PulsingDot: View {

    let color: Color
    @State private var on: Bool = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 6, height: 6)
            .opacity(on ? 0.35 : 1.0)
            .scaleEffect(on ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: on)
            .onAppear { on = true }
    }
}

/// Three staggered dots shown while a reply streams in.
private struct ThinkingDots: View {

    let color: Color
    @State private var phase: Int = 0
    @State private var task: Task<Void, Never>?

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(color)
                    .frame(width: 5, height: 5)
                    .opacity(phase == index ? 1.0 : 0.28)
                    .animation(.easeInOut(duration: 0.28), value: phase)
            }
        }
        .onAppear {
            task = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 350_000_000)
                    guard !Task.isCancelled else { return }
                    phase = (phase + 1) % 3
                }
            }
        }
        .onDisappear {
            task?.cancel()
            task = nil
        }
    }
}
