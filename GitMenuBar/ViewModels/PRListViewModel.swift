import Foundation
import SwiftUI
import Combine

@MainActor
class PRListViewModel: ObservableObject {
    @Published var pullRequests: [PullRequest] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedFilter: PRFilter = .reviewRequested
    @Published var lastUpdated: Date?
    @Published var isAuthenticated = false
    @Published var username: String?
    @Published var rateLimitWarning: String?
    @Published var sortOrder: PRSortOrder = .updatedDate

    let readStateService = ReadStateService()

    private let apiService = GitHubAPIService()
    private let cacheService = CacheService()
    private let notificationService = NotificationService()
    private let tokenKey = "github_pat"
    private var timer: AnyCancellable?
    private var settingsCancellable: AnyCancellable?
    private var retryCount = 0
    private let maxRetries = 3
    private var retryTask: Task<Void, Never>?

    var appSettings: AppSettings?

    var totalCount: Int { pullRequests.count }

    var displayedPullRequests: [PullRequest] {
        let hidden = appSettings?.hiddenRepositories ?? []
        var result = pullRequests
        if !hidden.isEmpty {
            result = result.filter { !hidden.contains($0.repositoryName) }
        }
        switch sortOrder {
        case .updatedDate:
            result.sort { $0.updatedAt > $1.updatedAt }
        case .createdDate:
            result.sort { $0.createdAt > $1.createdAt }
        case .repositoryName:
            result.sort { $0.repositoryName.localizedCaseInsensitiveCompare($1.repositoryName) == .orderedAscending }
        }
        return result
    }

    var allRepositories: [String] {
        Array(Set(pullRequests.map(\.repositoryName))).sorted()
    }

    var hasToken: Bool {
        KeychainHelper.retrieve(for: tokenKey) != nil
    }

    init() {
        isAuthenticated = hasToken
        if isAuthenticated {
            // Load cached PRs for instant display
            if let cached = cacheService.load(filter: selectedFilter) {
                pullRequests = cached
            }
            startPolling()
            Task { await refresh() }
        }
    }

    func configure(settings: AppSettings) {
        self.appSettings = settings
        settingsCancellable = settings.objectWillChange.sink { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.restartPolling()
            }
        }
    }

    func refresh() async {
        guard let token = KeychainHelper.retrieve(for: tokenKey) else {
            isAuthenticated = false
            return
        }

        isLoading = true
        errorMessage = nil
        retryTask?.cancel()
        retryTask = nil

        do {
            let (fetchedPRs, rateLimitRemaining, rateLimitResetDate) = try await apiService.fetchPullRequests(token: token, filter: selectedFilter)

            let maxDays = appSettings?.maxAgeDays ?? 30
            var results: [PullRequest]
            if maxDays > 0 {
                let cutoffDate = Calendar.current.date(byAdding: .day, value: -maxDays, to: Date())!
                results = fetchedPRs.filter { $0.createdAt > cutoffDate && $0.updatedAt > cutoffDate }
            } else {
                results = fetchedPRs
            }

            if selectedFilter == .assigned {
                results = results.filter { $0.reviewDecision != .approved }
            }

            // Check for new PRs and send notifications
            if appSettings?.notificationsEnabled ?? true {
                notificationService.checkForNewPRs(old: pullRequests, new: results, filter: selectedFilter)
            }

            pullRequests = results
            lastUpdated = Date()
            retryCount = 0

            // Cache results
            cacheService.save(prs: results, filter: selectedFilter)

            // Update rate limit warning
            if let remaining = rateLimitRemaining, remaining < 10 {
                let resetText: String
                if let resetDate = rateLimitResetDate {
                    let formatter = RelativeDateTimeFormatter()
                    formatter.unitsStyle = .abbreviated
                    resetText = " Resets \(formatter.localizedString(for: resetDate, relativeTo: Date()))"
                } else {
                    resetText = ""
                }
                rateLimitWarning = "API rate limit low: \(remaining) remaining.\(resetText)"
            } else {
                rateLimitWarning = nil
            }
        } catch let error as APIError {
            if case .unauthorized = error {
                isAuthenticated = false
            } else if case .rateLimited(let resetDate) = error {
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .abbreviated
                rateLimitWarning = "Rate limited. Resets \(formatter.localizedString(for: resetDate, relativeTo: Date()))"
            } else {
                scheduleRetry()
            }
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
            scheduleRetry()
        }

        isLoading = false
    }

    func switchFilter(_ filter: PRFilter) {
        selectedFilter = filter
        // Load cached data for instant switch
        if let cached = cacheService.load(filter: filter) {
            pullRequests = cached
        }
        Task { await refresh() }
    }

    func saveToken(_ token: String) async -> Bool {
        do {
            let login = try await apiService.validateToken(token)
            try KeychainHelper.save(token: token, for: tokenKey)
            username = login
            isAuthenticated = true
            startPolling()
            await refresh()
            return true
        } catch {
            errorMessage = "Invalid token: \(error.localizedDescription)"
            return false
        }
    }

    func signOut() {
        try? KeychainHelper.delete(for: tokenKey)
        isAuthenticated = false
        username = nil
        pullRequests = []
        lastUpdated = nil
        rateLimitWarning = nil
        retryTask?.cancel()
        retryTask = nil
        retryCount = 0
        timer?.cancel()
        timer = nil
    }

    func openPR(_ pr: PullRequest) {
        guard pr.url.scheme == "https",
              pr.url.host?.hasSuffix("github.com") == true else { return }
        readStateService.markAsRead(pr.id)
        objectWillChange.send()
        NSWorkspace.shared.open(pr.url)
    }

    func markAllAsRead() {
        for pr in pullRequests {
            readStateService.markAsRead(pr.id)
        }
        objectWillChange.send()
    }

    // MARK: - Private

    private func startPolling() {
        timer?.cancel()
        let interval = appSettings?.refreshInterval ?? 60
        timer = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.refresh()
                }
            }
    }

    private func restartPolling() {
        if isAuthenticated {
            startPolling()
        }
    }

    private func scheduleRetry() {
        guard retryCount < maxRetries else { return }
        retryCount += 1
        let delay = min(pow(2.0, Double(retryCount)) * 5.0, 120.0)
        retryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await self?.refresh()
        }
    }
}
