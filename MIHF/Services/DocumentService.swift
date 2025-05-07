import Foundation

struct DocumentRowDTO: Identifiable, Hashable, Decodable {
    let id: Int
    let name: String?
    let url: String
    var category: Nested?
    var season: Nested?
    let tournament: Nested?
    
    struct Nested: Hashable, Decodable {
        let id: Int
        let name: String
    }
}

enum DocumentService {

    // MARK: 1. Список документов

    /// GET `/documents`
    ///
    /// Фильтры:
    /// * categoryId
    /// * seasonId
    /// * tournamentId
    ///
    /// + pagination.
    static func list(categoryId: Int? = nil,
                     seasonId: Int? = nil,
                     tournamentId: Int? = nil,
                     page: Int = 1,
                     limit: Int = 20,
                     token: String?) async throws -> PagedResponse<DocumentRowDTO> {

        var comps = URLComponents(url: API.base.appendingPathComponent("documents"),
                                  resolvingAgainstBaseURL: false)!

        var items: [URLQueryItem] = [
            .init(name: "page",  value: String(page)),
            .init(name: "limit", value: String(limit))
        ]
        if let c = categoryId    { items.append(.init(name: "categoryId",   value: String(c))) }
        if let s = seasonId      { items.append(.init(name: "seasonId",     value: String(s))) }
        if let t = tournamentId  { items.append(.init(name: "tournamentId", value: String(t))) }

        comps.queryItems = items

        var request = URLRequest(url: comps.url!)
        request.httpMethod = "GET"
        if let token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        #if DEBUG
        print("➡️ [Doc] GET \(request.url?.absoluteString ?? "")")
        #endif

        do {
            let resp = try await API.perform(request: request,
                                             decodeAs: PagedResponse<DocumentRowDTO>.self)
            #if DEBUG
            print("✅ [Doc] list page \(page): \(resp.data.count) items")
            #endif
            return resp
        } catch {
            #if DEBUG
            print("❌ [Doc] list error:", error.localizedDescription)
            #endif
            throw error
        }
    }

    /// PATCH `/documents/{id}`
    ///
    /// Передавайте `nil`, чтобы удалить значение категории/сезона.
    static func updateMeta(id: Int,
                           categoryId: Int?,
                           seasonId: Int?,
                           token: String) async throws {

        let url = API.base.appendingPathComponent("documents/\(id)")

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let body = [
            "categoryId": categoryId as Any?,
            "seasonId":   seasonId   as Any?
        ].compactMapValues { $0 }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        #if DEBUG
        print("➡️ [Doc] PATCH \(url.lastPathComponent) payload:", body)
        #endif

        do {
            try await performExpectingNoContent(request) 
            #if DEBUG
            print("✅ [Doc] meta updated for id \(id)")
            #endif
        } catch {
            #if DEBUG
            print("❌ [Doc] update meta error:", error.localizedDescription)
            #endif
            throw error
        }
    }

    // MARK: – Helper for 204 responses
    private static func performExpectingNoContent(_ request: URLRequest) async throws {
        let (_, resp) = try await URLSession.shared.data(for: request)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}

// MARK: - Общая структура пагинированного ответа
struct PagedResponse<T: Decodable>: Decodable {
    let data: [T]
    let total: Int
    let page: Int
    let limit: Int
}
