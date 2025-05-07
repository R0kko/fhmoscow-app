
import SwiftUI
import WebKit

// MARK: - Навигационные маршруты
private struct TeamRoute: Hashable { let id: Int }
private struct PlayerRoute: Hashable { let id: Int }

// MARK: - Веб-вью для трансляции
private struct WebVideoView: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true
        let web = WKWebView(frame: .zero, configuration: cfg)
        web.scrollView.isScrollEnabled = false
        return web
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.load(URLRequest(url: url))
    }
}

// MARK: - Основной экран матча
struct GameDetailView: View {
    let gameId: Int

    @EnvironmentObject private var appState: AppState
    @StateObject private var vm: GameDetailViewModel
    @State private var selectedTab: Tab = .events
    /// 0 – team1, 1 – team2
    @State private var selectedLineup = 0
    @Environment(\.openURL) private var openURL

    private enum Tab: Hashable { case events, broadcast, lineups, referees }

    private var isCurrentUserReferee: Bool {
        appState.currentUser?.roles.contains { $0.alias.uppercased() == "REFEREE" } ?? false
    }

    init(gameId: Int, appState: AppState) {
        self.gameId = gameId
        _vm = StateObject(wrappedValue: GameDetailViewModel(gameID: gameId,
                                                            appState: appState))
    }

    var body: some View {
        Group {
            if let g = vm.detail {
                VStack(spacing: 0) {
                    header(g)
                    Divider()
                    TabView(selection: $selectedTab) {
                        eventsTab(g)
                            .tag(Tab.events)
                            .tabItem { Label("События", systemImage: "list.bullet.rectangle") }

                        broadcastTab(g)
                            .tag(Tab.broadcast)
                            .tabItem { Label("Трансляция", systemImage: "tv") }

                        lineupsTab()
                            .tag(Tab.lineups)
                            .tabItem { Label("Составы", systemImage: "person.3") }

                        if isCurrentUserReferee {
                            refereesTab()
                                .tag(Tab.referees)
                                .tabItem { Label("Судьи", systemImage: "person.crop.rectangle.stack") }
                        }
                    }
                }
            } else if vm.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let err = vm.error {
                ContentUnavailableView(err, systemImage: "xmark.octagon")
            }
        }
        .navigationTitle("Матч")
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.load() }
        .navigationDestination(for: TeamRoute.self) { route in
            TeamDetailView(teamId: route.id, teamName: "Команда", appState: appState)
                .environmentObject(appState)
        }
        .navigationDestination(for: PlayerRoute.self) { route in
            PlayerDetailView(playerID: route.id, appState: appState)
        }
    }
}

// MARK: - Header
private extension GameDetailView {
    @ViewBuilder
    func header(_ g: GameDetailDTO) -> some View {
        VStack(spacing: 4) {
            Text(dateString(g.dateStart))
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                teamBlock(g.team1)
                scoreBlock(g.score, status: g.status)
                teamBlock(g.team2)
            }
            .padding(.vertical, 8)

            if let stadium = g.stadium {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse")
                    Text(stadium.name).font(.caption)
                }
                .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        .padding(.bottom, 16)
    }

    func dateString(_ iso: String) -> String {
        guard
            let date = GameDetailViewModel.isoParser.date(from: iso)
        else { return iso }
        return DateFormatter.localizedString(from: date,
                                             dateStyle: .short,
                                             timeStyle: .short)
    }

    @ViewBuilder
    func teamBlock(_ t: GameTeamShortDTO) -> some View {
        VStack(spacing: 4) {
            AsyncImage(url: URL(string: t.logoURL ?? "")) { phase in
                switch phase {
                case .success(let img): img.resizable().scaledToFit()
                default: Image(systemName: "shield")
            }}
            .frame(width: 60, height: 60)
            .clipShape(Circle())
            .overlay(Circle().stroke(.quaternary, lineWidth: 1))

            NavigationLink(value: TeamRoute(id: t.id)) {
                Text(t.name)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: 120)
    }

    @ViewBuilder
    func scoreBlock(_ s: GameScoreDTO, status: Int) -> some View {
        VStack(spacing: 2) {
            // main score
            Text("\(s.team1 ?? 0) : \(s.team2 ?? 0)")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.5)

            if let so = s.shootout,
               let t1 = so.team1,
               let t2 = so.team2 {
                Text("SO \(t1)‑\(t2)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            statusIndicator(status)
        }
        .frame(minWidth: 110)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    func statusIndicator(_ status: Int) -> some View {
        switch status {
        case 0:
            Label("Запланирован", systemImage: "clock")
                .labelStyle(.titleAndIcon)
                .font(.caption2)
                .foregroundStyle(.secondary)
        case 1:
            Label("Live", systemImage: "dot.radiowaves.left.and.right")
                .font(.caption2.bold())
                .padding(.horizontal, 8).padding(.vertical, 2)
                .background(Color.red.opacity(0.2)).clipShape(Capsule())
                .overlay(Capsule().stroke(Color.red, lineWidth: 0.5))
                .animation(.easeInOut(duration: 0.9).repeatForever(), value: status)
        default:
            Label("Завершён", systemImage: "flag.checkered")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Tabs
private extension GameDetailView {
    func eventsTab(_ g: GameDetailDTO) -> some View {
        Group {
            if vm.filteredEvents.isEmpty {
                ContentUnavailableView("События ещё не загружены",
                                       systemImage: "list.bullet.rectangle")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(vm.filteredEvents) { ev in
                            eventRow(ev)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .scrollIndicators(.hidden)
                }
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    func eventRow(_ ev: GameEventDTO) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(ev.clockText)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .trailing)

            Image(systemName: ev.iconName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ev.typeColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(ev.eventTitle)
                    .font(.subheadline.weight(.semibold))

                NavigationLink(value: TeamRoute(id: ev.team.id)) {
                    Text(ev.team.name)
                        .font(.footnote)
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                .hideChevron()

                switch ev.typeId {
                case 2: goalView(ev)
                case 4: penaltyView(ev)
                default: EmptyView()
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }

    @ViewBuilder
    func goalView(_ ev: GameEventDTO) -> some View {
        if let scorer = ev.goalAuthor {
            HStack(spacing: 4) {
                playerLink(scorer).hideChevron()
                Text("— гол")
            }
        }
        if let a1 = ev.assist1 {
            HStack(spacing: 4) {
                Text("пас:")
                playerLink(a1).hideChevron()
            }
        }
        if let a2 = ev.assist2 {
            HStack(spacing: 4) {
                Text("пас:")
                playerLink(a2).hideChevron()
            }
        }
    }

    @ViewBuilder
    func penaltyView(_ ev: GameEventDTO) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "hand.raised.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            if let player = ev.penaltyPlayer {
                playerLink(player).hideChevron()
            }

            if let minutes = ev.penalty?.minutes {
                Text("(\(minutes) мин)")
                    .font(.footnote)
            }
        }
    }

    @ViewBuilder
    func playerLink(_ p: GameEventDTO.ShortPerson) -> some View {
        NavigationLink(value: PlayerRoute(id: p.id)) {
            Text(p.name)
                .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
        .listRowSeparator(.hidden)
    }

    @ViewBuilder
    func broadcastTab(_ g: GameDetailDTO) -> some View {
        if let urlStr = g.broadcast, let url = URL(string: urlStr) {
            ScrollView {
                VStack(spacing: 20) {
                    WebVideoView(url: url)
                        .aspectRatio(CGSize(width: 16, height: 9), contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(radius: 4)

                    Button {
                        openURL(url)
                    } label: {
                        Label("Открыть в Safari", systemImage: "safari")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)
                .padding(.top, 24)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .scrollIndicators(.hidden)
            .background(Color(uiColor: .systemGroupedBackground))
        } else {
            ContentUnavailableView("Трансляция недоступна", systemImage: "tv.slash")
        }
    }

    @ViewBuilder
    func lineupsTab() -> some View {
        let players1 = vm.lineupTeam1?.players ?? []
        let players2 = vm.lineupTeam2?.players ?? []
        if players1.isEmpty && players2.isEmpty {
            ContentUnavailableView("Составы пока недоступны",
                                   systemImage: "person.3")
        } else {
            VStack {
                Picker("Команда", selection: $selectedLineup) {
                    if let t1 = vm.detail?.team1 {
                        Text(t1.name).tag(0)
                    }
                    if let t2 = vm.detail?.team2 {
                        Text(t2.name).tag(1)
                    }
                }
                .pickerStyle(.segmented)
                .padding([.top, .horizontal])

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        let currentPlayers = selectedLineup == 0 ? players1 : players2
                        ForEach(currentPlayers) { pl in
                            NavigationLink(value: PlayerRoute(id: pl.id)) {
                                LineupRow(player: pl)
                                    .padding(.horizontal)
                            }
                            .buttonStyle(.plain)
                            .hideChevron()
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
        }
    }

    // MARK: – Referees tab
    @ViewBuilder
    func refereesTab() -> some View {
        if vm.referees.isEmpty {
            ContentUnavailableView("Судьи не назначены",
                                   systemImage: "person.crop.rectangle.badge.xmark")
        } else {
            List {
                ForEach(groupedReferees, id: \.0) { role, refs in
                    Section(role) {
                        ForEach(refs) { ref in
                            HStack {
                                AsyncImage(url: URL(string: ref.photo_url ?? "")) { phase in
                                    switch phase {
                                    case .success(let img): img.resizable()
                                    default:
                                        Image(systemName: "person.crop.circle")
                                            .resizable()
                                            .foregroundColor(.gray.opacity(0.4))
                                    }
                                }
                                .frame(width: 36, height: 36)
                                .clipShape(Circle())

                                Text(ref.full_name)
                                    .lineLimit(1)

                                Spacer()

                                if let phone = ref.phone {
                                    let digits = phone.filter { $0.isNumber }
                                    if let url = URL(string: "tel://\(digits)") {
                                        Button {
                                            openURL(url)
                                        } label: {
                                            Image(systemName: "phone")
                                        }
                                    }
                                }
                            }
                            .contentShape(Rectangle())
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    private var groupedReferees: [(String, [RefereeRowDTO])] {
        Dictionary(grouping: vm.referees, by: { $0.role })
            .map { ($0.key, $0.value) }
            .sorted { $0.0 < $1.0 }
    }
}

extension View {
    func hideChevron() -> some View {
        self
            .overlay(
                Image(systemName: "chevron.right")
                    .opacity(0)
            )
    }
}

// MARK: - Иконка для события
private extension GameEventDTO {
    var iconName: String {
        switch typeId {
        case 2:  return "hockey.puck"
        case 4:  return "exclamationmark.triangle"
        default: return "circle"
        }
    }
    var typeColor: Color {
        switch typeId {
        case 2:  return .blue        // goal
        case 4:  return .orange      // penalty
        default: return .gray
        }
    }

    var eventTitle: String {
        switch typeId {
        case 2:  return "Гол"
        case 4:  return violation?.fullName ?? "Штраф"
        default: return type
        }
    }
}

extension GameEventDTO {
    var clockText: String {
        String(format: "%02d:%02d", minute ?? 0, second ?? 0)
    }
}


/// Compact row for a player in the line‑up
private struct LineupRow: View {
    let player: GameLineupDTO.Player

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: player.photoURL ?? "")) { phase in
                switch phase {
                case .success(let img): img.resizable()
                default:
                    Image(systemName: "person.crop.circle")
                        .resizable()
                        .foregroundColor(.gray.opacity(0.4))
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())

            if let num = player.number {
                Text(String(num))
                    .font(.caption.bold())
                    .frame(width: 26, height: 26)
                    .background(Color.accentColor.opacity(0.15))
                    .clipShape(Circle())
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(player.fullName)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if let pos = player.position {
                    Text(pos)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        GameDetailView(gameId: 3222, appState: AppState())
            .environmentObject(AppState())
    }
}
