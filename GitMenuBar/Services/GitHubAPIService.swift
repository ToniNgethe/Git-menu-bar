import Foundation

actor GitHubAPIService {
    private let endpoint = URL(string: "https://api.github.com/graphql")!

    private let query = """
    query($searchQuery: String!) {
      search(query: $searchQuery, type: ISSUE, first: 30) {
        nodes {
          ... on PullRequest {
            id
            number
            title
            url
            repository {
              nameWithOwner
            }
            createdAt
            updatedAt
            isDraft
            reviewDecision
            commits(last: 1) {
              nodes {
                commit {
                  statusCheckRollup {
                    state
                  }
                }
              }
            }
            labels(first: 5) {
              nodes {
                name
                color
              }
            }
          }
        }
      }
    }
    """

    func fetchPullRequests(token: String, filter: PRFilter) async throws -> [PullRequest] {
        let searchQuery = "is:pr is:open \(filter.queryFragment)"

        let body: [String: Any] = [
            "query": query,
            "variables": ["searchQuery": searchQuery]
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            }
            throw APIError.httpError(httpResponse.statusCode)
        }

        return try parseResponse(data)
    }

    func validateToken(_ token: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.github.com/user")!)
        request.setValue("bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.unauthorized
        }

        // Validate required scope
        let scopes = httpResponse.value(forHTTPHeaderField: "X-OAuth-Scopes") ?? ""
        let scopeList = scopes.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard scopeList.contains("repo") else {
            throw APIError.insufficientScopes
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return json?["login"] as? String ?? "Unknown"
    }

    private func parseResponse(_ data: Data) throws -> [PullRequest] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = json["data"] as? [String: Any],
              let search = dataObj["search"] as? [String: Any],
              let nodes = search["nodes"] as? [[String: Any]] else {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errors = json["errors"] as? [[String: Any]],
               let message = errors.first?["message"] as? String {
                throw APIError.graphQLError(message)
            }
            throw APIError.parseError
        }

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let fallbackFormatter = ISO8601DateFormatter()

        func parseDate(_ string: String) -> Date {
            dateFormatter.date(from: string) ?? fallbackFormatter.date(from: string) ?? Date()
        }

        return nodes.compactMap { node -> PullRequest? in
            guard let id = node["id"] as? String,
                  let number = node["number"] as? Int,
                  let title = node["title"] as? String,
                  let urlString = node["url"] as? String,
                  let url = URL(string: urlString),
                  let repo = node["repository"] as? [String: Any],
                  let repoName = repo["nameWithOwner"] as? String,
                  let createdAtStr = node["createdAt"] as? String,
                  let updatedAtStr = node["updatedAt"] as? String else {
                return nil
            }

            let isDraft = node["isDraft"] as? Bool ?? false

            let reviewDecisionStr = node["reviewDecision"] as? String ?? ""
            let reviewDecision = ReviewDecision(rawValue: reviewDecisionStr) ?? .none

            var ciStatus: CIStatus = .none
            if let commits = node["commits"] as? [String: Any],
               let commitNodes = commits["nodes"] as? [[String: Any]],
               let lastCommit = commitNodes.last,
               let commit = lastCommit["commit"] as? [String: Any],
               let rollup = commit["statusCheckRollup"] as? [String: Any],
               let state = rollup["state"] as? String {
                ciStatus = CIStatus(rawValue: state) ?? .none
            }

            var labels: [Label] = []
            if let labelsObj = node["labels"] as? [String: Any],
               let labelNodes = labelsObj["nodes"] as? [[String: Any]] {
                labels = labelNodes.compactMap { labelNode in
                    guard let name = labelNode["name"] as? String,
                          let color = labelNode["color"] as? String else { return nil }
                    return Label(name: name, color: color)
                }
            }

            return PullRequest(
                id: id,
                number: number,
                title: title,
                url: url,
                repositoryName: repoName,
                createdAt: parseDate(createdAtStr),
                updatedAt: parseDate(updatedAtStr),
                isDraft: isDraft,
                reviewDecision: reviewDecision,
                ciStatus: ciStatus,
                labels: labels
            )
        }
    }
}

enum APIError: LocalizedError {
    case invalidResponse
    case unauthorized
    case insufficientScopes
    case httpError(Int)
    case parseError
    case graphQLError(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid response from GitHub"
        case .unauthorized: return "Invalid or expired token"
        case .insufficientScopes: return "Token is missing the required 'repo' scope"
        case .httpError(let code): return "HTTP error \(code)"
        case .parseError: return "Failed to parse response"
        case .graphQLError(let msg): return msg
        }
    }
}
