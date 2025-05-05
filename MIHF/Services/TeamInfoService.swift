import Foundation

/// Короткая карточка команды (для списков)
struct TeamRowDTO: Identifiable, Decodable {
    let id: Int
    let shortName: String
    let logoUrl: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case shortName = "short_name"
        case logoUrl   = "logo_url"
    }
}

/// Ответ `/teams` (список + пагинация)
struct TeamsListResponse: Decodable {
    let data: [TeamRowDTO]
    let total: Int
    let page: Int
    let limit: Int
}

/// Детальная информация о команде + составы
struct TeamDetailDTO: Decodable {
    struct Player: Identifiable, Decodable {
        let id: Int
        let fullName: String
        let dateOfBirth: String?
        let number: Int?
        let position: String?
        let photoUrl: String?

        private enum CodingKeys: String, CodingKey {
            case id
            case fullName    = "full_name"
            case dateOfBirth = "date_of_birth"
            case number
            case position
            case photoUrl    = "photo_url"
        }
    }

    struct Staff: Identifiable, Decodable {
        let id: Int
        let fullName: String
        let category: String?
        let photoUrl: String?

        private enum CodingKeys: String, CodingKey {
            case id
            case fullName = "full_name"
            case category
            case photoUrl = "photo_url"
        }
    }

    let id: Int
    let clubId: Int?
    let fullName: String
    let shortName: String
    let year: Int?
    let logoUrl: String?
    let players: [Player]
    let staff: [Staff]

    private enum CodingKeys: String, CodingKey {
        case id
        case clubId    = "club_id"
        case fullName  = "full_name"
        case shortName = "short_name"
        case year
        case logoUrl   = "logo_url"
        case players
        case staff
    }
}

// MARK: - Service -----------------------------------------------------------

enum TeamInfoService {

    /// Список команд (id, short_name, logo_url) с пагинацией и поиском
    static func list(page: Int = 1,
                     limit: Int = 20,
                     search: String? = nil,
                     year: Int? = nil,
                     token: String?) async throws -> TeamsListResponse {

        var comps = URLComponents(url: API.base.appendingPathComponent("teams"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        if let search, !search.isEmpty {
            comps.queryItems?.append(URLQueryItem(name: "search", value: search))
        }
        if let year {
            comps.queryItems?.append(URLQueryItem(name: "year", value: String(year)))
        }

        var request = URLRequest(url: comps.url!)
        request.httpMethod = "GET"
        if let token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        #if DEBUG
        print("➡️ [Teams] GET", request.url?.absoluteString ?? "")
        #endif

        do {
            let resp = try await API.perform(request: request, decodeAs: TeamsListResponse.self)
            #if DEBUG
            print("✅ [Teams] page \(page):", resp.data.count, "items")
            #endif
            return resp
        } catch {
            #if DEBUG
            print("❌ [Teams] error:", error.localizedDescription)
            #endif
            throw error
        }
    }

    /// Детали команды + игроки + штаб
    static func detail(id: Int, token: String?) async throws -> TeamDetailDTO {
        var request = URLRequest(url: API.base.appendingPathComponent("teams/\(id)"))
        request.httpMethod = "GET"
        if let token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        #if DEBUG
        print("➡️ [Team] GET", request.url?.absoluteString ?? "")
        #endif

        do {
            let dto = try await API.perform(request: request, decodeAs: TeamDetailDTO.self)
            #if DEBUG
            print("✅ [Team] id \(id) loaded")
            #endif
            return dto
        } catch {
            #if DEBUG
            print("❌ [Team] error:", error.localizedDescription)
            #endif
            throw error
        }
    }
}
