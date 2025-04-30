import SwiftUI

struct EditEmailView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    @State private var email: String = ""
    @State private var error: String?
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Новый e‑mail", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                if let error {
                    Section { Text(error).foregroundColor(.red) }
                }
            }
            .disabled(isLoading)
            .navigationTitle("Изменить e‑mail")
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarTrailing) { saveButton }
            })
        }
        .onAppear { email = appState.currentUser?.email ?? "" }
    }

    private var saveButton: some View {
        Button("Сохранить") { Task { await save() } }
    }

    @MainActor
    private func save() async {
        guard email.contains("@"), email.contains(".") else {
            error = "Введите корректный e‑mail"; return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            guard let token = appState.token else {
                error = "Сессия истекла"
                return
            }
            let dto = try await API.updateEmail(email, token: token)
            let roles = dto.roles?.map { Role(name: $0.name, alias: $0.alias) } ?? []
            // Конвертируем ISO‑строку даты рождения → Date?
            let dob: Date? = {
                guard let iso = dto.date_of_birth else { return nil }
                return ISO8601DateFormatter().date(from: iso)
            }()
            let updated = User(id: dto.id,
                               firstName: dto.first_name,
                               lastName: dto.last_name,
                               middleName: dto.middle_name,
                               dateOfBirth: dob,
                               email: dto.email,
                               phone: dto.phone,
                               roles: roles)
            appState.currentUser = updated
            dismiss()
        } catch {
            self.error = "Не удалось обновить e‑mail"
        }
    }
}
