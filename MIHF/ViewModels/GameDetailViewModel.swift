import Foundation
import SwiftUI

private extension GameLineupDTO {
    /// Returns a copy with `players` sorted by jersey number (nil at the end).
    func sortedByNumber() -> GameLineupDTO {
        let sortedPlayers = players.sorted {
            ($0.number ?? Int.max) < ($1.number ?? Int.max)
        }
        return GameLineupDTO(shortName: shortName,
                             players: sortedPlayers,
                             staff: staff, logoURL: logoURL)
    }
}

/// View‑model for `GameDetailView`
@MainActor
final class GameDetailViewModel: ObservableObject {

    // MARK: – Public observable state
    @Published private(set) var detail: GameDetailDTO?
    @Published private(set) var filteredEvents: [GameEventDTO] = []
    @Published private(set) var lineupTeam1: GameLineupDTO?
    @Published private(set) var lineupTeam2: GameLineupDTO?
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?
    @Published private(set) var referees: [RefereeRowDTO] = []

    // MARK: – Dependencies
    private let gameID: Int
    private let appState: AppState
    private let service: (Int, String?) async throws -> GameDetailDTO
    private let lineupService: (Int, String?) async throws -> GameLineupsResponse
    private let refereesService: (Int, String) async throws -> [RefereeRowDTO]

    // MARK: – Init
    init(gameID: Int,
         appState: AppState,
         service:        @escaping (Int, String?) async throws -> GameDetailDTO        = GameInfoService.detail,
         lineupService:  @escaping (Int, String?) async throws -> GameLineupsResponse = GameInfoService.lineups,
         refereesService:@escaping (Int, String)  async throws -> [RefereeRowDTO]     = RefereesService.refereesForGame) {

        self.gameID        = gameID
        self.appState      = appState
        self.service       = service
        self.lineupService = lineupService
        self.refereesService = refereesService
    }

    // MARK: – Intent
    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let dto = try await service(gameID, appState.token)
            detail = dto
            lineupTeam1 = dto.lineupTeam1?.sortedByNumber()
            lineupTeam2 = dto.lineupTeam2?.sortedByNumber()

            // Если составы не пришли вместе с деталями — запрашиваем отдельно
            if lineupTeam1 == nil || lineupTeam2 == nil {
                do {
                    let rosters = try await lineupService(gameID, appState.token)
                    lineupTeam1 = rosters.lineupTeam1.sortedByNumber()
                    lineupTeam2 = rosters.lineupTeam2.sortedByNumber()
                } catch {
                    #if DEBUG
                    print("⚠️ [Game] line‑ups load error:", error.localizedDescription)
                    #endif
                }
            }

            let hiddenTypes: Set<Int> = [1, 3, 5, 6, 7]

            filteredEvents = dto.events
                .compactMap { event in
                    guard !hiddenTypes.contains(event.typeId) else { return nil }
                    if event.typeId == 8 {
                        let copy = event
                        return copy
                    }
                    return event
                }
                .sorted {
                    if let m1 = $0.minute, let m2 = $1.minute, m1 != m2 {
                        return m1 < m2
                    }
                    return ($0.second ?? 0) < ($1.second ?? 0)
                }

            if let token = appState.token {
                do {
                    referees = try await refereesService(gameID, token)
                } catch {
                    #if DEBUG
                    print("⚠️ [Game] referees load error:", error.localizedDescription)
                    #endif
                }
            }

            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: – Helpers
    var startDate: Date? {
        guard let iso = detail?.dateStart else { return nil }
        return Self.isoParser.date(from: iso)
    }

    static let isoParser: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}
