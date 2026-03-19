import SwiftUI

@main
struct GitMenuBarApp: App {
    @StateObject private var viewModel = PRListViewModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(viewModel: viewModel)
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "arrow.triangle.pull")
                    .font(.system(size: 12))
                if viewModel.totalCount > 0 {
                    Text("\(viewModel.totalCount)")
                        .font(.system(size: 11, weight: .medium))
                        .monospacedDigit()
                }
            }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(viewModel)
        }
    }
}
