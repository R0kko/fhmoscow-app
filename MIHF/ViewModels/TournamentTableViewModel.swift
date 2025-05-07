import SwiftUI

@MainActor
final class TournamentTableViewModel: ObservableObject {

    // MARK: - Published UI state
    @Published var rows: [TableRowDTO] = []
    @Published var isLoading = false
    @Published var page = 1
    @Published var canLoadMore = true

    private let pageLimit = 20

    // MARK: - Dependencies
    private unowned let appState: AppState
    private let groupId: Int
    private var moscowStanding: Bool
    private let service: TableService.Type

    // MARK: - Init
    init(groupId: Int,
         moscowStanding: Bool,
         appState: AppState,
         service: TableService.Type = TableService.self)
    {
        self.groupId = groupId
        self.moscowStanding = moscowStanding
        self.appState = appState
        self.service = service
    }

    /// Первая загрузка / pull-to-refresh
    func reload() async {
        rows.removeAll()
        page = 1
        canLoadMore = true
        await loadNext()
    }

    func loadMoreIfNeeded(current item: TableRowDTO?) async {
        guard let item else { await loadNext(); return }

        let threshold = rows.index(
            rows.endIndex,
            offsetBy: -3,
            limitedBy: rows.startIndex
        ) ?? rows.startIndex

        if rows.firstIndex(where: { $0.id == item.id }) == threshold {
            await loadNext()
        }
    }

    func updateStanding(isMoscow: Bool) async {
        guard moscowStanding != isMoscow else { return }
        moscowStanding = isMoscow
        await reload()
    }

    // MARK: - Private helpers ----------------------------------------------

    private func loadNext() async {
        guard !isLoading,
              canLoadMore,
              let token = appState.token,
              !token.isEmpty
        else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await service.list(
                groupId: groupId,
                moscowStanding: moscowStanding,
                page: page,
                limit: pageLimit,
                token: token
            )

            rows += response.data
            rows.sort {
                if $0.score == $1.score {
                    return $0.position < $1.position
                }
                return $0.score > $1.score
            }

            canLoadMore = rows.count < response.total
            page += 1
        } catch {
            canLoadMore = false
            // TODO: показать алерт
        }
    }
}
