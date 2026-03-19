import Foundation
import SwiftUI

class AppSettings: ObservableObject {
    @AppStorage("refreshInterval") var refreshInterval: TimeInterval = 60
    @AppStorage("maxAgeDays") var maxAgeDays: Int = 30
    @AppStorage("notificationsEnabled") var notificationsEnabled: Bool = true
    @AppStorage("hiddenRepositoriesData") private var hiddenRepositoriesData: Data = Data()

    var hiddenRepositories: Set<String> {
        get {
            (try? JSONDecoder().decode(Set<String>.self, from: hiddenRepositoriesData)) ?? []
        }
        set {
            hiddenRepositoriesData = (try? JSONEncoder().encode(newValue)) ?? Data()
            objectWillChange.send()
        }
    }
}
