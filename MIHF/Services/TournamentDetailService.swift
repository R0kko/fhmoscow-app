//
//  TournamentDetailService.swift
//  MIHF
//
//  Created by Alexey Drobot on 02.05.2025.
//

import Foundation

/// Ответ детального турнира (можно расширить, если API вернёт больше полей)
struct TournamentDetailResponse: Decodable {
    let data: TournamentDetailDTO
}

/// Сервис работы с детальной информацией о турнире
enum TournamentDetailService {

    /// Загрузить детальную информацию по id турнира
    /// - Parameters:
    ///   - id: идентификатор турнира
    ///   - token: JWT token из `AppState.token`
    static func get(id: Int, token: String) async throws -> TournamentDetailDTO {
        let url = API.base.appendingPathComponent("/tournaments/\(id)")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let response: TournamentDetailResponse = try await API.perform(request: request, decodeAs: TournamentDetailResponse.self)
        return response.data
    }
}
