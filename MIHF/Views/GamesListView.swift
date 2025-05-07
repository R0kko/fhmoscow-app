import SwiftUI

struct GamesListView: View {

    // MARK: – Dependencies
    @EnvironmentObject private var appState: AppState
    @StateObject private var vm: GamesListViewModel

    // MARK: – UI State
    @State private var showFilterSheet = false
    @State private var tempFilter = GamesFilter()
    @State private var teams: [TeamRowDTO] = []

    // MARK: – Init
    init(appState: AppState) {
        _vm = StateObject(wrappedValue: GamesListViewModel(appState: appState))
    }

    // MARK: – Body
    var body: some View {
        List {
            ForEach(vm.games) { game in
                NavigationLink(value: GameRoute(id: game.id)) {
                    GameCard(game: game)
                        .onAppear {
                            Task { await vm.loadMoreIfNeeded(current: game) }
                        }
                }
                .listRowSeparator(.hidden)
                .padding(.vertical, 4)
            }

            if vm.isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .listRowSeparator(.hidden)
            }
            else if vm.games.isEmpty {
                ContentUnavailableView("Нет игр", systemImage: "sportscourt")
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .navigationTitle("Матчи")
        .navigationDestination(for: GameRoute.self) { route in
            GameDetailView(gameId: route.id, appState: appState)
                .environmentObject(appState)
        }
        .refreshable { await vm.reload() }
        .task { await vm.reload() }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    tempFilter = vm.filter
                    showFilterSheet = true
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
        }
        // MARK: – Filter Sheet
        .sheet(isPresented: $showFilterSheet) {
            NavigationStack {
                Form {
                    Section("Дата") {
                        DatePicker(
                            "С",
                            selection: Binding(
                                get: { tempFilter.dateFrom ?? Date() },
                                set: { tempFilter.dateFrom = $0 }
                            ),
                            displayedComponents: .date
                        )
                        DatePicker(
                            "По",
                            selection: Binding(
                                get: { tempFilter.dateTo ?? Date() },
                                set: { tempFilter.dateTo = $0 }
                            ),
                            displayedComponents: .date
                        )
                    }

                    Section("Команда") {
                        Picker("Команда", selection: $tempFilter.teamId) {
                            Text("Все").tag(nil as Int?)
                            ForEach(teams) { team in
                                Text(team.shortName).tag(Optional(team.id))
                            }
                        }
                    }

                    Section("Прочее") {
                        Picker("Статус", selection: $tempFilter.status) {
                            Text("Все").tag(nil as Int?)
                            Text("Запланированные").tag(0 as Int?)
                            Text("Идёт").tag(1 as Int?)
                            Text("Завершённые").tag(2 as Int?)
                        }
                    }
                }
                .navigationTitle("Фильтр матчей")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Отмена") { showFilterSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Применить") {
                            showFilterSheet = false
                            Task { await vm.apply(filters: tempFilter) }
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .task {
                await loadTeams()
            }
        }
    }

    @MainActor
    private func loadTeams() async {
        guard teams.isEmpty, let token = appState.token else { return }
        do {
            let resp = try await TeamInfoService.list(limit: 100, token: token)
            teams = resp.data.sorted { $0.shortName < $1.shortName }
        } catch {        }
    }
}

private struct GameCard: View {

    let game: GameRowDTO

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let displayFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "ru_RU")
        df.dateFormat = "E, dd.MM, HH:mm"
        return df
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(Self.displayFormatter.string(
                        from: Self.isoFormatter.date(from: game.date_start) ?? Date()
                ))
                .font(.subheadline.bold())

                Spacer(minLength: 4)

                let meta = [game.tournament?.name, game.group?.name]
                    .compactMap { $0 }
                    .joined(separator: " · ")
                if !meta.isEmpty {
                    Text(meta)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            // Main block: score‑box + teams
            HStack(alignment: .center, spacing: 16) {
                ScoreBox(team1: game.score?.team1,
                         team2: game.score?.team2)

                VStack(alignment: .leading, spacing: 12) {
                    TeamRow(name: game.team1.name,
                            logo: game.team1.logo_url)

                    TeamRow(name: game.team2.name,
                            logo: game.team2.logo_url)
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "mappin.and.ellipse")
                Text(game.stadium?.name ?? "Стадион неизвестен")
                    .lineLimit(1)
                Spacer()
                StatusPill(status: game.status)
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// MARK: – Helper subviews
struct ScoreBox: View {
    let team1: Int?
    let team2: Int?

    var body: some View {
        VStack(spacing: 4) {
            Text("\(team1 ?? 0)")
            Divider()
            Text("\(team2 ?? 0)")
        }
        .font(.title3.monospacedDigit().weight(.semibold))
        .frame(width: 56, height: 72)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct TeamRow: View {
    let name: String
    let logo: String?

    var body: some View {
        HStack(spacing: 8) {
            AsyncImage(url: URL(string: logo ?? "")) { phase in
                switch phase {
                case .success(let img): img.resizable().scaledToFit()
                default: Image(systemName: "shield").resizable().scaledToFit().opacity(0.3)
                }
            }
            .frame(width: 28, height: 28)
            .clipShape(Circle())

            Text(name)
                .font(.body)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Spacer()
        }
    }
}

struct StatusPill: View {
    let status: Int?

    var label: (text: String, color: Color) {
        switch status {
        case 0:  return ("Запланирован", .yellow)
        case 1:  return ("Идёт", .green)
        case 2:  return ("Завершён", .secondary)
        default: return ("—", .secondary)
        }
    }

    @State private var pulse = false

    var body: some View {
        Text(label.text.uppercased())
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(label.color.opacity(status == 1 && pulse ? 0.15 : 0.12))
            .clipShape(Capsule())
            .foregroundStyle(label.color)
            .onAppear {
                if status == 1 {
                    withAnimation(.easeInOut(duration: 0.8).repeatForever()) {
                        pulse.toggle()
                    }
                }
            }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        GamesListView(appState: AppState())
            .environmentObject(AppState())
    }
}
#endif
