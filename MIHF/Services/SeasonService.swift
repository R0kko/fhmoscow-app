import Foundation

/// DTO сезона (id + человекочитаемое имя)
struct SeasonDTO: Identifiable, Decodable, Hashable {
    let id: Int
    let name: String
}

/// Сервис справочника сезонов
enum SeasonService {

    /// Получить список сезонов (status = new | active)
    /// - Parameter token: JWT из `AppState.token` (можно передать `nil`, тогда будет запрос без авторизации).
    /// - Returns: массив `SeasonDTO`, отсортированный по id DESC
    static func list(token: String?) async throws -> [SeasonDTO] {
        var url = API.base
        url.appendPathComponent("/seasons")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Прямой decode массива DTO
        return try await API.perform(request: request, decodeAs: [SeasonDTO].self)
    }
}
