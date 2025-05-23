import SwiftUI
import Combine

// MARK: - Role model
struct Role: Codable, Identifiable {
    var id: String { alias }       // alias выступает в роли уникального идентификатора
    let name: String
    let alias: String
}

// MARK: - Persisted user model
struct User: Codable, Identifiable {
    let id: String
    let firstName: String
    let lastName: String
    let middleName: String?
    let dateOfBirth: Date?
    let email: String?
    let phone: String
    let roles: [Role]              // массив ролей пользователя

    enum CodingKeys: String, CodingKey {
        case id
        case firstName  = "first_name"
        case lastName   = "last_name"
        case middleName = "middle_name"
        case dateOfBirth = "date_of_birth"
        case email
        case phone
        case roles
    }

    var displayName: String {
        let initial = firstName.first.map { String($0) } ?? ""
        return "\(lastName) \(initial)."
    }
}

private enum StorageKey {
    static let user = "currentUser"
}

@MainActor
final class AppState: ObservableObject {
    enum Route { case splash, auth, home }

    // MARK: - Published state
    @Published var route: Route = .splash
    @Published var currentUser: User? = nil
    @Published var token: String? = nil

    // MARK: - Private
    private let keychain = KeychainService()
    private var cancellables = Set<AnyCancellable>()
    /// Помогает избежать дублирования подписки при повторном bootstrap()
    private var isLogoutObserverAttached = false

    // MARK: - Bootstrap (called from SplashView)
    func bootstrap() {
        Task { await bootstrapAsync() }
    }

    func bootstrapAsync() async {
        try? await Task.sleep(for: .milliseconds(800))

        do {
            token = try keychain.readToken()
        } catch {
            print("⚠️ Keychain read failed:", error)
            token = nil
        }

        if let data = UserDefaults.standard.data(forKey: StorageKey.user) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let user = try? decoder.decode(User.self, from: data) {
                currentUser = user
            }
        }

        let hasSession = (self.token != nil) && (currentUser != nil)
        route = hasSession ? .home : .auth

        if !isLogoutObserverAttached {
            NotificationCenter.default.publisher(for: .userShouldLogout)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in self?.logout() }
                .store(in: &cancellables)
            isLogoutObserverAttached = true
        }
    }

    // MARK: - Сохранение сессии после логина
    func saveSession(token: String, user: User) {
        do {
            try keychain.save(token: token)
        } catch {
            print("⚠️ Keychain save failed:", error)
        }
        self.token = token
        currentUser = user

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(user) {
            UserDefaults.standard.set(data, forKey: StorageKey.user)
        }
        route = .home
    }

    // MARK: - Logout
    func logout() {
        do {
            try keychain.deleteToken()
        } catch {
            print("⚠️ Keychain delete failed:", error)
        }
        self.token = nil
        UserDefaults.standard.removeObject(forKey: StorageKey.user)
        route = .auth
        currentUser = nil
    }
}
