import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    private var user: User {
        appState.currentUser!   // здесь безопасно, экран доступен только после логина
    }

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Основное")) {
                    LabeledContent("Имя", value: user.firstName)
                    LabeledContent("Фамилия", value: user.lastName)
                    if let middle = user.middleName {           // поле может быть nil
                        LabeledContent("Отчество", value: middle)
                    }
                    if let dob = user.dateOfBirth {
                        LabeledContent("Дата рождения", value: dob.formatted(date: .abbreviated, time: .omitted))
                    }
                }

                Section(header: Text("Контакты")) {
                    LabeledContent("Телефон", value: format(user.phone))
                    if let email = user.email {
                        LabeledContent("E-mail", value: email)
                    }
                }

                Section(header: Text("Роли")) {
                    ForEach(user.roles, id: \.alias) { role in
                        Text("\(role.name)  (\(role.alias))")
                    }
                }

                Section {
                    Button("Выйти из аккаунта", role: .destructive) {
                        appState.logout()
                    }
                }
            }
            .navigationTitle("Профиль")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") { dismiss() }
                }
            }
        }
    }

    // +7 (XXX) XXX-XX-XX
    private func format(_ digits: String) -> String {
        var d = digits.filter(\.isNumber)
        if d.hasPrefix("8") { d.replaceSubrange(d.startIndex...d.startIndex, with: "7") }
        d = String(d.prefix(11)).padding(toLength: 11, withPad: "•", startingAt: 0)
        return "+\(d[0]) (\(d[1...3])) \(d[4...6])-\(d[7...8])-\(d[9...10])"
    }
}

#Preview {
    let u = User(id: "0",
                 firstName: "Алексей",
                 lastName: "Иванов",
                 email: "user@mail.ru",
                 phone: "79001234567",
                 dateOfBirth: "1998-05-12",
                 middleName: nil,
                 roles: [.init(name: "Администратор", alias: "ADMIN")])
    let a = AppState()
    a.currentUser = u
    return ProfileView().environmentObject(a)
}