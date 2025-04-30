import Foundation
import Combine

extension Notification.Name {
    static let userShouldLogout = Notification.Name("userShouldLogout")
}

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

struct RoleDTO: Codable {
    let name: String
    let alias: String
}

struct UserDTO: Codable {
    let id: String
    let first_name: String
    let last_name: String
    let middle_name: String?
    let email: String?
    let phone: String
    let date_of_birth: String?
    let roles: [RoleDTO]?
}

private struct Empty: Decodable {}

struct API {
    static let base = URL(string: "http://localhost:3000")!
    private static let jsonDecoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    /// Generic GET with optional token & query items
    static func get<T: Decodable>(_ path: String,
                                  token: String? = nil,
                                  query: [URLQueryItem]? = nil,
                                  as type: T.Type) async throws -> T {
        var comps = URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        comps.queryItems = query
        var request = URLRequest(url: comps.url!)
        request.httpMethod = "GET"
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        return try await perform(request: request, decodeAs: type)
    }

    // MARK: - Core request helpers

    static func post<T: Decodable>(_ path: String,
                                           body: [String: Any],
                                           as type: T.Type) async throws -> T {
        let requestURL = base.appendingPathComponent(path)
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await perform(request: request, decodeAs: type)
    }

    private static func patch<T: Decodable, B: Encodable>(_ path: String,
                                                         token: String,
                                                         body: B,
                                                         as type: T.Type) async throws -> T {
        var request = URLRequest(url: base.appendingPathComponent(path))
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)
        return try await perform(request: request, decodeAs: type)
    }

    private static func put<T: Decodable, B: Encodable>(_ path: String,
                                                        token: String,
                                                        body: B,
                                                        as type: T.Type) async throws -> T {
        var request = URLRequest(url: base.appendingPathComponent(path))
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)
        return try await perform(request: request, decodeAs: type)
    }

    static func perform<T: Decodable>(request: URLRequest, decodeAs: T.Type) async throws -> T {
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

            case 401, 403:
                await MainActor.run {
                    NotificationCenter.default.post(name: .userShouldLogout, object: nil)
                }
                throw APIError.invalidCredentials
            case 400:
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

    // MARK: - Public endpoints

    static func login(phone: String, password: String) async throws -> (token: String, user: UserDTO) {
        struct LoginDTO: Codable { let token: String; let user: UserDTO }
        let dto = try await post("/auth/login", body: ["phone": phone, "password": password], as: LoginDTO.self)
        return (dto.token, dto.user)
    }

    /// PUT /users/profile/me/email
    static func updateEmail(_ email: String, token: String) async throws -> UserDTO {
        struct Body: Encodable { let email: String }
        return try await put("/users/profile/me", token: token, body: Body(email: email), as: UserDTO.self)
    }

    /// PATCH /users/profile/me/password
    static func changePassword(old: String, new: String, token: String) async throws {
        struct Body: Encodable { let old_password: String; let new_password: String }
        _ = try await patch("/users/profile/me/password", token: token,
                            body: Body(old_password: old, new_password: new),
                            as: Empty.self)
    }

    /// GET /players?search=
    static func searchPlayers(_ query: String,
                              token: String,
                              page: Int = 1,
                              limit: Int = 20) async throws -> PlayersListResponse {
        var items = [URLQueryItem(name: "page", value: String(page)),
                     URLQueryItem(name: "limit", value: String(limit))]
        if !query.isEmpty { items.append(URLQueryItem(name: "search", value: query)) }
        return try await get("/players", token: token, query: items, as: PlayersListResponse.self)
    }
}
