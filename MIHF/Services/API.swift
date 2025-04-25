import Foundation

enum APIError: LocalizedError {
    case invalidCredentials
    case serverStatus(Int)
    case decoding
    case noConnection
    case network(URLError)
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Неверный телефон или пароль"
        case .serverStatus(let code):
            return "Ошибка сервера (код: \(code))"
        case .decoding:
            return "Не удалось обработать ответ сервера"
        case .noConnection:
            return "Отсутствует подключение к интернету"
        case .network(let urlError):
            return urlError.localizedDescription
        case .unknown:
            return "Неизвестная ошибка"
        }
    }
}

// MARK: - DTOs
struct UserDTO: Codable {
    let id: String
    let first_name: String
    let last_name: String
    let email: String?
    let phone: String
}

struct API {
    private static let base = URL(string: "http://127.0.0.1:3000")!
    private static let jsonEncoder = JSONEncoder()
    private static let jsonDecoder = JSONDecoder()

    // MARK: - Public endpoints

    static func login(phone: String, password: String) async throws -> (token: String, user: UserDTO) {
        struct LoginDTO: Codable { let token: String; let user: UserDTO }
        let dto = try await post("/auth/login", body: ["phone": phone, "password": password], as: LoginDTO.self)
        return (dto.token, dto.user)
    }

    // MARK: - Core request helpers

    private static func post<T: Decodable>(_ path: String,
                                           body: [String: Any],
                                           as type: T.Type) async throws -> T {
        let requestURL = base.appendingPathComponent(path)
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await perform(request: request, decodeAs: type)
    }

    private static func perform<T: Decodable>(request: URLRequest, decodeAs: T.Type) async throws -> T {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw APIError.unknown }

            switch http.statusCode {
            case 200...299:
                do {
                    return try jsonDecoder.decode(T.self, from: data)
                } catch {
                    Logger.shared.error("Decoding error: \(error.localizedDescription)")
                    throw APIError.decoding
                }

            case 401, 400:
                throw APIError.invalidCredentials
            default:
                throw APIError.serverStatus(http.statusCode)
            }
        } catch let urlErr as URLError {
            if urlErr.code == .notConnectedToInternet || urlErr.code == .networkConnectionLost || urlErr.code == .timedOut || urlErr.code == .cannotFindHost || urlErr.code == .cannotConnectToHost {
                Logger.shared.error("No connection error: \(urlErr)")
                throw APIError.noConnection
            } else {
                Logger.shared.error("Network error: \(urlErr)")
                throw APIError.network(urlErr)
            }
        } catch let apiErr as APIError {
            throw apiErr
        } catch {
            Logger.shared.error("Unknown error: \(error)")
            throw APIError.unknown
        }
    }
}
