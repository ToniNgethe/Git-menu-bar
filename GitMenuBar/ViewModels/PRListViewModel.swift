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

    private let apiService = GitHubAPIService()
    private let tokenKey = "github_pat"
    private var timer: AnyCancellable?

    var totalCount: Int { pullRequests.count }

    var hasToken: Bool {
        KeychainHelper.retrieve(for: tokenKey) != nil
    }

    init() {
        isAuthenticated = hasToken
        if isAuthenticated {
            startPolling()
            Task { await refresh() }
        }
    }

    func refresh() async {
        guard let token = KeychainHelper.retrieve(for: tokenKey) else {
            isAuthenticated = false
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            pullRequests = try await apiService.fetchPullRequests(token: token, filter: selectedFilter)
            lastUpdated = Date()
        } catch let error as APIError {
            if case .unauthorized = error {
                isAuthenticated = false
            }
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func switchFilter(_ filter: PRFilter) {
        selectedFilter = filter
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
        timer?.cancel()
        timer = nil
    }

    func openPR(_ pr: PullRequest) {
        guard pr.url.scheme == "https",
              pr.url.host?.hasSuffix("github.com") == true else { return }
        NSWorkspace.shared.open(pr.url)
    }

    private func startPolling() {
        timer?.cancel()
        timer = Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.refresh()
                }
            }
    }
}
