import Foundation

// MARK: – Teams / Stadium
struct GameTeamShortDTO: Identifiable, Decodable {
    let id: Int
    let name: String
    let logoURL: String?

    private enum CodingKeys: String, CodingKey {
        case id, name
        case logoURL = "logo_url"
    }
}

// MARK: – Score
struct GameShootoutDTO: Decodable {
    let team1: Int?
    let team2: Int?
}

struct GameScoreDTO: Decodable {
    let team1: Int
    let team2: Int
    let shootout: GameShootoutDTO?
}

// MARK: – Events
struct GameEventDTO: Identifiable, Decodable {

    struct ShortPerson: Identifiable, Decodable {
        let id: Int
        let name: String
    }

    struct PenaltyDTO: Decodable {
        let id: Int
        let name: String
        let minutes: Int?
    }

    struct ViolationDTO: Decodable {
        let id: Int
        let name: String        // «ПОДН»
        let fullName: String?   // «Подножка»

        private enum CodingKeys: String, CodingKey {
            case id, name
            case fullName = "full_name"
        }
    }

    let id: Int
    let typeId: Int            // 2 – гол, 4 – штраф и т. д.
    let type: String           // локализованное название
    let minute: Int?
    let second: Int?
    let period: Int?

    let team: GameTeamShortDTO

    // players / refs (optional)
    let goalAuthor: ShortPerson?
    let assist1: ShortPerson?
    let assist2: ShortPerson?
    let shootoutPlayer: ShortPerson?
    let penaltyPlayer: ShortPerson?

    let penalty: PenaltyDTO?
    let violation: ViolationDTO?

    private enum CodingKeys: String, CodingKey {
        case id
        case typeId        = "type_id"
        case type
        case minute, second, period
        case team

        case goalAuthor    = "goal_author"
        case assist1
        case assist2
        case shootoutPlayer = "shootout_player"
        case penaltyPlayer  = "penalty_player"

        case penalty, violation
    }
}

// MARK: – Root DTO
struct GameDetailDTO: Decodable {
    let id: Int
    let dateStart: String           // ISO-8601, парсим в UI
    let status: Int                 // 0 – запланирован, 1 – идёт, 2 – завершён
    let score: GameScoreDTO
    let technicalDefeat: Bool
    let broadcast: String?
    let broadcastAlt: String?

    let team1: GameTeamShortDTO
    let team2: GameTeamShortDTO
    let stadium: StadiumShortDTO?
    let events: [GameEventDTO]

    private enum CodingKeys: String, CodingKey {
        case id
        case dateStart       = "date_start"
        case status, score
        case technicalDefeat = "technical_defeat"
        case broadcast
        case broadcastAlt    = "broadcast_alt"
        case team1, team2
        case stadium, events
    }
}

// MARK: – Network service
enum GameInfoService {

    /// GET `/games/{id}` – full match information
    /// - Parameters:
    ///   - id: game identifier
    ///   - token: JWT (optional, if backend needs auth)
    static func detail(id: Int,
                       token: String?) async throws -> GameDetailDTO {

        var request = URLRequest(
            url: API.base.appendingPathComponent("games/\(id)")
        )
        request.httpMethod = "GET"
        if let token, !token.isEmpty {
            request.setValue("Bearer \(token)",
                             forHTTPHeaderField: "Authorization")
        }

        #if DEBUG
        print("➡️ [Game] GET \(request.url?.absoluteString ?? "")")
        #endif

        do {
            let dto = try await API.perform(request: request,
                                            decodeAs: GameDetailDTO.self)
            #if DEBUG
            print("✅ [Game] #\(id) loaded with \(dto.events.count) events")
            #endif
            return dto
        } catch {
            #if DEBUG
            print("❌ [Game] error:", error.localizedDescription)
            #endif
            throw error
        }
    }
}
