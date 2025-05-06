import SwiftUI

struct HomeView: View {
    // MARK: - Dependencies
    @EnvironmentObject private var appState: AppState
    @State private var isAppeared = false

    private enum Route: Hashable {
        case profile
        case players
        case tournaments
        case clubs
        case games
        case refereeID
        case refereeAssignments
    }

    private let brandText      = Color(hex: 0x122859)
    private let brandBackground = Color(hex: 0xF7F8FA)
    private let brandAccent = Color(hex: 0x122859)

    private var isReferee: Bool {
        appState.currentUser?.roles.contains(where: { $0.alias.uppercased() == "REFEREE" }) ?? false
    }

    private struct MenuItem: Identifiable {
        enum Destination { case players, tournaments, clubs, games }
        let id = UUID()
        let title: String
        let systemImage: String
        let destination: Destination?
    }
    private let menu: [MenuItem] = [
        .init(title: "Игроки",    systemImage: "person.3",     destination: .players),
        .init(title: "Турниры",   systemImage: "trophy",       destination: .tournaments),
        .init(title: "Клубы",     systemImage: "building.2",   destination: .clubs),
        .init(title: "Матчи",      systemImage: "sportscourt",  destination: .games),
    ]

    private var ruDateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateStyle = .long
        return formatter.string(from: Date())
    }

    private var refereeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Служебный раздел")
                .font(.headline)
                .foregroundColor(.white)
            HStack(spacing: 16) {
                NavigationLink(value: Route.refereeID) {
                    refereeTile(title: "Моё удостоверение", systemImage: "qrcode")
                }
                NavigationLink(value: Route.refereeAssignments) {
                    refereeTile(title: "Назначения", systemImage: "list.bullet.rectangle")
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(brandAccent.opacity(0.9), in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func refereeTile(title: String, systemImage: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.title2)
            Text(title)
                .multilineTextAlignment(.center)
                .font(.caption.weight(.medium))
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity, minHeight: 80)
    }

    // MARK: - Body
var body: some View {
    NavigationStack {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                greetingHeader
                if isReferee { refereeSection }
                Text("Соревнования Москвы")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(brandText)
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
            case .games:
                GamesListView(appState: appState)
                    .environmentObject(appState)
            case .refereeID:
                RefereeIDView(uuid: appState.currentUser?.id ?? "—")
            case .refereeAssignments:
                RefereeGamesView(appState: appState)
                    .environmentObject(appState)
            }
        }
    }
}

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
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(brandAccent.opacity(0.15), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)
    }

    private var placeholderArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Документы")
                .font(.title3.weight(.semibold))
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
        case .games:       return .games
        }
    }
}

// MARK: – Referee QR
private struct RefereeIDView: View {
    let uuid: String
    var body: some View {
        VStack(spacing: 24) {
            qrImage
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(width: 240, height: 240)
            Text("UUID:\n\(uuid)")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding()
        .navigationTitle("Моё удостоверение")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var qrImage: Image {
        guard
            let data = uuid.data(using: .utf8),
            let filter = CIFilter(name: "CIQRCodeGenerator")
        else { return Image(systemName: "qrcode") }

        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("Q", forKey: "inputCorrectionLevel")

        let context = CIContext()
        let transformScale: CGFloat = 12
        if
            let output = filter.outputImage?
                .transformed(by: CGAffineTransform(scaleX: transformScale,
                                                   y: transformScale)),
            let cgImg = context.createCGImage(output, from: output.extent)
        {
            return Image(decorative: cgImg, scale: UIScreen.main.scale)
        }

        return Image(systemName: "qrcode")
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
    .environmentObject({
        let roles = [Role(name: "Арбитр", alias: "REFEREE")]
        let dob = Calendar.current.date(from: DateComponents(year: 2000, month: 1, day: 1))!
        let user = User(id: "1", firstName: "Алексей", lastName: "Иванов", middleName: nil, dateOfBirth: dob, email: "user@mail.ru", phone: "79104055190", roles: roles)
        let state = AppState()
        state.currentUser = user
        return state
    }())
}
