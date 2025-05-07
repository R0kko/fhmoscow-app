import SwiftUI
import Combine

/// View‑model for `PlayerDetailView`
@MainActor
final class PlayerViewModel: ObservableObject {

    // MARK: – Published state
    @Published private(set) var player: PlayerDetailDTO?
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?

    @Published private(set) var games: [GameRowDTO] = []
    @Published private(set) var gamesTotal = 0
    @Published private(set) var gamesPage  = 1
    private let gamesLimit = 20
    @Published private(set) var isLoadingGames = false

    // MARK: – Dependencies
    private let playerID: Int
    private let appState: AppState
    private let service: (Int, String?) async throws -> PlayerDetailDTO
    private let gamesService: (Int, Int, Int, String?) async throws -> GamesListResponse

    init(playerID: Int,
         appState: AppState,
         service:  @escaping (Int, String?) async throws -> PlayerDetailDTO  = PlayerInfoService.detail,
         gamesService: @escaping (Int, Int, Int, String?) async throws -> GamesListResponse = PlayerInfoService.games) {
        self.playerID = playerID
        self.appState = appState
        self.service = service
        self.gamesService = gamesService
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let dto = try await service(playerID, appState.token)
            self.player = dto
            self.error  = nil
            await loadGames(reset: true)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadGames(reset: Bool = false) async {
        guard !isLoadingGames else { return }
        if reset {
            games = []
            gamesPage = 1
        }
        isLoadingGames = true
        defer { isLoadingGames = false }

        do {
            let resp = try await gamesService(playerID, gamesPage, gamesLimit, appState.token)
            if reset {
                games = resp.data
            } else {
                games.append(contentsOf: resp.data)
            }
            gamesTotal = resp.total
            gamesPage += 1
        } catch {
            print("⚠️ Player games loading error:", error.localizedDescription)
        }
    }

    /// Prefetch next page when the user scrolls near the end
    func loadMoreIfNeeded(current item: GameRowDTO) async {
        guard !isLoadingGames,
              games.count < gamesTotal       // still have pages
        else { return }

        // if current item is within last 5 elements → fetch next page
        if let index = games.firstIndex(where: { $0.id == item.id }),
           index >= games.count - 5 {
            await loadGames()
        }
    }

    var fullName: String {
        guard let p = player else { return "" }
        return [p.surname, p.name, p.patronymic]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    var birthday: String? {
        guard let iso = player?.dateOfBirth,
              let date = Self.isoParser.date(from: iso)
        else { return nil }
        return Self.displayFormatter.string(from: date)
    }

    private static let isoParser: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        f.dateFormat = "d MMMM yyyy" 
        return f
    }()
}
