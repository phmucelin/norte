import SwiftUI
import NorteKit

@main
struct NorteiOSApp: App {
    var body: some Scene {
        WindowGroup {
            iOSRootView()
                .preferredColorScheme(.dark)
        }
    }
}
