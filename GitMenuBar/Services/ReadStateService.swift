import Foundation

class ReadStateService {
    private let key = "readPRIds"

    var readIds: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: key) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: key) }
    }

    func markAsRead(_ id: String) {
        var ids = readIds
        ids.insert(id)
        readIds = ids
    }

    func isRead(_ id: String) -> Bool {
        readIds.contains(id)
    }

    func clearAll() {
        readIds = []
    }
}
