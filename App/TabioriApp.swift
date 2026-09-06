import SwiftUI

@main
struct TabioriApp: App {
    @State private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            TripsView()
                .environment(store)
                .environment(\.locale, Locale(identifier: "ja_JP"))
                .tint(AppTheme.teal)
                .preferredColorScheme(store.settings.appearance.colorScheme)
        }
    }
}
