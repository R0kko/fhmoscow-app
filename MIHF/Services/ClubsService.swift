import Foundation


/// Короткая карточка клуба (для списков)
struct ClubRowDTO: Identifiable, Decodable {
    let id: Int
    let shortName: String
    let logo: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case shortName = "short_name"
        case logo
    }
}

/// Ответ `/clubs` со списком (пагинация)
struct ClubsListResponse: Decodable {
    let data: [ClubRowDTO]
    let total: Int
    let page: Int
    let limit: Int
}

/// Детальная карточка клуба
struct ClubDetailDTO: Decodable {
    struct Team: Identifiable, Decodable {
        let id: Int
        let shortName: String
        let fullName: String?
        let year: Int?
        let logoUrl: String?

        private enum CodingKeys: String, CodingKey {
            case id
            case shortName = "short_name"
            case fullName  = "full_name"
            case year
            case logoUrl   = "logo_url"
        }
    }

    let id: Int
    let fullName: String?
    let shortName: String?
    let description: String?
    let site: String?
    let isMoscow: Bool
    let logoUrl: String?
    let teams: [Team]

    private enum CodingKeys: String, CodingKey {
        case id
        case fullName  = "full_name"
        case shortName = "short_name"
        case description, site
        case isMoscow  = "is_moscow"
        case logoUrl   = "logo_url"
        case teams
    }
}

// MARK: - Service -----------------------------------------------------------

enum ClubsService {

    /// Список клубов
    ///
    /// - Parameters:
    ///   - page:   номер страницы (1‑based, default 1)
    ///   - limit:  элементов (default 20)
    ///   - search: поиск по названию
    ///   - isMoscow: фильтр по московским клубам
    ///   - token:  JWT (`AppState.token`)
    static func list(page: Int = 1,
                     limit: Int = 20,
                     search: String? = nil,
                     isMoscow: Bool? = nil,
                     token: String?) async throws -> ClubsListResponse {

        var comps = URLComponents(url: API.base.appendingPathComponent("clubs"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        if let search, !search.isEmpty {
            comps.queryItems?.append(URLQueryItem(name: "search", value: search))
        }
        if let isMoscow {
            comps.queryItems?.append(URLQueryItem(name: "isMoscow", value: isMoscow ? "true" : "false"))
        }

        var request = URLRequest(url: comps.url!)
        request.httpMethod = "GET"
        if let token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        #if DEBUG
        print("➡️ [Clubs] GET", request.url?.absoluteString ?? "")
        #endif

        do {
            let resp = try await API.perform(request: request, decodeAs: ClubsListResponse.self)
            #if DEBUG
            print("✅ [Clubs] page \(page):", resp.data.count, "items")
            #endif
            return resp
        } catch {
            #if DEBUG
            print("❌ [Clubs] error:", error.localizedDescription)
            #endif
            throw error
        }
    }

    /// Детали клуба
    static func detail(id: Int, token: String?) async throws -> ClubDetailDTO {
        var request = URLRequest(url: API.base.appendingPathComponent("clubs/\(id)"))
        request.httpMethod = "GET"
        if let token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        #if DEBUG
        print("➡️ [Club] GET", request.url?.absoluteString ?? "")
        #endif

        do {
            let dto = try await API.perform(request: request, decodeAs: ClubDetailDTO.self)
            #if DEBUG
            print("✅ [Club] id \(id) loaded")
            #endif
            return dto
        } catch {
            #if DEBUG
            print("❌ [Club] error:", error.localizedDescription)
            #endif
            throw error
        }
    }
}
