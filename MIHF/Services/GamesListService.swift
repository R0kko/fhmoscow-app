import Foundation

// MARK: - DTOs coming from API
struct ScoreDTO: Decodable {
    let team1: Int?
    let team2: Int?
}

struct TeamShortDTO: Decodable {
    let id: Int
    let name: String
    let logo_url: String?
}

struct StadiumShortDTO: Decodable {
    let id: Int
    let name: String
}

struct TournamentShortDTO: Decodable {
    let id: Int
    let name: String
}

struct GroupShortDTO: Decodable {
    let id: Int
    let name: String
}

struct GameRowDTO: Identifiable, Decodable {
    let id: Int
    let date_start: String
    let status: Int
    let score: ScoreDTO?
    let team1: TeamShortDTO
    let team2: TeamShortDTO
    let stadium: StadiumShortDTO?
    let tournament: TournamentShortDTO?
    let group: GroupShortDTO?

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    var startDate: Date? { Self.isoFormatter.date(from: date_start) }
}

// MARK: - Paginated response
struct GamesListResponse: Decodable {
    let data: [GameRowDTO]
    let total: Int
    let page: Int
    let limit: Int
}

// MARK: - Service
/// Аналогично `TournamentListService` — загрузка списка матчей с фильтрами.
enum GamesListService {

    /// Получить список игр.
    /// - Parameters:
    ///   - dateFrom: начальная дата (UTC, опционально)
    ///   - dateTo: конечная дата (UTC, опционально)
    ///   - stadiumId: фильтр по стадиону
    ///   - teamId: фильтр по команде (играет **хотя бы** одна из команд)
    ///   - status: статус матча (0‑план, 1‑лайв, 2‑завершён и т.д.)
    ///   - page: страница (по умолчанию 1)
    ///   - limit: элементов на страницу (по умолчанию 20)
    ///   - token: JWT из `AppState.token`
    static func list(dateFrom: Date? = nil,
                     dateTo: Date? = nil,
                     stadiumId: Int? = nil,
                     teamId: Int? = nil,
                     status: Int? = nil,
                     page: Int = 1,
                     limit: Int = 20,
                     token: String?) async throws -> GamesListResponse {

        // Формируем URL
        var comps = URLComponents(url: API.base.appendingPathComponent("/games"),
                                  resolvingAgainstBaseURL: false)!
        var items: [URLQueryItem] = [
            .init(name: "page", value: String(page)),
            .init(name: "limit", value: String(limit))
        ]

        let df = ISO8601DateFormatter()
        df.formatOptions = [.withFullDate]          // yyyy‑MM‑dd

        if let from = dateFrom {
            items.append(.init(name: "dateFrom", value: df.string(from: from)))
        }
        if let to = dateTo {
            items.append(.init(name: "dateTo", value: df.string(from: to)))
        }
        if let stadiumId {
            items.append(.init(name: "stadiumId", value: String(stadiumId)))
        }
        if let teamId {
            items.append(.init(name: "teamId", value: String(teamId)))
        }
        if let status {
            items.append(.init(name: "status", value: String(status)))
        }

        comps.queryItems = items

        var request = URLRequest(url: comps.url!)
        request.httpMethod = "GET"
        if let token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        print("➡️ [Games] GET", request.url?.absoluteString ?? "")
        do {
            let response = try await API.perform(request: request,
                                                 decodeAs: GamesListResponse.self)
            print("✅ [Games] page \(page):", response.data.count, "items")
            return response
        } catch {
            print("❌ [Games] error:", error.localizedDescription)
            throw error
        }
    }
}
