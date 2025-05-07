import Foundation

// MARK: - DTO

struct PlayerDetailDTO: Decodable, Identifiable {
    let id: Int
    let grip: String?
    let height: Int?
    let weight: Int?
    let surname: String
    let name: String
    let patronymic: String?
    let dateOfBirth: String?
    let email: String?
    let sex: String?
    let photo: String?

    struct TeamStat: Decodable, Identifiable {
        var id: Int { teamID }

        let teamID: Int
        let teamName: String
        let clubID: Int?
        let clubName: String?
        let logoURL: String?

        let games: Int
        let goals: Int
        let assists: Int
        let penalties: Int
        let missed: Int
        let reliabilityFactor: Double?   // может быть nil

        private enum CodingKeys: String, CodingKey {
            case teamID          = "team_id"
            case teamName        = "team_name"
            case clubID          = "club_id"
            case clubName        = "club_name"
            case logoURL         = "logo_url"
            case games, goals, assists, penalties, missed
            case reliabilityFactor = "reliability_factor"
        }
    }

    let statistics: [TeamStat]

    // MARK: Coding keys
    private enum CodingKeys: String, CodingKey {
        case id, grip, height, weight,
             surname, name, patronymic,
             dateOfBirth  = "date_of_birth",
             email, sex, photo,
             statistics
    }
}

// MARK: - Сервис

enum PlayerInfoService {

    /// Получить детальную карточку игрока (с агрегированной статистикой)
    ///
    /// GET `/players/{id}?withStats=true`
    ///
    /// - Parameters:
    ///   - id:  идентификатор игрока
    ///   - token: JWT, если нужен авторизованный доступ
    static func detail(id: Int,
                       token: String?) async throws -> PlayerDetailDTO {

        var comps = URLComponents(url: API.base.appendingPathComponent("players/\(id)"),
                                  resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "withStats", value: "true")]

        var request = URLRequest(url: comps.url!)
        request.httpMethod = "GET"

        if let token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        #if DEBUG
        print("➡️ [Player] GET \(request.url?.absoluteString ?? "")")
        #endif

        do {
            let dto = try await API.perform(request: request,
                                            decodeAs: PlayerDetailDTO.self)
            #if DEBUG
            print("✅ [Player] id \(dto.id) loaded with \(dto.statistics.count) team stats")
            #endif
            return dto
        } catch {
            #if DEBUG
            print("❌ [Player] error:", error.localizedDescription)
            #endif
            throw error
        }
    }

    /// Список матчей, в которых участвовал игрок
    /// GET `/games?playerId={id}&page={page}&limit={limit}`
    ///
    /// - Parameters:
    ///   - playerId: идентификатор игрока
    ///   - page:     номер страницы (по умолчанию — 1)
    ///   - limit:    количество элементов на страницу (по умолчанию — 20)
    ///   - token:    JWT, если нужен авторизованный доступ
    static func games(playerId: Int,
                      page: Int = 1,
                      limit: Int = 20,
                      token: String?) async throws -> GamesListResponse {

        var comps = URLComponents(url: API.base.appendingPathComponent("games"),
                                  resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            URLQueryItem(name: "playerId", value: String(playerId)),
            URLQueryItem(name: "page",      value: String(page)),
            URLQueryItem(name: "limit",     value: String(limit))
        ]

        var request = URLRequest(url: comps.url!)
        request.httpMethod = "GET"

        if let token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        #if DEBUG
        print("➡️ [Games] GET \(request.url?.absoluteString ?? "")")
        #endif

        do {
            let resp = try await API.perform(request: request,
                                             decodeAs: GamesListResponse.self)
            #if DEBUG
            print("✅ [Games] page \(page): \(resp.data.count) items")
            #endif
            return resp
        } catch {
            #if DEBUG
            print("❌ [Games] error:", error.localizedDescription)
            #endif
            throw error
        }
    }
}
