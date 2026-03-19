import Foundation
import AppKit
import UserNotifications

class NotificationService: NSObject, UNUserNotificationCenterDelegate {

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func checkForNewPRs(old: [PullRequest], new: [PullRequest], filter: PRFilter) {
        let oldIds = Set(old.map(\.id))
        let oldById = Dictionary(uniqueKeysWithValues: old.map { ($0.id, $0) })

        for pr in new {
            if !oldIds.contains(pr.id) {
                // New PR appeared
                switch filter {
                case .reviewRequested:
                    send(title: "New review request", body: pr.title, prURL: pr.url)
                case .assigned:
                    send(title: "New assignment", body: pr.title, prURL: pr.url)
                case .created:
                    break
                }
            } else if filter == .created, let oldPR = oldById[pr.id] {
                // Check for status changes on user's own PRs
                if oldPR.reviewDecision != .approved && pr.reviewDecision == .approved {
                    send(title: "PR Approved", body: pr.title, prURL: pr.url)
                } else if oldPR.reviewDecision != .changesRequested && pr.reviewDecision == .changesRequested {
                    send(title: "Changes Requested", body: pr.title, prURL: pr.url)
                }
            }
        }
    }

    private func send(title: String, body: String, prURL: URL) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["url": prURL.absoluteString]

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let urlString = response.notification.request.content.userInfo["url"] as? String,
           let url = URL(string: urlString),
           url.scheme == "https",
           url.host?.hasSuffix("github.com") == true {
            NSWorkspace.shared.open(url)
        }
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
