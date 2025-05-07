import Foundation

// MARK: - DTOs
/// Элемент списка групп, приходит от API
struct GroupRowDTO: Identifiable, Decodable {
    let id: Int
    let name: String
    let stageId: Int
    let tournamentId: Int

    private enum CodingKeys: String, CodingKey {
        case id, name
        case stageId      = "stage_id"
        case tournamentId = "tournament_id"
    }
}

/// Ответ API со списком групп
struct GroupsListResponse: Decodable {
    let data: [GroupRowDTO]
    let total: Int
    let page: Int?
}

/// Сервис работы со списком групп
enum GroupService {
    /// Получить группы по этапу (или турниру) с пагинацией.
    /// - Parameters:
    ///   - stageId:   идентификатор этапа (`/groups?stage=ID`)
    ///   - page:      номер страницы (1‑based, default 1)
    ///   - limit:     кол‑во элементов (default 50)
    ///   - token:     JWT‑токен (`AppState.token`). Если `nil` – запрос без авторизации
    /// - Returns: `GroupsListResponse`
    static func list(
        stageId: Int,
        page: Int = 1,
        limit: Int = 50,
        token: String?
    ) async throws -> GroupsListResponse {

        var comps = URLComponents(url: API.base.appendingPathComponent("groups"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            URLQueryItem(name: "stageId", value: String(stageId)),
            URLQueryItem(name: "page",     value: String(page)),
            URLQueryItem(name: "limit",    value: String(limit))
        ]

        var request = URLRequest(url: comps.url!)
        request.httpMethod = "GET"
        if let token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        #if DEBUG
        print("➡️ [Groups] GET", request.url?.absoluteString ?? "")
        #endif

        do {
            let response = try await API.perform(request: request, decodeAs: GroupsListResponse.self)
            #if DEBUG
            print("✅ [Groups] page \(page):", response.data.count, "items")
            #endif
            return response
        } catch {
            #if DEBUG
            print("❌ [Groups] error:", error.localizedDescription)
            #endif
            throw error
        }
    }
}
