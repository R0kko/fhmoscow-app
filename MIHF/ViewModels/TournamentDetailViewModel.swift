import SwiftUI

@MainActor
final class TournamentDetailViewModel: ObservableObject {

    // MARK: - Published state
    @Published private(set) var detail: TournamentDetailDTO?
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?

    // MARK: - Dependencies
    private let service: TournamentDetailServiceProtocol
    private let tournamentID: Int
    private unowned let appState: AppState


    // MARK: - Init
    init(
        tournamentID: Int,
        appState: AppState,
        service: TournamentDetailServiceProtocol = TournamentDetailService()
    ) {
        self.tournamentID = tournamentID
        self.appState = appState
        self.service = service
    }

    // MARK: - API
    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let token = appState.token
#if DEBUG
            if token == nil || token?.isEmpty == true {
                print("⚠️ TournamentDetailViewModel: appState.token is nil or empty")
            }
#endif
            detail = try await service.load(id: tournamentID, token: token)
            error = nil
        } catch {
            self.error = parse(error)
            detail = nil
        }
    }

    // MARK: - Helpers
    private func parse(_ error: Error) -> String {
        if let apiError = error as? APIError {
            return apiError.localizedDescription
        }
        return "Не удалось загрузить данные турнира"
    }
}
