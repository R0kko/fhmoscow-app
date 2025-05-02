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

    @Published var seasonFilter: Int?
    @Published var yearFilter: Int?

    @Published var seasons: [SeasonDTO] = []

    let appState: AppState

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

    func applyFilters(season: Int?, year: Int?) async {
        seasonFilter = season
        yearFilter = year
        await reload()
    }

    func loadSeasons() async {
        guard seasons.isEmpty, let token = appState.token else { return }
        do {
            seasons = try await SeasonService.list(token: token)
        } catch {
        }
    }

    private func loadFirst() async { if tournaments.isEmpty { await loadNext() } }

    private func loadNext() async {
        guard !isLoading, canLoadMore, let token = appState.token, !token.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await TournamentListService.list(
                seasonId: seasonFilter,
                yearOfBirth: yearFilter,
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
/// Уникальный тип ссылки, чтобы не конфликтовать с другими `.navigationDestination(for: Int.self)`
private struct TournamentRoute: Hashable {
    let id: Int
}
struct TournamentListView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var vm: TournamentListViewModel
    
    @State private var showFilter = false
    @State private var tempSeason: String = ""
    @State private var tempYear: String = ""
    @State private var showYearError = false
    
    /// Инициализатор, который получает актуальный `AppState` от родительского экрана
    init(appState: AppState) {
        _vm = StateObject(wrappedValue: TournamentListViewModel(appState: appState))
    }
    
    /// Трансформируем в массив, чтобы порядок секций был стабильным и избежать пустых секций
    private var grouped: [(key: String, items: [TournamentRowDTO])] {
        Dictionary(grouping: vm.tournaments, by: \.type)
            .map { ($0.key, $0.value) }
            .sorted { $0.key < $1.key }
    }
    
    var body: some View {
        List {
            ForEach(grouped, id: \.key) { entry in
                if !entry.items.isEmpty {
                    Section(header: Text(entry.key)) {
                        ForEach(entry.items) { tournament in
                            NavigationLink(value: TournamentRoute(id: tournament.id)) {
                                TournamentRowView(tournament: tournament)
                            }
                            .onAppear {
                                Task { await vm.loadMoreIfNeeded(current: tournament) }
                            }
                        }
                    }
                }
            }
            
            if vm.isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .listRowSeparator(.hidden)
            } else if vm.tournaments.isEmpty {
                ContentUnavailableView("Нет турниров", systemImage: "trophy")
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .navigationTitle("Турниры")
        .navigationDestination(for: TournamentRoute.self) { route in
            TournamentDetailView(tournamentId: route.id, appState: appState)
        }
        .refreshable { await vm.reload() }
        .task { await vm.reload() }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task { await vm.loadSeasons() }
                    tempSeason = vm.seasonFilter.map(String.init) ?? ""
                    tempYear = vm.yearFilter.map(String.init) ?? ""
                    showFilter = true
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .sheet(isPresented: $showFilter) {
            NavigationStack {
                Form {
                    Section("Сезон") {
                        Picker("Сезон", selection: $tempSeason) {
                            Text("Все").tag("")
                            ForEach(vm.seasons) { season in
                                Text(season.name).tag(String(season.id))
                            }
                        }
                    }
                    Section("Год рождения") {
                        TextField("Например, 2015", text: $tempYear)
                            .keyboardType(.numberPad)
                            .submitLabel(.done)
                    }
                }
                .navigationTitle("Фильтр")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Отмена") { showFilter = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Применить") {
                            let trimmed = tempYear.trimmingCharacters(in: .whitespaces)
                            if !trimmed.isEmpty {
                                if let y = Int(trimmed), (2000...2016).contains(y) {
                                    showFilter = false
                                    Task { await vm.applyFilters(season: Int(tempSeason), year: y) }
                                } else {
                                    showYearError = true
                                }
                            } else {
                                // год не задан – разрешаем
                                showFilter = false
                                Task { await vm.applyFilters(season: Int(tempSeason), year: nil) }
                            }
                        }
                    }
                }
            }
            .alert("Неверный год", isPresented: $showYearError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Введите год от 2000 до 2016.")
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
                    Text("Год рождения: \(String(tournament.year_of_birth))")
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
}
