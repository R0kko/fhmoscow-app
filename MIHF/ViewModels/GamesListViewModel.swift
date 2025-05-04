import SwiftUI

struct GameRoute: Hashable {
    let id: Int
}

struct GamesFilter: Equatable {
    var dateFrom: Date?
    var dateTo: Date?
    var stadiumId: Int?
    var teamId: Int?
    var status: Int?
}

@MainActor
final class GamesListViewModel: ObservableObject {

    // MARK: - Published
    @Published var games: [GameRowDTO] = []
    @Published var isLoading = false
    @Published var page = 1
    @Published var canLoadMore = true

    /// Активные фильтры
    @Published var filter = GamesFilter()

    // MARK: - Dependencies
    private let appState: AppState

    // MARK: - Init
    init(appState: AppState) {
        self.appState = appState
    }

    // MARK: - Public API
    func reload() async {
        page = 1
        games = []
        canLoadMore = true
        await loadNext()
    }

    func apply(filters: GamesFilter) async {
        // Если фильтры реально изменились – перезагружаем
        guard filters != filter else { return }
        filter = filters
        await reload()
    }

    func loadMoreIfNeeded(current item: GameRowDTO?) async {
        guard let item else { await loadFirst(); return }

        let thresholdIndex = games.index(
            games.endIndex,
            offsetBy: -3,
            limitedBy: games.startIndex
        ) ?? games.startIndex

        if games.firstIndex(where: { $0.id == item.id }) == thresholdIndex {
            await loadNext()
        }
    }

    // MARK: - Private helpers
    private func loadFirst() async {
        if games.isEmpty { await loadNext() }
    }

    private func loadNext() async {
        guard !isLoading, canLoadMore, let token = appState.token, !token.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await GamesListService.list(
                dateFrom: filter.dateFrom,
                dateTo: filter.dateTo,
                stadiumId: filter.stadiumId,
                teamId: filter.teamId,
                status: filter.status,
                page: page,
                limit: 20,
                token: token
            )
            games += response.data
            canLoadMore = games.count < response.total
            page += 1
        } catch {
            // На ошибке прекращаем дальнейшую пагинацию
            canLoadMore = false
        }
    }
}
