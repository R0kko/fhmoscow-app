import SwiftUI

@MainActor
final class DocumentListViewModel: ObservableObject {
    @Published private(set) var docs: [DocumentRowDTO] = []
    @Published private(set) var isLoading = false
    @Published private(set) var canLoadMore = true
    @Published private(set) var page = 1
    @Published private(set) var errorMessage: String?

    @Published var categoryId: Int?
    @Published var seasonId: Int?
    @Published var tournamentId: Int?

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
        docs.removeAll(keepingCapacity: true)
        await loadNext()
    }

    func loadMoreIfNeeded(current item: DocumentRowDTO?) async {
        guard let item else { await reload(); return }
        let threshold = docs.index(docs.endIndex,
                                   offsetBy: -3,
                                   limitedBy: docs.startIndex) ?? docs.startIndex
        if docs.firstIndex(where: { $0.id == item.id }) == threshold {
            await loadNext()
        }
    }

    func apply(categoryId: Int?, seasonId: Int?, tournamentId: Int?) async {
        self.categoryId   = categoryId
        self.seasonId     = seasonId
        self.tournamentId = tournamentId
        await reload()
    }

    func updateMeta(for docID: Int,
                    categoryId: Int?,
                    seasonId: Int?) async {
        guard let token = appState.token else { return }
        do {
            try await DocumentService.updateMeta(id: docID,
                                                 categoryId: categoryId,
                                                 seasonId: seasonId,
                                                 token: token)
            if let idx = docs.firstIndex(where: { $0.id == docID }) {
                if let c = categoryId {
                    docs[idx].category = .init(id: c,
                                               name: docs[idx].category?.name ?? "")
                } else {
                    docs[idx].category = nil
                }
                if let s = seasonId {
                    docs[idx].season = .init(id: s,
                                             name: docs[idx].season?.name ?? "")
                } else {
                    docs[idx].season = nil
                }
            }
        } catch {
            errorMessage = "Не удалось обновить данные документа"
        }
    }

    private func loadNext() async {
        guard !isLoading,
              canLoadMore else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let resp = try await DocumentService.list(
                categoryId: categoryId,
                seasonId: seasonId,
                tournamentId: tournamentId,
                page: page,
                limit: pageLimit,
                token: appState.token
            )
            docs += resp.data
            canLoadMore = docs.count < resp.total
            page += 1
        } catch {
            errorMessage = "Не удалось загрузить документы"
            canLoadMore = false
        }
    }
}
