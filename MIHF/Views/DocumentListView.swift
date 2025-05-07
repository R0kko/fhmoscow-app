import SwiftUI

struct DocumentsListView: View {

    // MARK: – Dependencies
    @EnvironmentObject private var appState: AppState
    @StateObject private var vm: DocumentListViewModel

    @State private var showFilterSheet = false
    @State private var tmpSeason: Int?
    @State private var seasons: [SeasonDTO] = []

    // MARK: – Init
    init(appState: AppState) {
        _vm = StateObject(wrappedValue: DocumentListViewModel(appState: appState))
    }

    // MARK: – Body
    var body: some View {
        List {
            ForEach(groupedDocs, id: \.key) { key, items in
                Section(header: Text(key)) {
                    ForEach(items) { doc in
                        Link(destination: URL(string: doc.url)!) {
                            HStack {
                                Image(systemName: "doc.text")
                                    .foregroundColor(Color(hex: 0x122859))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(doc.name ?? "Документ \(doc.id)")
                                        .lineLimit(2)
                                    if let tournament = doc.tournament?.name {
                                        Text(tournament)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if let season = doc.season?.name {
                                    Text(season)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .onAppear { Task { await vm.loadMoreIfNeeded(current: doc) } }
                    }
                }
            }

            if vm.isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
            } else if vm.docs.isEmpty {
                ContentUnavailableView("Нет документов", systemImage: "doc.text")
            }
        }
        .listStyle(.plain)
        .navigationTitle("Документы")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    tmpSeason = vm.seasonId
                    showFilterSheet = true
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .refreshable { await vm.reload() }
        .task { await vm.reload() }
        .sheet(isPresented: $showFilterSheet) {
            NavigationStack {
                Form {
                    Section("Сезон") {
                        Picker("Сезон", selection: $tmpSeason) {
                            Text("Все").tag(nil as Int?)
                            ForEach(seasons) { s in
                                Text(s.name).tag(Optional(s.id))
                            }
                        }
                    }
                }
                .navigationTitle("Фильтр")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Отмена") { showFilterSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Применить") {
                            showFilterSheet = false
                            Task { await vm.apply(categoryId: nil,
                                                  seasonId: tmpSeason,
                                                  tournamentId: nil) }
                        }
                    }
                }
            }
            .presentationDetents([.medium])
            .task {
                if seasons.isEmpty {
                    do {
                        seasons = try await SeasonService.list(token: appState.token)
                    } catch { /* ignore */ }
                }
            }
        }
    }

    private var groupedDocs: [(key: String, value: [DocumentRowDTO])] {
        Dictionary(grouping: vm.docs, by: { $0.category?.name ?? "Без категории" })
            .map { ($0.key, $0.value) }
            .sorted { $0.key < $1.key }
    }
}
