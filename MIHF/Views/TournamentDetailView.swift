//
//  TournamentDetailView.swift
//  MIHF
//  Created by Alexey Drobot on 02.05.2025.

import SwiftUI

// MARK: - DTOs (минимум для отображения)
struct TournamentDetailDTO: Decodable {
    let id: Int
    let fullName: String
    let shortName: String
    let logo: String?
    let yearOfBirth: Int?
    // Позже добавим: stages, groups и т.д.
}

// MARK: - Заглушка сервиса (будет заменён)
protocol TournamentDetailServiceProtocol {
    func load(id: Int, token: String?) async throws -> TournamentDetailDTO
}

// MARK: - View‑Model
@MainActor
final class TournamentDetailViewModel: ObservableObject {
    @Published var detail: TournamentDetailDTO?
    @Published var isLoading = false
    @Published var error: String?

    private let service: TournamentDetailServiceProtocol
    private let id: Int

    init(id: Int, service: TournamentDetailServiceProtocol) {
        self.id = id
        self.service = service
    }

    func load(token: String?) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            detail = try await service.load(id: id, token: token)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Вью
struct TournamentDetailView: View {
    let tournamentId: Int
    let service: TournamentDetailServiceProtocol

    @EnvironmentObject private var appState: AppState
    @StateObject private var vm: TournamentDetailViewModel

    init(tournamentId: Int,
         service: TournamentDetailServiceProtocol = StubDetailService()) {
        self.tournamentId = tournamentId
        self.service = service
        _vm = StateObject(wrappedValue: TournamentDetailViewModel(id: tournamentId,
                                                                  service: service))
    }

    var body: some View {
        Group {
            if let detail = vm.detail {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        AsyncImage(url: URL(string: detail.logo ?? "")) { phase in
                            switch phase {
                            case .success(let img): img.resizable()
                            case .failure: Image(systemName: "trophy")
                            default: ProgressView()
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: 150)
                        .aspectRatio(contentMode: .fit)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(radius: 4)

                        Text(detail.fullName)
                            .font(.title3.weight(.semibold))
                        Text(detail.shortName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if let y = detail.yearOfBirth {
                            Text("Год рождения: \(y)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        // Заглушка для этапов
                        ContentUnavailableView("Этапы появятся позже", systemImage: "list.bullet.rectangle")
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
        .task { await vm.load(token: appState.token) }
    }
}

// MARK: - Stub Service
struct StubDetailService: TournamentDetailServiceProtocol {
    func load(id: Int, token: String?) async throws -> TournamentDetailDTO {
        // Имитация задержки сети
        try await Task.sleep(nanoseconds: 300_000_000)
        return TournamentDetailDTO(id: id,
                                   fullName: "Кубок Москвы (Заглушка)",
                                   shortName: "Кубок",
                                   logo: nil,
                                   yearOfBirth: 2015)
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        TournamentDetailView(tournamentId: 1)
            .environmentObject(AppState())
    }
}
