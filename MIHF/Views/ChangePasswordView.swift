import SwiftUI

struct ChangePasswordView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    @State private var oldPwd = ""
    @State private var strength: PasswordStrength = .weak
    @FocusState private var focusedField: Field?

    enum Field { case old, new, confirm }

    enum PasswordStrength: Int, CaseIterable {
        case weak = 1, medium = 2, strong = 3
        var text: String {
            switch self {
            case .weak:   return "Слабый"
            case .medium: return "Средний"
            case .strong: return "Сильный"
            }
        }
        var color: Color {
            switch self {
            case .weak:   return .red
            case .medium: return .orange
            case .strong: return .green
            }
        }
    }
    @State private var newPwd = ""
    @State private var confirmPwd = ""
    @State private var error: String?
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Старый пароль") {
                    SecureField("Старый пароль", text: $oldPwd)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section("Новый пароль") {
                    SecureField("Новый пароль", text: $newPwd)
                        .focused($focusedField, equals: .new)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: newPwd) { _, pwd in
                            strength = evaluateStrength(pwd)
                        }

                    VStack(alignment: .leading, spacing: 4) {
                        ProgressView(value: Double(strength.rawValue), total: 3)
                            .tint(strength.color)
                        Text("Сложность: \(strength.text)")
                            .font(.caption)
                            .foregroundColor(strength.color)
                    }

                    SecureField("Повторите пароль", text: $confirmPwd)
                        .focused($focusedField, equals: .confirm)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                if let error {
                    Section { Text(error).foregroundColor(.red) }
                }
            }
            .disabled(isLoading)
            .navigationTitle("Смена пароля")
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarTrailing) { saveButton }
            })
            .overlay {
                if isLoading {
                    ZStack {
                        Color.black.opacity(0.15).ignoresSafeArea()
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(1.4)
                    }
                }
            }
        }
    }

    private var saveButton: some View {
        Button("Сохранить") { Task { await save() } }
            .disabled(isLoading)
    }

    @MainActor
    private func save() async {
        guard !oldPwd.isEmpty,
              newPwd == confirmPwd,
              strength == .medium || strength == .strong else {
            error = "Пароль должен содержать заглавные и строчные буквы, цифры и быть не короче 8 символов"
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            guard let token = appState.token else {
                error = "Сессия истекла"
                return
            }
            try await PasswordService.changePassword(old: oldPwd,
                                                     new: newPwd,
                                                     token: token)

            dismiss()
            appState.logout()
        } catch is PasswordService.PasswordError {
            error = "Неверный текущий пароль"
        } catch PasswordService.ServiceError.noConnection {
            error = "Отсутствует подключение к интернету"
        } catch {
            self.error = "Не удалось сменить пароль"
        }
    }

    private func evaluateStrength(_ pwd: String) -> PasswordStrength {
        let lengthScore = pwd.count >= 12 ? 1 : 0
        let upper  = pwd.range(of: "[A-Z]", options: .regularExpression) != nil ? 1 : 0
        let lower  = pwd.range(of: "[a-z]", options: .regularExpression) != nil ? 1 : 0
        let digit  = pwd.range(of: "[0-9]", options: .regularExpression) != nil ? 1 : 0
        let special = pwd.range(of: "[!@#$%^&*()_+=-]", options: .regularExpression) != nil ? 1 : 0
        let score = lengthScore + upper + lower + digit + special
        switch score {
        case 0...2: return .weak
        case 3...4: return .medium
        default:    return .strong
        }
    }
}
