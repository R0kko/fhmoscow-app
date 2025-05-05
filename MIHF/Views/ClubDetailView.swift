import SwiftUI

private struct TeamRoute: Hashable {
    let id: Int
    let name: String
}

private extension String {
    var strippedHTML: String {
        if let data = self.data(using: .utf8) {
            if let attr = try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.html,
                          .characterEncoding: String.Encoding.utf8.rawValue],
                documentAttributes: nil)
            {
                return attr.string
            }
        }
        return self.replacingOccurrences(of: "<[^>]+>", with: "",
                                         options: .regularExpression)
    }
}

struct ClubDetailView: View {

    // MARK: - Input
    let clubId: Int
    let clubName: String
    private let appState: AppState

    // MARK: - View‑Model
    @StateObject private var vm: ClubDetailViewModel

    // MARK: - Init
    init(clubId: Int, clubName: String, appState: AppState) {
        self.clubId = clubId
        self.clubName = clubName
        self.appState = appState
        _vm = StateObject(wrappedValue: ClubDetailViewModel(clubId: clubId, appState: appState))
    }

    var body: some View {
        Group {
            if let detail = vm.detail {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {

                        // Logo + titles
                        HStack(spacing: 12) {
                            AsyncImage(url: URL(string: detail.logoUrl ?? "")) { phase in
                                switch phase {
                                case .success(let img): img.resizable().scaledToFit()
                                default:
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(.systemGray5))
                                }
                            }
                            .frame(width: 96, height: 96)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                            VStack(alignment: .leading, spacing: 4) {
                                if let full = detail.fullName {
                                    Text(full)
                                        .font(.title3.weight(.semibold))
                                }
                                if let short = detail.shortName ?? detail.fullName {
                                    Text(short)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                if detail.isMoscow {
                                    Label("Московский клуб", systemImage: "m.circle")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                        }

                        if let desc = detail.description?.strippedHTML, !desc.isEmpty {
                            Text(desc)
                                .font(.body)
                        }

                        if let site = detail.site, let url = URL(string: site) {
                            Link(destination: url) {
                                Label(site, systemImage: "link")
                            }
                            .font(.subheadline)
                        }

                        Divider()

                        if !detail.teams.isEmpty {
                            Text("Команды")
                                .font(.headline)

                            ForEach(detail.teams) { team in
                                NavigationLink(value: TeamRoute(id: team.id, name: team.shortName)) {
                                    HStack(spacing: 12) {
                                        AsyncImage(url: URL(string: detail.logoUrl ?? "")) { phase in
                                            switch phase {
                                            case .success(let img): img.resizable()
                                            default: Circle().fill(Color(.systemGray4))
                                            }
                                        }
                                        .frame(width: 40, height: 40)
                                        .clipShape(Circle())

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(team.shortName)
                                                .font(.body)
                                                .lineLimit(1)
                                            if let year = team.year {
                                                Text(String(year))
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        Spacer()
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                    .padding()
                }
            } else if vm.isLoading {
                VStack { Spacer(); ProgressView(); Spacer() }
            } else if let error = vm.error {
                ContentUnavailableView(error, systemImage: "xmark.octagon")
            }
        }
        .navigationTitle(clubName)
        .navigationDestination(for: TeamRoute.self) { route in
            TeamDetailView(teamId: route.id, teamName: route.name, appState: appState)
                .environmentObject(appState)
        }
        .task { await vm.load() }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        ClubDetailView(clubId: 1, clubName: "СКА", appState: AppState())
    }
}
#endif
