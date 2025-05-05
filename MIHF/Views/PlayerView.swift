import SwiftUI

struct PlayerDetailView: View {

    // MARK: – State
    @StateObject private var vm: PlayerViewModel
    @EnvironmentObject private var appState: AppState

    // MARK: – Init
    init(playerID: Int, appState: AppState) {
        _vm = .init(wrappedValue: PlayerViewModel(playerID: playerID,
                                                 appState: appState))
    }

    // MARK: – Body
    var body: some View {
        Group {
            if let detail = vm.player {
                content(for: detail)
            } else if vm.isLoading {
                ProgressView("Загружаем информацию...")
                    .progressViewStyle(.circular)
            } else if let error = vm.error {
                VStack(spacing: 12) {
                    Text(error)
                        .multilineTextAlignment(.center)
                    Button("Повторить") {
                        Task { await vm.load() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .task { await vm.load() }        // initial load
        .navigationTitle(vm.fullName.isEmpty ? "Игрок" : vm.fullName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: GameRoute.self) { route in
            GameDetailView(gameId: route.id, appState: appState)
                .environmentObject(appState)
        }
    }

    // MARK: – Sub-views
    @ViewBuilder
    private func content(for p: PlayerDetailDTO) -> some View {
        ScrollView {
            VStack(spacing: 24) {

                headerSection(for: p)

                Divider()

                physicalSection(for: p)

                if !p.statistics.isEmpty {
                    Divider()
                    statisticsSection(stats: p.statistics)
                }
                if !vm.games.isEmpty || vm.isLoadingGames {
                    Divider()
                    gamesSection
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .overlay(alignment: .top) { if vm.isLoading { LinearProgressView() } }
    }

    // MARK: – Header (photo + ФИО + дата рождения)
    @ViewBuilder
    private func headerSection(for p: PlayerDetailDTO) -> some View {
        HStack(alignment: .top, spacing: 16) {

            AsyncImage(url: URL(string: p.photo ?? "")) { phase in
                switch phase {
                case .success(let img):
                    img
                        .resizable()
                        .scaledToFill()
                default:
                    Image(systemName: "person.fill")
                        .resizable()
                        .scaledToFit()
                        .padding(12)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 96, height: 96)
            .background(.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(vm.fullName.isEmpty ? "—" : vm.fullName)
                    .font(.title3.bold())

                if let date = vm.birthday {
                    Text(date)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let sex = p.sex {
                    Text(sex)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
    }

    // MARK: – Growth, weight, grip…
    @ViewBuilder
    private func physicalSection(for p: PlayerDetailDTO) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Физические данные")
                .font(.headline)

            LazyVGrid(columns: [.init(.adaptive(minimum: 120), spacing: 16)],
                      alignment: .leading,
                      spacing: 12) {

                InfoRow(label: "Рост", value: p.height.map { "\($0) см" })
                InfoRow(label: "Вес",  value: p.weight.map { "\($0) кг" })
                InfoRow(label: "Хват", value: p.grip)
                InfoRow(label: "E-mail", value: p.email)
            }
        }
    }

    // MARK: – Statistics
    @ViewBuilder
    private func statisticsSection(stats: [PlayerDetailDTO.TeamStat]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Статистика")
                .font(.title3.weight(.semibold))

            LazyVStack(spacing: 12) {
                ForEach(stats) { st in
                    TeamStatCard(stat: st)
                }
            }
        }
    }

    // MARK: – Player matches
    @ViewBuilder
    private var gamesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Матчи игрока")
                .font(.title3.weight(.semibold))

            if vm.isLoadingGames && vm.games.isEmpty {
                HStack { Spacer(); ProgressView(); Spacer() }
            }
            else if vm.games.isEmpty {
                ContentUnavailableView("Нет данных", systemImage: "sportscourt")
            }
            else {
                LazyVStack(spacing: 12) {
                    ForEach(vm.games) { game in
                        NavigationLink(value: GameRoute(id: game.id)) {
                            SmallGameCard(game: game)
                                .onAppear { Task { await vm.loadMoreIfNeeded(current: game) } }
                        }
                        .buttonStyle(.plain)
                    }
                    if vm.isLoadingGames {
                        HStack { Spacer(); ProgressView(); Spacer() }
                    }
                }
            }
        }
    }

    // MARK: – Small game card (fits narrow column)
    private struct SmallGameCard: View {
        let game: GameRowDTO

        private static let isoParser: ISO8601DateFormatter = {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return f
        }()
        private static let dateFormatter: DateFormatter = {
            let df = DateFormatter()
            df.locale = .current
            df.dateFormat = "dd.MM, HH:mm"
            return df
        }()

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                // date
                Text(Self.dateFormatter.string(from: Self.isoParser.date(from: game.date_start) ?? Date()))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    ScoreBox(team1: game.score?.team1, team2: game.score?.team2)
                        .frame(width: 44)
                    VStack(alignment: .leading, spacing: 6) {
                        TeamRow(name: game.team1.name, logo: game.team1.logo_url)
                        TeamRow(name: game.team2.name, logo: game.team2.logo_url)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private struct TeamStatCard: View {
        let stat: PlayerDetailDTO.TeamStat

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {

                HStack(spacing: 10) {
                    AsyncImage(url: URL(string: stat.logoURL ?? "")) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFit()
                        default:
                            Image(systemName: "shield")
                                .resizable()
                                .scaledToFit()
                                .padding(6)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 40, height: 40)
                    .background(Color(.systemGray5))
                    .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(stat.teamName)
                            .font(.headline)

                        if let club = stat.clubName {
                            Text(club)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()
                }

                let stats: [StatCell] = [
                    StatCell(label: "Игры",    value: stat.games),
                    StatCell(label: "Голы",    value: stat.goals),
                    StatCell(label: "Пасы",    value: stat.assists),
                    StatCell(label: "Штраф",   value: stat.penalties),
                    stat.reliabilityFactor != nil
                        ? StatCell(label: "Коэф.", value: String(format: "%.2f",
                                                                    stat.reliabilityFactor!))
                        : StatCell(label: "Пропущ.", value: stat.missed)
                ]

                LazyVGrid(columns: Array(repeating: .init(.flexible(), spacing: 16),
                                         count: 3),
                          alignment: .leading,
                          spacing: 8) {
                    ForEach(stats) { $0 }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.systemGray6))
            )
        }
    }

    private struct StatCell: View, Identifiable {
        let id = UUID()
        let label: String
        let value: String

        init(label: String, value: Int) {
            self.label  = label
            self.value  = "\(value)"
        }
        init(label: String, value: String) {
            self.label  = label
            self.value  = value
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption.weight(.medium))
            }
        }
    }
}

// MARK: – Small reusable views
private struct InfoRow: View {
    let label: String
    let value: String?

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.callout.weight(.semibold))
            Spacer()
            Text(value ?? "—")
                .font(.callout)
                .foregroundStyle(.primary)
        }
    }
}

private struct LinearProgressView: View {
    @State private var isVisible = false
    var body: some View {
        ProgressView()
            .progressViewStyle(.linear)
            .opacity(isVisible ? 1 : 0)
            .task {
                withAnimation(.easeInOut(duration: 0.2)) { isVisible = true }
            }
    }
}

// MARK: – Preview
#Preview {
    NavigationStack {
        PlayerDetailView(playerID: 5433, appState: .preview)
            .environment(\.locale, .init(identifier: "ru"))
    }
}
