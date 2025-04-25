import SwiftUI

@main
struct CourseAppApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootRouter()
                .environmentObject(appState)
        }
    }
}

struct RootRouter: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        switch appState.route {
        case .splash: SplashView()
        case .auth:   AuthView()
        case .home:   HomeView()
        }
    }
}
