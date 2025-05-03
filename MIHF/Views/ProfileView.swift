import SwiftUI

struct ProfileView: View {
    // MARK: - Dependencies
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var showLogoutConfirm = false
    @State private var showEmailSheet = false
    @State private var showPasswordSheet = false

    // MARK: - Computed user
    private var user: User? { appState.currentUser }
    
    var body: some View {
        List {
            if let user = user {

                Section(header: Text("Основное")) {
                    LabeledContent("Имя", value: user.firstName)
                    LabeledContent("Фамилия", value: user.lastName)
                    if let middle = user.middleName { LabeledContent("Отчество", value: middle) }
                    if let dob = user.dateOfBirth {
                        LabeledContent("Дата рождения", value: formatDate(dob))
                    }
                }

                Section(header: Text("Контакты")) {
                    LabeledContent("Телефон", value: formattedPhone(user.phone))
                    if let email = user.email {
                        LabeledContent("E‑mail", value: email)
                    }
                }

                Section(header: Text("Роли")) {
                    ForEach(user.roles) { role in
                        Text("\(role.name)")
                    }
                }

                Section {
                    Button { showEmailSheet = true } label: { Text("Изменить e‑mail") }
                    Button { showPasswordSheet = true } label: { Text("Сбросить пароль") }
                }

                Section {
                    Button("Выйти из аккаунта", role: .destructive) {
                        showLogoutConfirm = true
                    }
                }
            }
        }
        .navigationTitle("Профиль")
        .alert("Вы действительно хотите выйти?", isPresented: $showLogoutConfirm) {
            Button("Выйти", role: .destructive) {
                appState.logout()
            }
            Button("Отмена", role: .cancel) { }
        }
        .sheet(isPresented: $showEmailSheet) { EditEmailView().environmentObject(appState) }
        .sheet(isPresented: $showPasswordSheet) { ChangePasswordView().environmentObject(appState) }
    }

    // MARK: - Helpers
    private func formattedPhone(_ raw: String) -> String {
        var digits = raw.filter { $0.isNumber }
        if digits.first == "8" { digits.replaceSubrange(digits.startIndex...digits.startIndex, with: "7") }
        if digits.count < 11 {
            digits.append(contentsOf: String(repeating: "•", count: 11 - digits.count))
        }
        let c = Array(digits.prefix(11))
        guard c.count == 11 else { return raw }
        return "+\(c[0]) (\(c[1])\(c[2])\(c[3])) \(c[4])\(c[5])\(c[6])-\(c[7])\(c[8])-\(c[9])\(c[10])"
    }

    private func formatDate(_ date: Date) -> String {
        localized(date)
    }

    private func localized(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "ru_RU")
        df.dateStyle = .long
        return df.string(from: date)
    }
}

#Preview {
    ProfileView()
        .environmentObject({
            let roles = [Role(name: "Администратор", alias: "ADMIN"),
                         Role(name: "Тренер",        alias: "COACH")]
            let dob = Calendar.current.date(from: DateComponents(year: 1998, month: 5, day: 12))!
            let user = User(id: "0",
                            firstName: "Алексей",
                            lastName: "Иванов",
                            middleName: "Сергеевич",
                            dateOfBirth: dob,
                            email: "user@mail.ru",
                            phone: "79001234567",
                            roles: roles)
            let state = AppState()
            state.currentUser = user
            return state
        }())
}
