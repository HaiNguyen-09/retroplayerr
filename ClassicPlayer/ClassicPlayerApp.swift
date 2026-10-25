import SwiftUI

@main
struct ClassicPlayerApp: App {
    var body: some Scene {
        WindowGroup {
            ClassicPlayerRootView()
                .preferredColorScheme(.light)
                .statusBarHidden(true)
                .persistentSystemOverlays(.hidden)
        }
    }
}
