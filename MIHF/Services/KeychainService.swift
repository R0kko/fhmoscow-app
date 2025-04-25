import Foundation
import Security

enum KeychainError: Error {
    case itemNotFound
    case unexpectedData
    case unhandled(OSStatus)
}

struct KeychainService {
    private let service = "com.yourcompany.yourapp"
    private let account = "jwt"

    // MARK: - Save / Update
    func save(token: String) throws {
        let data = Data(token.utf8)

        // Сначала пробуем обновить, если уже есть
        let query: [CFString: Any] = [
            kSecClass:           kSecClassGenericPassword,
            kSecAttrService:     service,
            kSecAttrAccount:     account
        ]
        let attrs: [CFString: Any] = [kSecValueData: data]

        let status = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)

        if status == errSecItemNotFound {
            // если нет — добавляем
            var addQuery = query
            addQuery[kSecValueData] = data
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw KeychainError.unhandled(addStatus) }
        } else if status != errSecSuccess {
            throw KeychainError.unhandled(status)
        }
    }

    // MARK: - Read
    func readToken() throws -> String {
        let query: [CFString: Any] = [
            kSecClass:           kSecClassGenericPassword,
            kSecAttrService:     service,
            kSecAttrAccount:     account,
            kSecReturnData:      true,
            kSecMatchLimit:      kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            guard
                let data = item as? Data,
                let token = String(data: data, encoding: .utf8)
            else { throw KeychainError.unexpectedData }
            return token

        case errSecItemNotFound:
            throw KeychainError.itemNotFound

        default:
            throw KeychainError.unhandled(status)
        }
    }

    // MARK: - Delete
    func deleteToken() throws {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound
        else { throw KeychainError.unhandled(status) }
    }
}
