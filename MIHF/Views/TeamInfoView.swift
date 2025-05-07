import SwiftUI

private struct TeamRoute: Hashable {
    let id: Int
    let name: String
}

private struct PlayerRoute: Hashable {
    let id: Int
    let name: String
}

struct TeamListView: View {

    @EnvironmentObject private var appState: AppState
    @StateObject private var vm: TeamListViewModel

    // search / filters
    @State private var query: String = ""
    @State private var yearFilter: String = ""

    @State private var showFilter = false
    @State private var showYearError = false

    init(appState: AppState) {
        _vm = StateObject(wrappedValue: TeamListViewModel(appState: appState))
    }

    var body: some View {
        List {
            ForEach(vm.teams) { team in
                NavigationLink(value: TeamRoute(id: team.id, name: team.shortName)) {
                    TeamRow(team: team)
                }
                .task { await vm.loadMoreIfNeeded(current: team) }
            }

            if vm.isLoading && vm.teams.isEmpty {
                ForEach(0..<6, id: \.self) { _ in
                    TeamRow(team: .placeholder)
                        .redacted(reason: .placeholder)
                }
            } else if vm.isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
            } else if vm.teams.isEmpty {
                ContentUnavailableView("Нет команд", systemImage: "sportscourt")
            }
        }
        .listStyle(.plain)
        .navigationTitle("Команды")
        .navigationDestination(for: TeamRoute.self) { route in
            TeamDetailView(teamId: route.id, teamName: route.name, appState: appState)
                .environmentObject(appState)
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
        .onSubmit(of: .search) { Task { await vm.applyFilters(search: query, year: Int(yearFilter)) } }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showFilter = true } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if vm.isLoading { ProgressView() }
            }
        }
        .sheet(isPresented: $showFilter) {
            NavigationStack {
                Form {
                    Section("Год") {
                        TextField("Напр. 2015", text: $yearFilter)
                            .keyboardType(.numberPad)
                    }
                }
                .navigationTitle("Фильтр")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Отмена") { showFilter = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Применить") {
                            if yearFilter.isEmpty || Int(yearFilter) != nil {
                                showFilter = false
                                Task { await vm.applyFilters(search: query, year: Int(yearFilter)) }
                            } else {
                                showYearError = true
                            }
                        }
                    }
                }
                .alert("Неверный год", isPresented: $showYearError) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text("Введите год числом, например 2015.")
                }
            }
        }
        .refreshable { await vm.reload() }
        .task { await vm.reload() }
    }

    private struct TeamRow: View {
        let team: TeamRowDTO
        var body: some View {
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: team.logoUrl ?? "")) { phase in
                    switch phase {
                    case .success(let img): img.resizable()
                    default:
                        Circle().fill(Color(.systemGray4))
                    }
                }
                .frame(width: 48, height: 48)
                .clipShape(Circle())
                Text(team.shortName)
                    .font(.body)
                    .lineLimit(1)
            }
        }
    }
}

private extension TeamRowDTO {
    static var placeholder: TeamRowDTO {
        .init(id: 0, shortName: "Команда", logoUrl: nil)
    }
}

private func formattedBirth(_ iso: String?) -> String? {
    guard let iso else { return nil }

    struct ISO {
        static let parser: ISO8601DateFormatter = {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return f
        }()
    }

    guard let date = ISO.parser.date(from: iso) else { return nil }

    let df = DateFormatter()
    df.locale = Locale(identifier: "ru_RU")
    df.dateFormat = "d MMMM yyyy"
    return df.string(from: date)
}

struct TeamDetailView: View {

    let teamId: Int
    let teamName: String
    private let appState: AppState

    @StateObject private var vm: TeamDetailViewModel

    init(teamId: Int, teamName: String, appState: AppState) {
        self.teamId = teamId
        self.teamName = teamName
        self.appState = appState
        _vm = StateObject(wrappedValue: TeamDetailViewModel(teamId: teamId, appState: appState))
    }

    var body: some View {
        Group {
            if let detail = vm.detail {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {

                        HStack(spacing: 12) {
                            AsyncImage(url: URL(string: detail.logoUrl ?? "")) { phase in
                                switch phase {
                                case .success(let img): img.resizable().scaledToFit()
                                default:
                                    RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray5))
                                }
                            }
                            .frame(width: 96, height: 96)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(detail.fullName)
                                    .font(.title3.weight(.semibold))
                                if let year = detail.year {
                                    Text(String(year))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                        }

                        Divider()

                        if !vm.playersByPosition.isEmpty {
                            Text("Игроки")
                                .font(.headline)

                            ForEach(vm.playersByPosition, id: \.key) { group in
                                if !group.items.isEmpty {
                                    Section(header:
                                                Text(group.key)
                                                    .font(.subheadline.weight(.semibold))
                                                    .foregroundColor(.secondary)
                                                    .textCase(nil)
                                    ) {
                                        ForEach(group.items) { player in
                                            NavigationLink(
                                                value: PlayerRoute(id: player.id, name: player.fullName)
                                            ) {
                                                PersonRow(
                                                    fullName: player.fullName,
                                                    subtitle: formattedBirth(player.dateOfBirth),
                                                    photoUrl: player.photoUrl,
                                                    number: player.number,
                                                    showChevron: true
                                                )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                        }

                        // Staff
                        if !detail.staff.isEmpty {
                            Text("Тренерский штаб")
                                .font(.headline)
                                .padding(.top, 8)

                            ForEach(detail.staff) { st in
                                PersonRow(
                                    fullName: st.fullName,
                                    subtitle: st.category,
                                    photoUrl: st.photoUrl,
                                    number: nil,
                                    showChevron: false
                                )
                            }
                        }
                    }
                    .padding()
                }
                .navigationDestination(for: PlayerRoute.self) { route in
                    PlayerDetailView(playerID: route.id, appState: appState)
                }
            } else if vm.isLoading {
                VStack { Spacer(); ProgressView(); Spacer() }
            } else if let err = vm.error {
                ContentUnavailableView(err, systemImage: "xmark.octagon")
            }
        }
        .navigationTitle(teamName)
        .task { await vm.load() }
    }

    private struct PersonRow: View {
        let fullName: String
        let subtitle: String?
        let photoUrl: String?
        let number: Int?
        let showChevron: Bool  

        var body: some View {
            HStack(spacing: 12) {

                AsyncImage(url: URL(string: photoUrl ?? "")) { phase in
                    switch phase {
                    case .success(let img): img.resizable()
                    default:
                        Image(systemName: "person.crop.circle")
                            .resizable()
                            .foregroundColor(.gray.opacity(0.5))
                    }
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())

                if let number {
                    Text(String(number))
                        .font(.caption.bold())
                        .frame(width: 28, height: 28)
                        .background(Color.accentColor.opacity(0.15))
                        .clipShape(Circle())
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(fullName)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .contentShape(Rectangle())
            .buttonStyle(.plain)
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Previews
#if DEBUG
#Preview {
    NavigationStack {
        TeamListView(appState: AppState())
            .environmentObject(AppState())
    }
}
#endif
