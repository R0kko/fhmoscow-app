import SwiftUI

struct HomeView: View {
    // MARK: - Dependencies
    @EnvironmentObject private var appState: AppState
    @State private var isAppeared = false

    /// Навигация из HomeView
    private enum Route: Hashable {
        case profile
        case players
        case tournaments
        case clubs
    }

    // MARK: - Brand
    private let brandText      = Color(hex: 0x122859)
    private let brandBackground = Color(hex: 0xF7F8FA)

    // MARK: - Menu stub
    private struct MenuItem: Identifiable {
        enum Destination { case players, tournaments, clubs }
        let id = UUID()
        let title: String
        let systemImage: String
        let destination: Destination?
    }
    private let menu: [MenuItem] = [
        .init(title: "Игроки",    systemImage: "person.3",     destination: .players),
        .init(title: "Турниры",   systemImage: "trophy",       destination: .tournaments),
        .init(title: "Клубы",     systemImage: "building.2",   destination: .clubs),
        .init(title: "Новости",   systemImage: "newspaper",    destination: nil),
        .init(title: "Календарь", systemImage: "calendar",     destination: nil),
        .init(title: "Задачи",    systemImage: "checkmark.circle", destination: nil),
        .init(title: "Документы", systemImage: "doc.text",     destination: nil)
    ]

    private var ruDateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateStyle = .long
        return formatter.string(from: Date())
    }

    // MARK: - Body
var body: some View {
    NavigationStack {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                greetingHeader
                menuGrid
                placeholderArea
            }
            .padding(.horizontal)
            .scaleEffect(isAppeared ? 1 : 0.95)
            .opacity(isAppeared ? 1 : 0)
            .animation(.easeOut(duration: 0.4), value: isAppeared)
            .onAppear { isAppeared = true }
        }
        .background(brandBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        // destination inside NavigationStack
        .navigationDestination(for: Route.self) { route in
            switch route {
            case .profile:
                ProfileView().environmentObject(appState)
            case .players:
                PlayersListView().environmentObject(appState)
            case .tournaments:
                TournamentListView(appState: appState).environmentObject(appState)
            case .clubs:
                ClubListView(appState: appState)
                    .environmentObject(appState)
            }
        }
    }
}

    // MARK: - Components
    private var greetingHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(greeting), \(appState.currentUser?.firstName ?? "Гость")!")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(brandText)
                Text(ruDateString)
                    .font(.subheadline)
                    .foregroundColor(brandText.opacity(0.6))
            }
            Spacer()
            NavigationLink(value: Route.profile) {
                Image(systemName: "person.circle.fill")
                    .font(.title2)
                    .foregroundColor(brandText)
            }
            .accessibilityLabel("Профиль")
        }
        .animation(.easeInOut, value: greeting)
    }

    private var menuGrid: some View {
        LazyVGrid(columns: Array(repeating: .init(.flexible(), spacing: 16), count: 2), spacing: 16) {
            ForEach(menu) { item in
                if let dest = item.destination {
                    NavigationLink(value: routeFromMenu(dest)) {
                        menuTile(for: item)
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    menuTile(for: item)
                        .opacity(0.4)
                }
            }
        }
    }

    @ViewBuilder
    private func menuTile(for item: MenuItem) -> some View {
        VStack(spacing: 12) {
            Image(systemName: item.systemImage)
                .font(.title)
                .foregroundColor(brandText)
            Text(item.title)
                .font(.body.weight(.medium))
                .foregroundColor(brandText)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)
    }

    /// Заглушка под будущие модули / виджеты
    private var placeholderArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Разделы приложения")
                .font(.headline)
                .foregroundColor(brandText)
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .frame(height: 160)
                .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)
                .overlay(
                    Text("Плейсхолдер под виджеты / ленту")
                        .foregroundColor(brandText.opacity(0.6))
                )
        }
        .padding(.top, 8)
    }

    // MARK: - Greeting helper
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12:   return "Доброе утро"
        case 12..<18:  return "Добрый день"
        case 18..<23:  return "Добрый вечер"
        default:       return "Доброй ночи"
        }
    }

    private func routeFromMenu(_ dest: MenuItem.Destination) -> Route {
        switch dest {
        case .players:     return .players
        case .tournaments: return .tournaments
        case .clubs:       return .clubs
        }
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
    .environmentObject({
        let roles = [Role(name: "Администратор", alias: "ADMIN")]
        let dob = Calendar.current.date(from: DateComponents(year: 2000, month: 1, day: 1))!
        let user = User(id: "1", firstName: "Алексей", lastName: "Иванов", middleName: nil, dateOfBirth: dob, email: "user@mail.ru", phone: "79104055190", roles: roles)
        let state = AppState()
        state.currentUser = user
        return state
    }())
}
