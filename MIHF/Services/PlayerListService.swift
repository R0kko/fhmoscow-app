import Foundation

/// Сервис работы со списком игроков
enum PlayersListService {

    /// Выполнить поиск игроков.
    /// - Parameters:
    ///   - query: строка поиска (фамилия/ФИО). Пустая = все.
    ///   - page: номер страницы (начинается с 1).
    ///   - limit: элементы на страницу (дефолт 20).
    ///   - token: JWT из `AppState.token`.
    /// - Returns: `PlayersListResponse` (data, page, total)
    static func search(query: String,
                       page: Int = 1,
                       limit: Int = 20,
                       token: String) async throws -> PlayersListResponse {
        // Формируем URL с queryItems
        var comps = URLComponents(url: API.base.appendingPathComponent("/players"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        if !query.isEmpty {
            comps.queryItems?.append(URLQueryItem(name: "search", value: query))
        }

        var request = URLRequest(url: comps.url!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        return try await API.perform(request: request, decodeAs: PlayersListResponse.self)
    }
}
