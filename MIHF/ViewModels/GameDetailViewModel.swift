import Foundation
import SwiftUI

/// View‑model for `GameDetailView`
@MainActor
final class GameDetailViewModel: ObservableObject {

    // MARK: – Public observable state
    @Published private(set) var detail: GameDetailDTO?
    @Published private(set) var filteredEvents: [GameEventDTO] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?

    // MARK: – Dependencies
    private let gameID: Int
    private let appState: AppState
    private let service: (Int, String?) async throws -> GameDetailDTO

    // MARK: – Init
    init(gameID: Int,
         appState: AppState,
         service: @escaping (Int, String?) async throws -> GameDetailDTO = GameInfoService.detail) {
        self.gameID = gameID
        self.appState = appState
        self.service = service
    }

    // MARK: – Intent
    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let dto = try await service(gameID, appState.token)
            detail = dto

            let hiddenTypes: Set<Int> = [1, 3, 5, 6, 7]

            filteredEvents = dto.events
                .compactMap { event in
                    guard !hiddenTypes.contains(event.typeId) else { return nil }
                    if event.typeId == 8 {
                        var copy = event
                        return copy
                    }
                    return event
                }
                .sorted {
                    // sort by minute, then second
                    if let m1 = $0.minute, let m2 = $1.minute, m1 != m2 {
                        return m1 < m2
                    }
                    return ($0.second ?? 0) < ($1.second ?? 0)
                }

            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: – Helpers
    /// Converts ISO‑8601 `date_start` into `Date`
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

