import SwiftUI

// MARK: - DTOs
struct StageDTO: Identifiable, Decodable, Hashable {
    let id: Int
    let name: String
    let current: Bool?
}

struct TournamentDetailDTO: Decodable {
    let id: Int
    let fullName: String
    let shortName: String
    let dateStart: Date?
    let dateEnd: Date?
    let logo: String?
    let yearOfBirth: Int?
    let type: String?
    let season: String?
    let stages: [StageDTO]

    private enum CodingKeys: String, CodingKey {
        case id
        case fullName      = "full_name"
        case shortName     = "short_name"
        case dateStart    = "date_start"
        case dateEnd      = "date_end"
        case logo
        case yearOfBirth   = "year_of_birth"
        case type
        case season
        case stages
    }
}

// MARK: - Service Protocol
protocol TournamentDetailServiceProtocol {
    func load(id: Int, token: String?) async throws -> TournamentDetailDTO
}

private struct StageRoute: Hashable {
    let stage: StageDTO
}

// MARK: - View
struct TournamentDetailView: View {
    let tournamentId: Int
    private let appState: AppState        // passed from parent
    @StateObject private var vm: TournamentDetailViewModel

    init(tournamentId: Int,
         appState: AppState,
         service: TournamentDetailServiceProtocol = TournamentDetailService()) {
        self.tournamentId = tournamentId
        self.appState = appState
        _vm = StateObject(
            wrappedValue: TournamentDetailViewModel(
                tournamentID: tournamentId,
                appState: appState,
                service: service
            )
        )
    }

    var body: some View {
        Group {
            if let detail = vm.detail {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Header: logo + titles
                        HStack(alignment: .top, spacing: 12) {
                            AsyncImage(url: URL(string: detail.logo ?? "")) { phase in
                                switch phase {
                                case .success(let img): img
                                        .resizable()
                                        .scaledToFit()
                                case .failure: Image(systemName: "trophy")
                                        .resizable()
                                        .scaledToFit()
                                default: ProgressView()
                                }
                            }
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                            VStack(alignment: .leading, spacing: 8) {
                                Text(detail.fullName)
                                    .font(.headline)
                                Text(detail.shortName)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Divider()

                        // Tournament fields
                        VStack(alignment: .leading, spacing: 8) {
                            if let t = detail.type {
                                FieldRow(title: "Тип", value: t, systemImage: "sportscourt")
                            }
                            if let s = detail.season {
                                FieldRow(title: "Сезон", value: s, systemImage: "calendar")
                            }
                            if let start = detail.dateStart, let end = detail.dateEnd {
                                FieldRow(title: "Даты", value: dateRange(start: start, end: end), systemImage: "clock")
                            }
                            if let y = detail.yearOfBirth {
                                FieldRow(title: "Год рождения", value: String(y), systemImage: "person")
                            }
                        }
                        .padding(.vertical, 4)

                        Divider()
                            .padding(.top, 4)

                        // Stages
                        if !detail.stages.isEmpty {
                            Text("Этапы")
                                .font(.headline)
                                .padding(.top, 8)

                            ForEach(detail.stages) { stage in
                                NavigationLink(value: StageRoute(stage: stage)) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(stage.name)
                                                .lineLimit(1)
                                                .truncationMode(.tail)
                                            if stage.current == true {
                                                Text("текущий")
                                                    .font(.caption2.bold())
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.accentColor.opacity(0.15))
                                                    .clipShape(Capsule())
                                            }
                                        }
                                        Spacer(minLength: 8)
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.vertical, 4)
                                    .contentShape(Rectangle())                   // tap area full width
                                }
                                .buttonStyle(PlainButtonStyle())                // removes blue tint
                            }
                        }
                    }
                    .padding()
                }
            } else if vm.isLoading {
                VStack { Spacer(); ProgressView(); Spacer() }
            } else if let err = vm.error {
                ContentUnavailableView(err, systemImage: "xmark.octagon")
            }
        }
        .navigationTitle("Турнир")
        .navigationDestination(for: StageRoute.self) { route in
            Text("Stage \(route.stage.name)") // TODO: StageDetailView
        }
        .task { await vm.load() }
    }
}

// MARK: - Helpers
private struct FieldRow: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: systemImage)
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 20))
                .frame(width: 24)                       // fixed icon column
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.body)
            }
        }
        .padding(.vertical, 2)                           // tighter row
    }
}
private extension TournamentDetailView {
    func dateRange(start: Date, end: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "ru_RU")
        df.dateFormat = "dd.MM.yyyy"
        return "\(df.string(from: start)) — \(df.string(from: end))"
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        TournamentDetailView(tournamentId: 1, appState: AppState())
    }
}
