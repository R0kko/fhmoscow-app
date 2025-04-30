import Foundation

/// Сервис, инкапсулирующий логику смены пароля.
struct PasswordService {

    /// Ошибки, возвращаемые при попытке сменить пароль.
    enum PasswordError: Error {
        /// Неверно введён старый пароль
        case wrongOldPassword
    }

    /// Ошибки транспортного уровня (связь с сервером).
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
