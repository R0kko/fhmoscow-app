import SwiftUICore

struct SplashView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 120)
        }
        .onAppear { appState.bootstrap() }
    }
}
