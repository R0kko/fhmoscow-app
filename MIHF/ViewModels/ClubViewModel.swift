import SwiftUI

// MARK: - View‑model списка клубов (пагинация + поиск)
@MainActor
final class ClubListViewModel: ObservableObject {

    // MARK: - Published UI state
    @Published var clubs: [ClubRowDTO] = []
    @Published var isLoading = false
    @Published var page = 1
    @Published var canLoadMore = true
    @Published var query: String = ""
    @Published var showOnlyMoscow = false

    // MARK: - Dependencies
    private unowned let appState: AppState
    private let pageLimit = 20

    // MARK: - Init
    init(appState: AppState) { self.appState = appState }

    func reload() async {
        page = 1
        clubs.removeAll()
        canLoadMore = true
        await loadNext()
    }

    func loadMoreIfNeeded(current item: ClubRowDTO?) async {
        guard let item else { await loadNext(); return }

        let threshold = clubs.index(
            clubs.endIndex,
            offsetBy: -3,
            limitedBy: clubs.startIndex
        ) ?? clubs.startIndex

        if clubs.firstIndex(where: { $0.id == item.id }) == threshold {
            await loadNext()
        }
    }

    func applyFilters(search: String, isMoscow: Bool) async {
        query = search
        showOnlyMoscow = isMoscow
        await reload()
    }

    private func loadNext() async {
        guard !isLoading,
              canLoadMore,
              let token = appState.token,
              !token.isEmpty
        else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await ClubsService.list(
                page: page,
                limit: pageLimit,
                search: query.isEmpty ? nil : query,
                isMoscow: showOnlyMoscow ? true : nil,
                token: token
            )
            clubs += response.data
            canLoadMore = clubs.count < response.total
            page += 1
        } catch {
            canLoadMore = false
        }
    }
}
