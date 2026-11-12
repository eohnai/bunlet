import EventBridge
import SwiftUI
import Usage

/// Usage row cells: logo, window, percentage and reset, separated by a faint bar.
/// Hover shows an immediate custom popup instead of a delayed native tooltip (decision 0018).
struct NotchAllowanceStrip: View {
    let store: UsageStore
    let activeProviders: Set<Agent>
    @State private var hovered: Agent?

    var body: some View {
        // The parent creates this view only while expanded. With no providers,
        // there is no allowance to age and no countdown to schedule.
        if !activeProviders.isEmpty {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                let nowMs = Int64(context.date.timeIntervalSince1970 * 1_000)
                let snapshots = store.snapshots(activeProviders: activeProviders, nowMs: nowMs)
                let entries = NotchAllowancePresentation.entries(activeProviders: activeProviders,
                                                                  snapshots: snapshots)
                HStack(spacing: 12) {
                    ForEach(entries, id: \.provider) { entry in
                        if entry.provider != entries.first?.provider {
                            Text("|")
                                .font(.system(size: 12))
                                .foregroundStyle(Color(red: 224 / 255, green: 226 / 255, blue: 242 / 255).opacity(0.25))
                                .accessibilityHidden(true)
                        }
                        cell(entry, nowMs: nowMs)
                    }
                }
            }
        }
    }

    private func cell(_ entry: NotchAllowanceEntry, nowMs: Int64) -> some View {
        let name = entry.provider == .codex ? "Codex" : "Claude Code"
        let countdown = NotchAllowancePresentation.countdownText(for: entry.window, at: nowMs)
        let spoken = entry.percentLeft.map { "\(entry.windowLabel), \($0) percent left, resets in \(countdown)" }
            ?? "\(entry.windowLabel), usage limits unavailable"
        return HStack(spacing: 6) {
            logo(entry.provider, name: name)
            HStack(spacing: 4) {
                if let percentLeft = entry.percentLeft {
                    Text(entry.windowLabel)
                    Text("\(percentLeft)%").foregroundStyle(color(entry.color))
                    Text(countdown)
                } else {
                    // Missing data must not look like zero remaining.
                    Text("\(entry.windowLabel) unavailable")
                }
            }
            .font(.system(size: 12, weight: .medium))
            .kerning(-0.2)
            .monospacedDigit()
            .foregroundStyle(.white.opacity(0.7))
            if entry.source?.isStale == true {
                Text("stale").font(.system(size: 12)).foregroundStyle(IslandPalette.mutedText)
            }
            if needsWarning(entry) {
                Circle().fill(Color(red: 1, green: 0x8C / 255, blue: 0)).frame(width: 6, height: 6)
            }
        }
        .lineLimit(1)
        .fixedSize()
        .contentShape(Rectangle())
        .onHover { inside in
            if inside { hovered = entry.provider } else if hovered == entry.provider { hovered = nil }
        }
        .overlay(alignment: .topLeading) {
            if hovered == entry.provider {
                popup(lines(entry, nowMs: nowMs))
                    .alignmentGuide(.top) { $0[.top] - 22 }
                    .allowsHitTesting(false)
            }
        }
        .zIndex(hovered == entry.provider ? 1 : 0)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name), \(spoken)\(entry.accountUnverified ? ", account unverified" : "")\(entry.source?.isStale == true ? ", stale" : "")")
    }

    @ViewBuilder private func logo(_ provider: Agent, name: String) -> some View {
        if let image = ProviderLogo.bundled[provider] {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 12, height: 12)
                .accessibilityHidden(true)
        } else {
            Text(name).font(.system(size: 12, weight: .medium)).foregroundStyle(.white)
        }
    }

    private func popup(_ lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(lines, id: \.self) { Text($0) }
        }
        .font(.system(size: 11))
        .lineSpacing(6)
        .foregroundStyle(.white.opacity(0.9))
        .fixedSize()
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Color(white: 40 / 255).opacity(0.96), in: RoundedRectangle(cornerRadius: 6))
    }

    private func lines(_ entry: NotchAllowanceEntry, nowMs: Int64) -> [String] {
        var lines = NotchAllowancePresentation.detailLines(for: entry, at: nowMs)
        if entry.provider == .claude {
            switch store.receiverState {
            case .listening: break
            case .unavailable: lines.append("Quota receiver unavailable. Pause and resume Agents to retry.")
            case .stopped: lines.append("Quota receiver stopped.")
            }
            if store.invalidIntake { lines.append("Invalid quota input was rejected.") }
        }
        if store.intakeLost { lines.append("Quota intake overflowed. A later reading is needed.") }
        if store.capacityReached { lines.append("Quota source capacity reached; new sources were refused.") }
        return lines
    }

    private func needsWarning(_ entry: NotchAllowanceEntry) -> Bool {
        (entry.provider == .claude && store.receiverState == .unavailable) || store.intakeLost || store.capacityReached
    }

    /// Level colors applied to percent left (D6): above 50 green, 20–50 yellow, below 20 red.
    private func color(_ color: AllowanceColor) -> Color {
        switch color {
        case .green: Color(red: 0, green: 0xF8 / 255, blue: 0x73 / 255)
        case .yellow: Color(red: 1, green: 0xC2 / 255, blue: 0x24 / 255)
        case .red: Color(red: 1, green: 0x30 / 255, blue: 0x4B / 255)
        case .gray: IslandPalette.mutedText
        }
    }
}
