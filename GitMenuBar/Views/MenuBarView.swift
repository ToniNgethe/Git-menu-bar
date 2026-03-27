import SwiftUI

struct MenuBarView: View {
    @ObservedObject var viewModel: PRListViewModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(spacing: 0) {
            if !viewModel.isAuthenticated {
                onboardingView
            } else {
                headerView
                filterBar
                rateLimitBanner
                contentView
                footerView
            }
        }
        .frame(width: 380)
        .background(.ultraThinMaterial)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Pull Requests")
                    .font(.system(size: 13, weight: .semibold))
                if let username = viewModel.username {
                    Text("@\(username)")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            HStack(spacing: 2) {
                // Toggle read state
                IconButton(icon: viewModel.allRead ? "eye.slash" : "eye") {
                    viewModel.toggleAllRead()
                }

                // Sort menu
                Menu {
                    Button {
                        viewModel.sortOrder = .updatedDate
                    } label: {
                        HStack {
                            Text("Updated Date")
                            if viewModel.sortOrder == .updatedDate { Image(systemName: "checkmark") }
                        }
                    }
                    Button {
                        viewModel.sortOrder = .createdDate
                    } label: {
                        HStack {
                            Text("Created Date")
                            if viewModel.sortOrder == .createdDate { Image(systemName: "checkmark") }
                        }
                    }
                    Button {
                        viewModel.sortOrder = .repositoryName
                    } label: {
                        HStack {
                            Text("Repository")
                            if viewModel.sortOrder == .repositoryName { Image(systemName: "checkmark") }
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 26, height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.clear)
                        )
                }
                .menuStyle(.borderlessButton)
                .frame(width: 26, height: 26)

                IconButton(icon: "arrow.clockwise", isSpinning: viewModel.isLoading) {
                    Task { await viewModel.refresh() }
                }
                .disabled(viewModel.isLoading)

                IconButton(icon: "gearshape") {
                    openSettings()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        HStack(spacing: 6) {
            ForEach(PRFilter.allCases, id: \.self) { filter in
                FilterPill(
                    title: filter.shortLabel,
                    isSelected: viewModel.selectedFilter == filter
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.switchFilter(filter)
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    // MARK: - Rate Limit Banner

    @ViewBuilder
    private var rateLimitBanner: some View {
        if let warning = viewModel.rateLimitWarning {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
                Text(warning)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.08))
        }
    }

    private func errorBanner(message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
                .foregroundStyle(.red)
            Text(message)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Spacer()
            Button {
                Task { await viewModel.refresh() }
            } label: {
                Text("Retry")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.08))
    }

    // MARK: - Content

    private var contentView: some View {
        Group {
            if viewModel.isLoading && viewModel.displayedPullRequests.isEmpty {
                loadingView
            } else if let error = viewModel.errorMessage, viewModel.displayedPullRequests.isEmpty {
                EmptyStateView(
                    icon: "exclamationmark.triangle",
                    title: "Something went wrong",
                    subtitle: error,
                    action: { Task { await viewModel.refresh() } },
                    actionLabel: "Retry"
                )
            } else if viewModel.displayedPullRequests.isEmpty {
                EmptyStateView(
                    icon: "tray",
                    title: "No pull requests",
                    subtitle: "Nothing here right now"
                )
            } else {
                if let error = viewModel.errorMessage {
                    errorBanner(message: error)
                }
                prListView
            }
        }
    }

    private var dynamicListHeight: CGFloat {
        let rowHeight: CGFloat = 72
        let listPadding: CGFloat = 8
        let computed = CGFloat(viewModel.displayedPullRequests.count) * rowHeight + listPadding
        let minHeight: CGFloat = 120
        let maxHeight: CGFloat = 600
        return min(max(computed, minHeight), maxHeight)
    }

    private var prListView: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(viewModel.displayedPullRequests) { pr in
                    PRRowView(
                        pr: pr,
                        isRead: viewModel.readStateService.isRead(pr.id)
                    ) {
                        viewModel.openPR(pr)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .frame(height: dynamicListHeight)
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.small)
                .tint(.secondary)
            Text("Fetching PRs...")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            if let lastUpdated = viewModel.lastUpdated {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.green.opacity(0.6))
                        .frame(width: 5, height: 5)
                    Text("Updated \(formatTimeAgo(lastUpdated))")
                        .font(.system(size: 10))
                        .foregroundStyle(.quaternary)
                }
            }
            Spacer()
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Text("Quit")
                    .font(.system(size: 10))
                    .foregroundStyle(.quaternary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Onboarding

    private var onboardingView: some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                Circle()
                    .fill(.blue.opacity(0.08))
                    .frame(width: 64, height: 64)
                Image(systemName: "arrow.triangle.pull")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(.blue.opacity(0.7))
            }

            VStack(spacing: 4) {
                Text("Git Menu Bar")
                    .font(.system(size: 15, weight: .semibold))
                Text("Connect your GitHub account to see your pull requests here.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 240)
            }

            Button {
                openSettings()
            } label: {
                Text("Connect GitHub")
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.blue)
                    )
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(24)
        .frame(width: 380, height: 260)
    }

    private func formatTimeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Components

struct IconButton: View {
    let icon: String
    var isSpinning: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isHovered ? .primary : .secondary)
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isHovered ? Color.primary.opacity(0.06) : Color.clear)
                )
                .rotationEffect(.degrees(isSpinning ? 360 : 0))
                .animation(
                    isSpinning
                        ? .linear(duration: 0.8).repeatForever(autoreverses: false)
                        : .default,
                    value: isSpinning
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct FilterPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(isSelected
                              ? Color.primary.opacity(0.08)
                              : isHovered
                                ? Color.primary.opacity(0.04)
                                : Color.clear
                        )
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
