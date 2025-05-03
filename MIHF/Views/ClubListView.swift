import SwiftUI

/// Уникальный маршрут для навигации к детали клуба
private struct ClubRoute: Hashable {
    let id: Int
    let name: String
}

struct ClubListView: View {
    // MARK: - Dependencies
    @EnvironmentObject private var appState: AppState
    @StateObject private var vm: ClubListViewModel

    // MARK: - Search & filter
    @State private var query: String = ""
    @State private var showMoscowOnly = false

    // MARK: - Init
    init(appState: AppState) {
        _vm = StateObject(wrappedValue: ClubListViewModel(appState: appState))
    }

    // MARK: - Body
    var body: some View {
        List {
            ForEach(vm.clubs) { club in
                NavigationLink(value: ClubRoute(id: club.id, name: club.shortName)) {
                    ClubRow(club: club)
                }
                .task { await vm.loadMoreIfNeeded(current: club) }
            }

            if vm.isLoading && vm.clubs.isEmpty {
                ForEach(0..<6, id: \.self) { _ in
                    ClubRow(club: .placeholder)
                        .redacted(reason: .placeholder)
                }
            } else if vm.isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .listRowSeparator(.hidden)
            } else if vm.clubs.isEmpty {
                ContentUnavailableView("Нет клубов", systemImage: "sportscourt")
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .navigationTitle("Клубы")
        .navigationDestination(for: ClubRoute.self) { route in
            ClubDetailView(clubId: route.id, clubName: route.name, appState: appState)
                .environmentObject(appState)
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
        .onSubmit(of: .search) { Task { await vm.applyFilters(search: query, isMoscow: showMoscowOnly) } }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Toggle(isOn: $showMoscowOnly) {
                    Image(systemName: "m.circle")
                }
                .toggleStyle(.button)
                .onChange(of: showMoscowOnly) { newVal in
                    Task { await vm.applyFilters(search: query, isMoscow: newVal) }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if vm.isLoading { ProgressView() }
            }
        }
        .refreshable { await vm.reload() }
        .task { await vm.reload() }
    }
}

// MARK: - Row
private struct ClubRow: View {
    let club: ClubRowDTO

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: club.logo ?? "")) { phase in
                switch phase {
                case .success(let img): img.resizable()
                default:
                    Circle()
                        .fill(Color(.systemGray4))
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(Circle())

            Text(club.shortName)
                .font(.body)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Placeholder
private extension ClubRowDTO {
    static var placeholder: ClubRowDTO {
        .init(id: 0, shortName: "Клуб", logo: nil)
    }
}

// MARK: - Preview
#if DEBUG
#Preview {
    NavigationStack {
        ClubListView(appState: AppState())
            .environmentObject(AppState())
    }
}
#endif
