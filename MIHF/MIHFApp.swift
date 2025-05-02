import SwiftUI

@main
struct MIHFApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                RootRouter()
            }
            .environmentObject(appState)
            .task { await appState.bootstrapAsync() } 
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
