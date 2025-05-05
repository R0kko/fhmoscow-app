import SwiftUI

struct AuthView: View {
    // MARK: - Dependencies
    @EnvironmentObject private var appState: AppState

    // MARK: - State
    @State private var phone: String = ""
    @State private var password: String = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var didAttempt = false
    @State private var shake = false
    private let gradient = LinearGradient(
        gradient: Gradient(stops: [
            .init(color: Color(hex: 0x122859).opacity(0.5), location: 0),            // Dark blue
            .init(color: Color(hex: 0x0E3869).opacity(0.5), location: 0.1),         // Blue
            .init(color: Color(hex: 0x459EDB).opacity(0.5), location: 0.7),         // Light blue
            .init(color: Color(hex: 0xC5181D, alpha: 0.25), location: 1) // Subtle red tint
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    @State private var cardScale: CGFloat = 0.9
    @FocusState private var focusedField: Field?

    enum Field { case phone, password }

    // MARK: - Validation
    private var isPhoneValid: Bool {
        phone.filter { $0.isNumber }.count == 11
    }
    private var isPasswordValid: Bool { password.count >= 6 }
    private var canSubmit: Bool { isPhoneValid && isPasswordValid && !isLoading }

    var body: some View {
        NavigationStack {
            VStack {
                Spacer(minLength: 60)

                // Card
                VStack(spacing: 20) {
                    title
                    phoneField
                    passwordField
                    submitButton
                    if let message = errorMessage { errorLabel(message) }
                }
                .scaleEffect(cardScale)
                .offset(x: shake ? -10 : 0)
                .animation(.default, value: shake)
                .onAppear {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        cardScale = 1
                    }
                }
                .padding(24)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)
                .padding(.horizontal, 24)
                .animation(.easeInOut, value: isLoading)
                .opacity(isLoading ? 0.6 : 1)

                Spacer()
            }
            .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Готово") { hideKeyboard() } } }
            .background(gradient.ignoresSafeArea())
        }
    }

    // MARK: - Subviews
    private var title: some View {
        VStack(spacing: 4) {
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 80)
                .shadow(radius: 1)
            Text("Авторизация в системе")
                .font(.title2.weight(.bold))
        }
        .padding(.bottom, 12)
    }

    private var phoneField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Телефон")
                .font(.caption)
                .foregroundColor(.secondary)
            TextField("+7 (___) ___‑__‑__", text: $phone)
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
                .focused($focusedField, equals: .phone)
                .disabled(isLoading)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 8).stroke(borderColor(isValid: isPhoneValid, currentText: phone)))
                .onChange(of: phone) { _, newValue in
                    phone = formatPhone(newValue)
                }
        }
    }

    private var passwordField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Пароль")
                .font(.caption)
                .foregroundColor(.secondary)
            SecureField("Минимум 6 символов", text: $password)
                .textContentType(.password)
                .focused($focusedField, equals: .password)
                .disabled(isLoading)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 8).stroke(borderColor(isValid: isPasswordValid, currentText: password)))
        }
    }

    private var submitButton: some View {
        Button {
            login()
        } label: {
            ZStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Text("Войти")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(canSubmit ? Color.accentColor : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(8)
            .shadow(radius: canSubmit ? 4 : 0)
        }
        .disabled(!canSubmit)
        .animation(.easeInOut, value: canSubmit)
    }

    private func errorLabel(_ text: String) -> some View {
        Text(text)
            .foregroundColor(.red)
            .multilineTextAlignment(.center)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
            .animation(.spring(), value: errorMessage)
    }

    private func borderColor(isValid: Bool, currentText: String) -> Color {
        if !didAttempt { return Color.secondary.opacity(0.3) }
        return isValid ? Color.accentColor.opacity(0.7) : .red
    }

    // MARK: - Actions
    private func login() {
        hideKeyboard()
        didAttempt = true
        // локальная валидация до запроса
        if !canSubmit {
            withAnimation { shake.toggle() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation { shake.toggle() }
            }
            return
        }
        errorMessage = nil
        isLoading = true
        Task {
            do {
                let digits = phone.filter { $0.isNumber }
                let (token, dto) = try await API.login(phone: digits, password: password)

                let roles = dto.roles?.map { Role(name: $0.name, alias: $0.alias) } ?? []

                let dob: Date? = {
                    guard let iso = dto.date_of_birth else { return nil }
                    return ISO8601DateFormatter().date(from: iso)
                }()

                let user = User(id: dto.id,
                                firstName: dto.first_name,
                                lastName: dto.last_name,
                                middleName: dto.middle_name,
                                dateOfBirth: dob,
                                email: dto.email,
                                phone: dto.phone,
                                roles: roles)
                await MainActor.run {
                    appState.saveSession(token: token, user: user)
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    handle(error)
                    isLoading = false
                }
            }
        }
    }

    private func handle(_ error: Error) {
        if let apiErr = error as? APIError {
            switch apiErr {
            case .invalidCredentials:
                errorMessage = "Неверный телефон или пароль"
            case .noConnection:
                errorMessage = "Отсутствует подключение к интернету"
            case .serverStatus(let code):
                errorMessage = "Ошибка сервера (код: \(code))"
            default:
                errorMessage = "Неизвестная ошибка. Попробуйте позже"
            }
        } else {
            errorMessage = "Неизвестная ошибка. Попробуйте позже"
        }
        Logger.shared.error("Auth failed: \(error.localizedDescription)")
    }
}

// MARK: - Helpers
private extension String {
    func matches(_ regex: String) -> Bool {
        range(of: regex, options: .regularExpression) != nil
    }
}

#if canImport(UIKit)
private extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
#endif

#Preview {
    AuthView().environmentObject(AppState())
}

private extension AuthView {
    func formatPhone(_ value: String) -> String {
        let digits = value.filter { $0.isNumber }
        // Ensure starts with 7
        let withoutFirst = digits.hasPrefix("8") ? "7" + digits.dropFirst() : digits
        let normalized = withoutFirst.hasPrefix("7") ? withoutFirst : "7" + withoutFirst
        let limited = String(normalized.prefix(11))
        // Format as +7 (XXX) XXX-XX-XX
        var result = "+7"
        let numbers = limited.dropFirst()
        let chars = Array(numbers)
        if chars.count > 0 {
            result += " ("
        }
        for (i, c) in chars.enumerated() {
            switch i {
            case 0...2:
                result += String(c)
                if i == 2 { result += ") " }
            case 3...5:
                result += String(c)
                if i == 5 { result += "‑" }
            case 6...7:
                result += String(c)
                if i == 7 { result += "‑" }
            case 8...9:
                result += String(c)
            default:
                break
            }
        }
        return result
    }
}


// MARK: - Color Hex Initializer
extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}
