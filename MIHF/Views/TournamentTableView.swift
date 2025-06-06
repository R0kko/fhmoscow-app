private extension TableRowDTO {
    static var placeholder: TableRowDTO {
        .init(
            teamId: 0,
            shortName: "Команда",
            logo: nil,
            gameCount: 0,
            winCount: 0,
            tieCount: 0,
            lossCount: 0,
            winOvertimeCount: 0,
            loseOvertimeCount: 0,
            pucksScored: 0,
            pucksMissed: 0,
            pucksDifference: 0,
            score: 0,
            position: 0
        )
    }
}
import SwiftUI

private struct TeamRoute: Hashable {
    let id: Int
    let name: String
}

struct TournamentTableView: View {

    // MARK: ‑ Input
    let groupId: Int
    let groupName: String
    let initialMoscowStanding: Bool
    private let appState: AppState

    @StateObject private var vm: TournamentTableViewModel

    @State private var standingFilter: Standing = .general

    init(groupId: Int,
         groupName: String,
         initialMoscowStanding: Bool = false,
         appState: AppState) {
        self.groupId = groupId
        self.groupName = groupName
        self.initialMoscowStanding = initialMoscowStanding
        self.appState = appState
        _vm = StateObject(
            wrappedValue: TournamentTableViewModel(
                groupId: groupId,
                moscowStanding: initialMoscowStanding,
                appState: appState
            )
        )
    }

    private enum Standing: String, CaseIterable, Identifiable {
        case general = "Общий"
        case moscow  = "Московский"

        var id: Self { self }
        var isMoscow: Bool { self == .moscow }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Standing", selection: $standingFilter) {
                ForEach(Standing.allCases) { stand in
                    Text(stand.rawValue).tag(stand)
                }
            }
            .pickerStyle(.segmented)
            .padding([.horizontal, .top])

            Divider()
                .padding(.top, 6)

            List {
                headerRow

                ForEach(vm.rows) { row in
                    NavigationLink(value: TeamRoute(id: row.teamId, name: row.shortName)) {
                        TableRowView(row: row)
                    }
                    .onAppear { Task { await vm.loadMoreIfNeeded(current: row) } }
                }

                if vm.isLoading && vm.rows.isEmpty {
                    ForEach(0..<6, id: \.self) { _ in
                        TableRowView(row: .placeholder)
                            .redacted(reason: .placeholder)
                            .shimmering()
                    }
                } else if vm.isLoading {
                    HStack { Spacer(); ProgressView(); Spacer() }
                        .listRowSeparator(.hidden)
                } else if vm.rows.isEmpty {
                    ContentUnavailableView("Нет данных", systemImage: "tablecells")
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
        }
        .navigationTitle(groupName)
        .navigationDestination(for: TeamRoute.self) { route in
            TeamDetailView(teamId: route.id, teamName: route.name, appState: appState)
                .environmentObject(appState)
        }
        .refreshable { await vm.reload() }
        .task { await vm.reload() }
        .onChange(of: standingFilter) { _, newValue in
            Task { await vm.updateStanding(isMoscow: newValue.isMoscow) }
        }
    }

    // MARK: ‑ Static header
    @ViewBuilder
    private var headerRow: some View {
        HStack(spacing: 8) {
            Text("#")
                .frame(width: 24, alignment: .center)

            Spacer().frame(width: 32)

            Text("Команда")
                .frame(minWidth: 160, alignment: .leading)

            Spacer()

            Text("О")
                .frame(width: 40, alignment: .trailing)
        }
        .font(.footnote.weight(.semibold))
        .foregroundColor(.secondary)
    }
}

// MARK: - Row View
private struct TableRowView: View {
    let row: TableRowDTO
    @State private var expanded = false

    var body: some View {
        VStack(spacing: 4) {
            Button {
                withAnimation(.easeInOut) { expanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Text(String(row.position))
                        .font(.callout.weight(.semibold))
                        .frame(width: 24, alignment: .center)

                    AsyncImage(url: URL(string: row.logo ?? "")) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable()
                        default:
                            Circle()
                                .fill(Color(.systemGray4))
                        }
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())

                    Text(row.shortName)
                        .frame(minWidth: 160, alignment: .leading)
                        .lineLimit(1)

                    Spacer()

                    numeric(row.score)              
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(PlainButtonStyle())
            .contentShape(Rectangle())

            if expanded {
                VStack(alignment: .leading, spacing: 4) {
                    statRow("Игры", row.gameCount)
                    statRow("Победы", row.winCount)
                    statRow("Победы (ОТ)", row.winOvertimeCount)
                    statRow("Поражения (ОТ)", row.loseOvertimeCount)
                    statRow("Ничьи", row.tieCount)
                    statRow("Заброшено шайб", row.pucksScored)
                    statRow("Пропущено шайб", row.pucksMissed)
                    statRow("Разница шайб", Int(row.pucksDifference))
                    statRow("Очки", row.score)
                }
                .font(.caption)
                .padding(.horizontal, 64)
                .padding(.bottom, 6)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    @ViewBuilder
    private func numeric(_ value: Int) -> some View {
        Text(String(value))
            .frame(width: 40, alignment: .trailing)
            .font(.body.monospacedDigit())
    }

    @ViewBuilder
    private func statRow(_ title: String, _ value: Int) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(String(value))
                .font(.caption.monospacedDigit())
        }
    }
}

private extension View {
    func shimmering() -> some View {
        self
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [.clear, .white.opacity(0.4), .clear]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .rotationEffect(.degrees(30))
                .blendMode(.overlay)
                .mask(self)
                .animation(
                    .linear(duration: 1.2)
                        .repeatForever(autoreverses: false),
                    value: UUID()
                )
            )
    }
}
