import SwiftUI
import Combine

// MARK: - Persisted user model
struct User: Codable, Identifiable {
    let id: String
    let firstName: String
    let lastName: String
    let email: String?
    let phone: String

    var displayName: String { firstName }
}

@MainActor
final class AppState: ObservableObject {
    enum Route { case splash, auth, home }

    // MARK: - Published state
    @Published var route: Route = .splash
    @Published var currentUser: User? = nil

    // MARK: - Private
    private let keychain = KeychainService()

    // MARK: - Bootstrap (called from SplashView)
    func bootstrap() {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.8)) // небольшая задержка для анимации

            // 1) Токен
            let token = try? keychain.readToken()

            // 2) Пользователь из UserDefaults (если был сохранён)
            if let data = UserDefaults.standard.data(forKey: "currentUser"),
               let user = try? JSONDecoder().decode(User.self, from: data) {
                currentUser = user
            }

            // 3) Решаем, какой экран показать
            let hasSession = (token != nil) && (currentUser != nil)
            route = hasSession ? .home : .auth
        }
    }

    // MARK: - Сохранение сессии после логина
    func saveSession(token: String, user: User) {
        try? keychain.save(token: token)
        currentUser = user

        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: "currentUser")
        }
        route = .home
    }

    // MARK: - Logout
    func logout() {
        try? keychain.deleteToken()
        UserDefaults.standard.removeObject(forKey: "currentUser")
        currentUser = nil
        route = .auth
    }
}
