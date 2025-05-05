import SwiftUI

@MainActor
final class GroupViewModel: ObservableObject {

    // MARK: - Published UI state
    @Published var groups: [GroupRowDTO] = []
    @Published var isLoading = false
    @Published var canLoadMore = true
    @Published var page = 1

    // MARK: - Dependencies
    private unowned let appState: AppState
    private let stageId: Int
    private let service: GroupService.Type

    // MARK: - Init
    init(stageId: Int,
         appState: AppState,
         service: GroupService.Type = GroupService.self) {
        self.stageId = stageId
        self.appState = appState
        self.service = service
    }

    // MARK: - Public API
    /// Первый запуск / Pull‑to‑refresh
    func reload() async {
        groups.removeAll()
        page = 1
        canLoadMore = true
        await loadNext()
    }

    func loadMoreIfNeeded(current item: GroupRowDTO?) async {
        guard let item else { await loadNext(); return }
        let threshold = groups.index(
            groups.endIndex,
            offsetBy: -3,
            limitedBy: groups.startIndex
        ) ?? groups.startIndex

        if groups.firstIndex(where: { $0.id == item.id }) == threshold {
            await loadNext()
        }
    }

    // MARK: - Private helpers
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
                stageId: stageId,
                page: page,
                limit: 20,
                token: token
            )
            groups += response.data
            groups.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            canLoadMore = groups.count < response.total
            page += 1
        } catch {
            // TODO: всплывашка / логирование
            canLoadMore = false
        }
    }
}
