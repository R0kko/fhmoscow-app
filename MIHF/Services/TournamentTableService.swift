import Foundation

// MARK: - DTOs
/// Одна строка турнирной таблицы
struct TableRowDTO: Identifiable, Decodable {
    let id = UUID()                   // локальный id для SwiftUI
    let teamId: Int
    let shortName: String
    let logo: String?
    let gameCount: Int
    let winCount: Int
    let tieCount: Int
    let lossCount: Int
    let winOvertimeCount: Int
    let loseOvertimeCount: Int
    let pucksScored: Int
    let pucksMissed: Int
    let pucksDifference: Double
    let score: Int
    let position: Int

    private enum CodingKeys: String, CodingKey {
        case teamId          = "team_id"
        case shortName       = "short_name"
        case logo
        case gameCount       = "game_count"
        case winCount        = "win_count"
        case tieCount        = "tie_count"
        case lossCount       = "loss_count"
        case winOvertimeCount  = "win_overtime_count"
        case loseOvertimeCount = "lose_overtime_count"
        case pucksScored     = "pucks_scored"
        case pucksMissed     = "pucks_missed"
        case pucksDifference = "pucks_difference"
        case score
        case position
    }
}

/// Ответ от `/tournamentTables`
struct TablesListResponse: Decodable {
    let data: [TableRowDTO]
    let total: Int
    let page: Int
    let limit: Int
}

// MARK: - Service
enum TableService {
    /// Загрузить таблицу для конкретной группы (`groupId`)
    ///
    /// - Parameters:
    ///   - groupId: ID группы (обязательно)
    ///   - moscowStanding: true/false — московская или «общая» таблица
    ///   - page:  номер страницы (1-based, default 1)
    ///   - limit: элементов на страницу (default 20)
    ///   - token: JWT-токен (`AppState.token`)
    static func list(
        groupId: Int,
        moscowStanding: Bool,
        page: Int = 1,
        limit: Int = 20,
        token: String?
    ) async throws -> TablesListResponse {

        // URL + query-параметры
        var comps = URLComponents(url: API.base.appendingPathComponent("tournamentTables"),
                                  resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            URLQueryItem(name: "groupId", value: String(groupId)),
            URLQueryItem(name: "moscowStanding", value: moscowStanding ? "true" : "false"),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "limit", value: String(limit)),
        ]

        var request = URLRequest(url: comps.url!)
        request.httpMethod = "GET"
        if let token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        #if DEBUG
        print("➡️ [Tables] GET", request.url?.absoluteString ?? "")
        #endif

        do {
            let response = try await API.perform(request: request,
                                                 decodeAs: TablesListResponse.self)
            #if DEBUG
            print("✅ [Tables] page \(page):", response.data.count, "items")
            #endif
            return response
        } catch {
            #if DEBUG
            print("❌ [Tables] error:", error.localizedDescription)
            #endif
            throw error
        }
    }
}
