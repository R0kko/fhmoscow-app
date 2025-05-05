import SwiftUI

@MainActor
final class ClubDetailViewModel: ObservableObject {
    // MARK: - Published UI state
    @Published var detail: ClubDetailDTO?
    @Published var isLoading = false
    @Published var error: String?

    // MARK: - Dependencies
    private unowned let appState: AppState
    private let clubId: Int

    // MARK: - Init
    init(clubId: Int, appState: AppState) {
        self.clubId = clubId
        self.appState = appState
    }

    // MARK: - Public API
    func load() async {
        guard !isLoading, let token = appState.token else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            detail = try await ClubsService.detail(id: clubId, token: token)
        } catch {
            self.error = "Не удалось загрузить данные клуба"
        }
    }
}
