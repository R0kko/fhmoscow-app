import Foundation

struct TournamentsListResponse: Decodable {
    let data: [TournamentRowDTO]
    let total: Int
    let page: Int?
}

enum TournamentListService {
    /// Получить список турниров с пагинацией и фильтрами.
    /// - Parameters:
    ///   - seasonId: ID сезона (optional).
    ///   - yearOfBirth: фильтр по году рождения (optional).
    ///   - page: номер страницы (1‑based, default 1).
    ///   - limit: кол-во элементов (default 20).
    ///   - token: JWT-токен из `AppState.token`.
    /// - Returns: `TournamentsListResponse`.
    static func list(seasonId: Int? = nil,
                     yearOfBirth: Int? = nil,
                     page: Int = 1,
                     limit: Int = 20,
                     token: String?) async throws -> TournamentsListResponse {

        var comps = URLComponents(url: API.base.appendingPathComponent("/tournaments"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        if let seasonId { comps.queryItems?.append(URLQueryItem(name: "season", value: String(seasonId))) }
        if let yearOfBirth { comps.queryItems?.append(URLQueryItem(name: "year", value: String(yearOfBirth))) }

        var request = URLRequest(url: comps.url!)
        request.httpMethod = "GET"
        if let token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        print("➡️ [Tournaments] GET", request.url?.absoluteString ?? "")
        do {
            let response = try await API.perform(request: request, decodeAs: TournamentsListResponse.self)
            print("✅ [Tournaments] page \(page):", response.data.count, "items")
            return response
        } catch {
            print("❌ [Tournaments] error:", error.localizedDescription)
            throw error
        }
    }
}
