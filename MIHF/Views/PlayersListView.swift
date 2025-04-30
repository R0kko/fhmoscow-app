import SwiftUICore
import SwiftUI

struct PlayerRowDTO: Identifiable, Decodable {
    let id: Int
    let surname: String
    let name: String
    let patronymic: String?
    let dateOfBirth: String?
    let photo: String?

    enum CodingKeys: String, CodingKey {
        case id, surname, name, patronymic, photo
        case dateOfBirth = "date_of_birth"
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    var fio: String { [surname, name, patronymic].compactMap { $0 }.joined(separator: " ") }
    var birthFormatted: String {
        guard let iso = dateOfBirth, let date = Self.isoFormatter.date(from: iso) else { return "" }
        let df = DateFormatter()
        df.locale = Locale(identifier: "ru_RU")
        df.dateFormat = "dd.MM.yyyy"
        return df.string(from: date)
    }
}

struct PlayersListView: View {
    @EnvironmentObject private var appState: AppState
    @State private var query: String = ""
    @State private var players: [PlayerRowDTO] = []
    @State private var page = 1
    @State private var total = 0
    private let limit = 20
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            playersList
            .navigationTitle("Игроки")
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
            .onSubmit(of: .search) { Task { await fetchPlayers() } }
            .refreshable { await fetchPlayers() }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isLoading { ProgressView() }
                }
            }
            .alert("Ошибка", isPresented: .constant(error != nil), actions: {
                Button("OK") { error = nil }
            }, message: { Text(error ?? "") })
            .navigationDestination(for: Int.self) { id in
                Text("Player #\(id)") // TODO: PlayerDetailView
            }
        }
        .task { await fetchPlayers() }
    }

    private var loadingRow: some View {
        HStack {
            Spacer(); ProgressView(); Spacer()
        }
    }

    @MainActor private func fetchPlayers() async {
        guard let token = appState.token else { error = "Сессия истекла"; return }
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await PlayersListService.search(query: query, page: 1, token: token)
            self.players = result.data
            self.page = result.page
            self.total = result.total
        } catch {
            self.error = "Не удалось загрузить список игроков"
        }
    }

    @MainActor private func loadMore() async {
        guard !isLoading, players.count < total else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let next = page + 1
            guard let token = appState.token else { return }
            let result = try await PlayersListService.search(query: query, page: next, token: token)
            self.players += result.data
            self.page = next
            self.total = result.total
        } catch {
            // swallow pagination errors silently
        }
    }

    // MARK: - Sub‑Views
    @ViewBuilder private var playersList: some View {
        List {
            if isLoading && players.isEmpty {
                loadingRow
            }
            ForEach(players) { player in
                NavigationLink(value: player.id) {
                    PlayerRowView(player: player)
                }
                .task {
                    if player.id == players.last?.id && players.count < total && !isLoading {
                        await loadMore()
                    }
                }
            }
        }
    }
}

// MARK: - DTO & Response

struct PlayersListResponse: Decodable {
    let data: [PlayerRowDTO]
    let page: Int
    let total: Int
}

extension AppState {
    static var preview: AppState {
        let mock = AppState()
        return mock
    }
}

// MARK: - Preview

#Preview {
    PlayersListView()
        .environmentObject(AppState.preview)
}

struct PlayerRowView: View {
    let player: PlayerRowDTO

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: player.photo ?? "")) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                default:
                    Image(systemName: "person.crop.circle.fill")
                        .resizable().scaledToFill()
                        .foregroundColor(.gray.opacity(0.6))
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(player.fio)
                    .font(.body)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if !player.birthFormatted.isEmpty {
                    Text(player.birthFormatted)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
