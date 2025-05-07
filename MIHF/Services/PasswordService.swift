import Foundation

struct PasswordService {
    enum PasswordError: Error {
        case wrongOldPassword
    }

    enum ServiceError: Error {
        case noConnection
        case server(status: Int)
    }

    /// PATCH /users/me/password
    /// - Parameters:
    ///   - old:  Старый пароль
    ///   - new:  Новый пароль (уже валидирован на стороне UI)
    ///   - token: JWT пользователя
    static func changePassword(old: String,
                               new: String,
                               token: String) async throws {
        do {
            try await API.changePassword(old: old, new: new, token: token)
        } catch let apiErr as APIError {
            switch apiErr {
            case .invalidCredentials:
                throw PasswordError.wrongOldPassword
            case .noConnection:
                throw ServiceError.noConnection
            case .serverStatus(let code):
                throw ServiceError.server(status: code)
            default:
                throw apiErr       
            }
        }
    }
}
