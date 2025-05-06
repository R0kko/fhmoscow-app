import SwiftUI

private struct IdentifiableString: Identifiable {
    let id = UUID()
    let value: String
}

/// Экран назначений судьи (список игр + подтверждение)
struct RefereeGamesView: View {

    // MARK: – Dependencies
    @EnvironmentObject private var appState: AppState
    @StateObject private var vm: RefereeGamesViewModel

    // MARK: – UI State
    @State private var alertItem: IdentifiableString?

    // MARK: – Init
    init(appState: AppState) {
        _vm = StateObject(wrappedValue: RefereeGamesViewModel(appState: appState))
    }

    // MARK: – Body
    var body: some View {
        List {
            ForEach(vm.games, id: \.id) { game in
                row(for: game)
            }

            if vm.isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .listRowSeparator(.hidden)
            } else if vm.games.isEmpty {
                ContentUnavailableView("Нет назначений", systemImage: "person.3.sequence")
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .navigationTitle("Назначения")
        .navigationDestination(for: GameRoute.self) { route in
            GameDetailView(gameId: route.id, appState: appState)
                .environmentObject(appState)
        }
        .refreshable { await vm.reload() }
        .task { await vm.reload() }
        .alert(item: $alertItem) { item in
            Alert(title: Text(item.value))
        }
    }

    // MARK: - Row builder
    @ViewBuilder
    private func row(for game: GameRowDTO) -> some View {
        ZStack {
            RefereeGameCard(game: game, confirmed: game.confirmed ?? false)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if game.confirmed ?? false {
                        Button("Отозвать") {
                            Task {
                                await vm.unconfirm(gameId: game.id)
                                if let msg = vm.alertMessage {
                                    alertItem = IdentifiableString(value: msg)
                                }
                            }
                        }
                        .tint(.red)
                    } else {
                        Button("Подтвердить") {
                            Task {
                                await vm.confirm(gameId: game.id)
                                if let msg = vm.alertMessage {
                                    alertItem = IdentifiableString(value: msg)
                                }
                            }
                        }
                        .tint(.green)
                    }
                }
                .onAppear { Task { await vm.loadMoreIfNeeded(current: game) } }

            // Invisible link without chevron
            NavigationLink(value: GameRoute(id: game.id)) {
                EmptyView()
            }
            .opacity(0)
        }
        .listRowSeparator(.hidden)
        .padding(.vertical, 4)
    }
}

// MARK: - Compact card for referee list
private struct RefereeGameCard: View {

    let game: GameRowDTO
    let confirmed: Bool

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
            // date + tournament/group line
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(
                    Self.displayFormatter.string(
                        from: Self.isoFormatter.date(from: game.date_start) ?? Date()
                    )
                )
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

            // main block: score‑box + teams
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
        .background(
            ZStack(alignment: .leading) {
                // main card background + optional left accent bar
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.systemBackground))

                if confirmed {
                    // 4‑pt accent bar on the left for clear visual cue
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.green)
                        .frame(width: 4)
                        .padding(.vertical, 6)
                        .padding(.leading, 2)
                }
            }
            .overlay(
                // subtle stroke for light mode
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(confirmed ? Color.green.opacity(0.5) : Color.clear,
                                  lineWidth: 1)
            )
        )
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        RefereeGamesView(appState: .preview)
            .environmentObject(AppState.preview)
    }
}
#endif
