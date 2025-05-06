import SwiftUI
import Foundation

// MARK: - View-model назначений судьи
@MainActor
final class RefereeGamesViewModel: ObservableObject {

    // MARK: Public reactive state
    @Published var games: [GameRowDTO] = []
    @Published var isLoading = false
    @Published var canLoadMore = true
    @Published var page = 1
    @Published var alertMessage: String?

    // MARK: Private
    private unowned let appState: AppState
    private let pageLimit = 20

    init(appState: AppState) {
        self.appState = appState
    }


    func reload() async {
        guard !isLoading else { return }
        page = 1
        canLoadMore = true
        games.removeAll(keepingCapacity: true)
        await loadNext()
    }

    func loadMoreIfNeeded(current item: GameRowDTO?) async {
        guard let item else { await reload(); return }
        let threshold = games.index(games.endIndex,
                                    offsetBy: -3,
                                    limitedBy: games.startIndex) ?? games.startIndex
        if games.firstIndex(where: { $0.id == item.id }) == threshold {
            await loadNext()
        }
    }

    func confirm(gameId: Int) async {
        await setConfirmation(gameId: gameId, confirm: true)
    }

    func unconfirm(gameId: Int) async {
        await setConfirmation(gameId: gameId, confirm: false)
    }

    private func loadNext() async {
        guard !isLoading,
              canLoadMore,
              let token = appState.token,
              !token.isEmpty else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let resp = try await RefereesService.games(
                page: page,
                limit: pageLimit,
                token: token
            )
            games += resp.data
            games.sort { $0.date_start > $1.date_start }
            canLoadMore = games.count < resp.total
            page += 1
        } catch {
            alertMessage = "Не удалось загрузить список матчей"
            canLoadMore = false
        }
    }

    private func setConfirmation(gameId: Int, confirm: Bool) async {
        guard let token = appState.token else { return }
        do {
            if confirm {
                try await RefereesService.confirm(gameId: gameId, token: token)
            } else {
                try await RefereesService.unconfirm(gameId: gameId, token: token)
            }
            await reload()
        } catch {
            alertMessage = confirm ? "Не удалось подтвердить матч"
                                   : "Не удалось отозвать подтверждение"
        }
    }
}
