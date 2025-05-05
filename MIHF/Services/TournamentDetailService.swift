import Foundation

final class TournamentDetailService: TournamentDetailServiceProtocol {
    func load(id: Int, token: String?) async throws -> TournamentDetailDTO {
        var url = API.base
        url.appendPathComponent("/tournaments/\(id)")

        var request = URLRequest(url: url)
        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, _) = try await URLSession.shared.data(for: request)

        #if DEBUG
        if let jsonString = String(data: data, encoding: .utf8) {
            print("🟢 [Tournament] raw JSON:", jsonString)
        }
        #endif

        let decoder = JSONDecoder()
        let isoWithFraction = ISO8601DateFormatter()
        isoWithFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let isoPlain = ISO8601DateFormatter()

        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let d = isoWithFraction.date(from: raw) ?? isoPlain.date(from: raw) {
                return d
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported ISO‑8601 date: \(raw)"
            )
        }

        return try decoder.decode(TournamentDetailDTO.self, from: data)
    }
}
