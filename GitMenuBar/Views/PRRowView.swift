import SwiftUI

struct PRRowView: View {
    let pr: PullRequest
    var isRead: Bool = false
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 10) {
                // Status indicator
                statusIndicator
                    .padding(.top, 3)

                // Content
                VStack(alignment: .leading, spacing: 3) {
                    // Repo + author + time
                    HStack {
                        Text(pr.repositoryName.components(separatedBy: "/").last ?? pr.repositoryName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        // Author avatar and login
                        AsyncImage(url: pr.authorAvatarURL) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .foregroundStyle(.quaternary)
                        }
                        .frame(width: 14, height: 14)
                        .clipShape(Circle())

                        Text(pr.authorLogin)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        Spacer()

                        Text(pr.timeAgo)
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }

                    // Title
                    Text(pr.title)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    // Bottom row: labels + PR number
                    HStack(spacing: 6) {
                        if pr.isDraft {
                            StatusBadge(text: "Draft", color: .secondary)
                        }

                        reviewBadge

                        ciBadge

                        if pr.isMergeable == false {
                            StatusBadge(text: "Conflict", icon: "exclamationmark.triangle", color: .red)
                        }

                        if !pr.labels.isEmpty {
                            ForEach(pr.labels.prefix(2)) { label in
                                LabelPill(label: label)
                            }
                        }

                        Spacer()

                        Text("#\(pr.number)")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.quaternary)
                    }
                    .padding(.top, 1)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? Color.primary.opacity(0.04) : Color.clear)
            )
            .contentShape(Rectangle())
            .opacity(isRead ? 0.5 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            Button("Copy Link") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(pr.url.absoluteString, forType: .string)
            }
            Button("Open in Browser") {
                onTap()
            }
        }
    }

    // MARK: - Status Indicator

    private var statusIndicator: some View {
        ZStack {
            Circle()
                .fill(statusColor.opacity(0.15))
                .frame(width: 18, height: 18)
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)
        }
    }

    private var statusColor: Color {
        switch pr.statusColor {
        case .approved: return .green
        case .pending: return .orange
        case .changesRequested: return .red
        case .failing: return .red
        case .draft: return .gray
        case .conflict: return .purple
        }
    }

    // MARK: - Badges

    @ViewBuilder
    private var reviewBadge: some View {
        switch pr.reviewDecision {
        case .approved:
            if let countText = pr.reviewCountText {
                StatusBadge(text: "\(countText) Approved", color: .green)
            } else {
                StatusBadge(text: "Approved", color: .green)
            }
        case .changesRequested:
            if let countText = pr.reviewCountText {
                StatusBadge(text: "\(countText) Changes", color: .red)
            } else {
                StatusBadge(text: "Changes", color: .red)
            }
        case .reviewRequired:
            if let countText = pr.reviewCountText {
                StatusBadge(text: "\(countText) Review", color: .orange)
            } else {
                StatusBadge(text: "Review", color: .orange)
            }
        case .none:
            EmptyView()
        }
    }

    @ViewBuilder
    private var ciBadge: some View {
        switch pr.ciStatus {
        case .success:
            StatusBadge(icon: "checkmark", color: .green)
        case .failure, .error:
            StatusBadge(icon: "xmark", color: .red)
        case .pending, .expected:
            StatusBadge(icon: "clock", color: .orange)
        case .none:
            EmptyView()
        }
    }
}

// MARK: - Supporting Views

struct StatusBadge: View {
    var text: String?
    var icon: String?
    let color: Color

    var body: some View {
        HStack(spacing: 2) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 7, weight: .bold))
            }
            if let text {
                Text(text)
                    .font(.system(size: 9, weight: .medium))
            }
        }
        .foregroundStyle(color)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(color.opacity(0.1))
        )
    }
}

struct LabelPill: View {
    let label: Label

    var body: some View {
        Text(label.name)
            .font(.system(size: 9, weight: .medium))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(labelColor.opacity(0.1))
            )
            .foregroundStyle(labelColor.opacity(0.8))
    }

    private var labelColor: Color {
        Color(hex: label.color) ?? .secondary
    }
}

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard hex.count == 6,
              let intVal = UInt64(hex, radix: 16) else {
            return nil
        }
        let r = Double((intVal >> 16) & 0xFF) / 255.0
        let g = Double((intVal >> 8) & 0xFF) / 255.0
        let b = Double(intVal & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
