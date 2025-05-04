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

    private enum Tab: Hashable { case events, broadcast, lineups }

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
        // Переходы
        .navigationDestination(for: TeamRoute.self) { route in
            TeamDetailView(teamId: route.id, teamName: "Команда", appState: appState)
                .environmentObject(appState)
        }
        .navigationDestination(for: PlayerRoute.self) { route in
            Text("Игрок #\(route.id)") // TODO: PlayerDetailView
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
            Text("\(s.team1) : \(s.team2)")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.5)

            // shoot‑out (optional)
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
        // Increase tap size around the score so the header feels balanced.
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
        List {
            ForEach(vm.filteredEvents) { ev in
                eventRow(ev)
            }
        }
        .listStyle(.plain)
        .animation(.default, value: vm.filteredEvents)
    }

    @ViewBuilder
    func eventRow(_ ev: GameEventDTO) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(ev.clockText)
                .font(.caption.monospacedDigit())
                .frame(width: 46, alignment: .trailing)

            Image(systemName: ev.iconName)
                .foregroundStyle(ev.typeColor)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                // команда
                NavigationLink(value: TeamRoute(id: ev.team.id)) {
                    Text(ev.team.name).font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)

                switch ev.typeId {
                case 2: goalView(ev)
                case 4: penaltyView(ev)
                default: Text(ev.type)
                }
            }
        }
    }

    @ViewBuilder
    func goalView(_ ev: GameEventDTO) -> some View {
        if let scorer = ev.goalAuthor {
            HStack(spacing: 4) {
                playerLink(scorer)
                Text("— гол")
            }
        }
        if let a1 = ev.assist1 {
            HStack(spacing: 4) {
                Text("пас:")
                playerLink(a1)
            }
        }
        if let a2 = ev.assist2 {
            HStack(spacing: 4) {
                Text("пас:")
                playerLink(a2)
            }
        }
    }

    @ViewBuilder
    func penaltyView(_ ev: GameEventDTO) -> some View {
        HStack(spacing: 4) {
            if let p = ev.penaltyPlayer {
                playerLink(p)
            }
            Text("— \(ev.violation?.fullName ?? ev.violation?.name ?? "")")
            if let m = ev.penalty?.minutes {
                Text("(\(m) мин)")
            }
        }
    }

    @ViewBuilder
    func playerLink(_ p: GameEventDTO.ShortPerson) -> some View {
        NavigationLink(value: PlayerRoute(id: p.id)) {
            Text(p.name).underline().foregroundStyle(.blue)
        }
        .buttonStyle(.plain)
    }

    // — BROADCAST —
    @ViewBuilder
    func broadcastTab(_ g: GameDetailDTO) -> some View {
        if let urlStr = g.broadcast, let url = URL(string: urlStr) {
            WebVideoView(url: url)
                .aspectRatio(CGSize(width: 16, height: 9), contentMode: .fit)
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
        } else {
            ContentUnavailableView("Трансляция недоступна", systemImage: "tv.slash")
        }
    }

    // — LINE-UPS —
    @ViewBuilder
    func lineupsTab() -> some View {
        ContentUnavailableView("Составы пока недоступны", systemImage: "person.3")
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
}

extension GameEventDTO {
    /// Human‑readable time (mm:ss) used by the list.
    var clockText: String {
        String(format: "%02d:%02d", minute ?? 0, second ?? 0)
    }
}

// MARK: - Equatable conformance (needed for .animation value)
extension GameEventDTO: Equatable {
    static func == (lhs: GameEventDTO, rhs: GameEventDTO) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Предпросмотр
#Preview {
    NavigationStack {
        GameDetailView(gameId: 3222, appState: AppState())
            .environmentObject(AppState())
    }
}
