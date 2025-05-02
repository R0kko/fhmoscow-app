import SwiftUI

/// Экран «Список групп» для выбранного этапа
struct GroupsListView: View {
    let stage: StageDTO            // пришёл из детального турнира
    private let appState: AppState

    @StateObject private var vm: GroupViewModel

    /// Инициализатор: передаём StageDTO и AppState
    init(stage: StageDTO, appState: AppState) {
        self.stage = stage
        self.appState = appState
        _vm = StateObject(wrappedValue: GroupViewModel(stageId: stage.id,
                                                       appState: appState))
    }

    // уникальный маршрут для детального экрана группы
    private struct GroupRoute: Hashable {
        let id: Int
        let name: String
    }

    var body: some View {
        List {
            ForEach(vm.groups) { group in
                NavigationLink(value: GroupRoute(id: group.id, name: group.name)) {
                    Text(group.name)
                        .lineLimit(1)
                }
                .task { await vm.loadMoreIfNeeded(current: group) }
            }

            if vm.isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .listRowSeparator(.hidden)
            } else if vm.groups.isEmpty {
                ContentUnavailableView("Нет групп", systemImage: "person.3.sequence")
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .navigationTitle(stage.name)
        .navigationDestination(for: GroupRoute.self) { route in
            TournamentTableView(
                groupId: route.id,
                groupName: route.name,
                appState: appState
            )
        }
        .refreshable { await vm.reload() }
        .task { await vm.reload() }
    }
}

#if DEBUG
#Preview {
    let stage = StageDTO(id: 1, name: "Групповой этап", current: true)
    return NavigationStack {
        GroupsListView(stage: stage, appState: AppState())
    }
}
#endif
