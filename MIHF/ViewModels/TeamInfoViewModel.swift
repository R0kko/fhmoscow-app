import SwiftUI

// MARK: - View‑model списка команд
@MainActor
final class TeamListViewModel: ObservableObject {
    @Published var teams: [TeamRowDTO] = []
    @Published var isLoading = false
    @Published var canLoadMore = true
    @Published var page = 1
    @Published var query: String = ""
    @Published var yearFilter: Int?
    

    private unowned let appState: AppState
    private let pageLimit = 20

    init(appState: AppState) { self.appState = appState }

    func reload() async {
        guard !isLoading else { return }
        page = 1
        canLoadMore = true
        teams.removeAll(keepingCapacity: true)
        await loadNext()
    }

    func loadMoreIfNeeded(current item: TeamRowDTO?) async {
        guard let item else { await reload(); return }
        let threshold = teams.index(teams.endIndex,
                                    offsetBy: -3,
                                    limitedBy: teams.startIndex) ?? teams.startIndex
        if teams.firstIndex(where: { $0.id == item.id }) == threshold {
            await loadNext()
        }
    }

    func applyFilters(search: String, year: Int?) async {
        query = search
        yearFilter = year
        await reload()
    }

    // MARK: private
    private func loadNext() async {
        guard !isLoading,
              canLoadMore,
              let token = appState.token,
              !token.isEmpty else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let resp = try await TeamInfoService.list(
                page: page,
                limit: pageLimit,
                search: query.isEmpty ? nil : query,
                year: yearFilter,
                token: token
            )
            teams += resp.data
            canLoadMore = teams.count < resp.total
            page += 1
        } catch {
            canLoadMore = false
        }
    }
}

// MARK: - View‑model детальной команды
@MainActor
final class TeamDetailViewModel: ObservableObject {
    @Published var detail: TeamDetailDTO?
    @Published var isLoading = false
    @Published var error: String?

    private unowned let appState: AppState
    private let teamId: Int

    init(teamId: Int, appState: AppState) {
        self.teamId = teamId
        self.appState = appState
    }

    func load() async {
        guard !isLoading, let token = appState.token else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            detail = try await TeamInfoService.detail(id: teamId, token: token)
        } catch {
            self.error = "Не удалось загрузить данные команды"
        }
    }

    var playersSorted: [TeamDetailDTO.Player] {
        guard let detail else { return [] }
        return detail.players.sorted {
            let lhs = $0.number ?? Int.max
            let rhs = $1.number ?? Int.max
            return lhs < rhs
        }
    }

    var playersByPosition: [(key: String, items: [TeamDetailDTO.Player])] {
        Dictionary(grouping: playersSorted, by: { $0.position ?? "—" })
            .map { ($0.key, $0.value) }
            .sorted { $0.key < $1.key }
    }
}
