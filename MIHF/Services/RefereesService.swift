import Foundation

// MARK: - Сервис

enum RefereesService {

    // MARK: 1. Список назначений

    /// Список матчей, назначенных текущему судье.
    ///
    /// GET `/referees/games?page={page}&limit={limit}`
    ///
    /// - Parameters:
    ///   - page:  номер страницы (по умолчанию — 1)
    ///   - limit: количество элементов на страницу (по умолчанию — 20)
    ///   - token: JWT; _обязателен_, иначе сервер вернёт 401
    @discardableResult
    static func games(page: Int = 1,
                      limit: Int = 20,
                      token: String) async throws -> GamesListResponse {

        var comps = URLComponents(url: API.base.appendingPathComponent("referees/games"),
                                  resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            URLQueryItem(name: "page",  value: String(page)),
            URLQueryItem(name: "limit", value: String(limit))
        ]

        var request = URLRequest(url: comps.url!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        #if DEBUG
        print("➡️ [Referee] GET \(request.url?.absoluteString ?? "")")
        #endif

        do {
            let resp = try await API.perform(request: request,
                                             decodeAs: GamesListResponse.self)
            #if DEBUG
            print("✅ [Referee] page \(page): \(resp.data.count) items")
            #endif
            return resp
        } catch {
            #if DEBUG
            print("❌ [Referee] error:", error.localizedDescription)
            #endif
            throw error
        }
    }

    // MARK: - Internal helpers
    /// Выполнить запрос, где сервер отвечает 204 (No Content).
    /// Считаем успехом любой статус‑код 2xx; иначе бросаем ошибку.
    private static func performExpectingNoContent(_ request: URLRequest) async throws {
        let (_, resp) = try await URLSession.shared.data(for: request)
        guard let http = resp as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "API", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "Server error \(http.statusCode)"])
        }
    }

    // MARK: 2. Подтвердить назначение

    /// PATCH `/referees/games/{gameId}/confirm`
    ///
    /// - Parameters:
    ///   - gameId: id игры
    ///   - token:  JWT – текущий пользователь должен иметь роль судьи
    static func confirm(gameId: Int,
                        token: String) async throws {

        let url = API.base
            .appendingPathComponent("referees/games/\(gameId)/confirm")

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        #if DEBUG
        print("➡️ [Referee] PATCH \(url.path) — confirm")
        #endif

        do {
            try await performExpectingNoContent(request)
            #if DEBUG
            print("✅ [Referee] game \(gameId) confirmed (204)")
            #endif
        } catch {
            #if DEBUG
            print("❌ [Referee] confirm error:", error.localizedDescription)
            #endif
            throw error
        }
    }

    // MARK: 3. Отозвать подтверждение

    /// PATCH `/referees/games/{gameId}/unconfirm`
    ///
    /// - Parameters:
    ///   - gameId: id игры
    ///   - token:  JWT
    static func unconfirm(gameId: Int,
                          token: String) async throws {

        let url = API.base
            .appendingPathComponent("referees/games/\(gameId)/unconfirm")

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        #if DEBUG
        print("➡️ [Referee] PATCH \(url.path) — unconfirm")
        #endif

        do {
            try await performExpectingNoContent(request)
            #if DEBUG
            print("✅ [Referee] game \(gameId) unconfirmed (204)")
            #endif
        } catch {
            #if DEBUG
            print("❌ [Referee] unconfirm error:", error.localizedDescription)
            #endif
            throw error
        }
    }
}

// MARK: - Вспомогательные типы

private struct EmptyDTO: Decodable {}
