import Foundation

enum ReviewDecision: String, Codable {
    case approved = "APPROVED"
    case changesRequested = "CHANGES_REQUESTED"
    case reviewRequired = "REVIEW_REQUIRED"
    case none = ""
}

enum CIStatus: String, Codable {
    case success = "SUCCESS"
    case failure = "FAILURE"
    case pending = "PENDING"
    case expected = "EXPECTED"
    case error = "ERROR"
    case none = ""
}

struct Label: Identifiable, Codable {
    var id: String { name }
    let name: String
    let color: String
}

struct PullRequest: Identifiable {
    let id: String
    let number: Int
    let title: String
    let url: URL
    let repositoryName: String
    let createdAt: Date
    let updatedAt: Date
    let isDraft: Bool
    let reviewDecision: ReviewDecision
    let ciStatus: CIStatus
    let labels: [Label]

    var statusColor: StatusColor {
        if isDraft { return .draft }
        switch reviewDecision {
        case .approved:
            return ciStatus == .failure || ciStatus == .error ? .failing : .approved
        case .changesRequested:
            return .changesRequested
        case .reviewRequired, .none:
            return ciStatus == .failure || ciStatus == .error ? .failing : .pending
        }
    }

    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: updatedAt, relativeTo: Date())
    }
}

enum StatusColor {
    case approved
    case pending
    case changesRequested
    case failing
    case draft
}

enum PRFilter: String, CaseIterable {
    case reviewRequested = "Review Requested"
    case assigned = "Assigned"
    case created = "Created"

    var shortLabel: String {
        switch self {
        case .reviewRequested: return "Reviews"
        case .assigned: return "Assigned"
        case .created: return "Created"
        }
    }

    var queryFragment: String {
        switch self {
        case .created: return "author:@me"
        case .reviewRequested: return "review-requested:@me"
        case .assigned: return "assignee:@me"
        }
    }
}
