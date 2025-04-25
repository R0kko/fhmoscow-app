import SwiftUI

struct HomeView: View {
    // MARK: - Deps
    @EnvironmentObject private var appState: AppState
    @State private var isAppeared = false

    private let brandText = Color(hex: 0x122859)
    private let brandBackground = Color(hex: 0xF7F8FA)

    // MARK: - Menu stub
    private struct MenuItem: Identifiable { let id = UUID(); let title: String; let systemImage: String }
    private let menu: [MenuItem] = [
        .init(title: "Новости",   systemImage: "newspaper"),
        .init(title: "Календарь", systemImage: "calendar"),
        .init(title: "Задачи",    systemImage: "checkmark.circle"),
        .init(title: "Документы", systemImage: "doc.text")
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
                Spacer()
                Spacer()
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
                    .foregroundColor(.secondary)
            }
            Spacer()
            // Профиль
            Button {
                // TODO: Navigate to profile screen
            } label: {
                Image(systemName: "person.circle.fill")
                    .font(.title2)
                    .foregroundColor(brandText)
            }
            .accessibilityLabel("Профиль")
        }
        .animation(.easeInOut, value: greeting)
    }

    private var menuGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
            ForEach(menu) { item in
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
        }
    }

    /// Заглушка под будущие модули / виджеты
    private var placeholderArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Разделы приложения")
                .font(.headline)
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .frame(height: 160)
                .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)
                .overlay(Text("Плейсхолдер под виджеты / ленту").foregroundColor(brandText.opacity(0.6)))
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
}

#Preview {
    HomeView()
        .environmentObject({
            let a = AppState()
            a.currentUser = User(id: "1",
                                 firstName: "Алексей",
                                 lastName: "Иванов",
                                 email: nil,
                                 phone: "")
            return a
        }())
}
