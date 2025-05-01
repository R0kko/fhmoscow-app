import SwiftUI

// MARK: - DTO (comes from API)
struct TournamentRowDTO: Identifiable, Decodable {
    let id: Int
    let full_name: String
    let short_name: String
    let logo: String?
    let year_of_birth: Int
    let type: String
    let season: String
}

// MARK: - View Model
@MainActor
final class TournamentListViewModel: ObservableObject {
    @Published var tournaments: [TournamentRowDTO] = []
    @Published var isLoading = false
    @Published var page = 1
    @Published var canLoadMore = true

    let appState: AppState   // internal so View can read

    init(appState: AppState) { self.appState = appState }

    func loadMoreIfNeeded(current item: TournamentRowDTO?) async {
        guard let item = item else { await loadFirst(); return }
        // Вычисляем индекс порога безопасно (если элементов < 3)
        let thresholdIndex = tournaments.index(
            tournaments.endIndex,
            offsetBy: -3,
            limitedBy: tournaments.startIndex
        ) ?? tournaments.startIndex

        if tournaments.firstIndex(where: { $0.id == item.id }) == thresholdIndex {
            await loadNext()
        }
    }

    func reload() async { page = 1; tournaments = []; canLoadMore = true; await loadNext() }

    private func loadFirst() async { if tournaments.isEmpty { await loadNext() } }

    private func loadNext() async {
        guard !isLoading, canLoadMore, let token = appState.token, !token.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await TournamentListService.list(
                page: page,
                limit: 20,
                token: token
            )
            tournaments += response.data
            canLoadMore = tournaments.count < response.total
            page += 1
        } catch {
            // TODO: handle error (e.g. show alert)
            canLoadMore = false
        }
    }
}

// MARK: - View
struct TournamentListView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var vm: TournamentListViewModel

    /// Инициализатор, который получает актуальный `AppState` от родительского экрана
    init(appState: AppState) {
        _vm = StateObject(wrappedValue: TournamentListViewModel(appState: appState))
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(vm.tournaments) { tournament in
                    TournamentRowView(tournament: tournament)
                        .task {
                            await vm.loadMoreIfNeeded(current: tournament)
                        }
                }
                if vm.isLoading {
                    HStack { Spacer(); ProgressView(); Spacer() }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Турниры")
            .refreshable { await vm.reload() }
            .task { await vm.loadMoreIfNeeded(current: nil) }
        }
    }
}

// MARK: - Row View
struct TournamentRowView: View {
    let tournament: TournamentRowDTO

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AsyncImage(url: URL(string: tournament.logo ?? "")) { phase in
                switch phase {
                case .success(let image): image.resizable()
                case .failure(_): Image(systemName: "sportscourt.fill").resizable()
                default: ProgressView()
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(tournament.short_name)
                    .font(.headline)
                    .lineLimit(1)
                Text("Год рождения: \(tournament.year_of_birth)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("Сезон \(tournament.season)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(tournament.type)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}
