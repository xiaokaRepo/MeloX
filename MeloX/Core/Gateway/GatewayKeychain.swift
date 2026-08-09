import Foundation
import Security

nonisolated struct GatewayKeychain: Sendable {
    private let service = "com.melox.gateway"
    private let account = "client-token"

#if targetEnvironment(simulator)
    private let simulatorFallbackKey = "melox.gateway.client-token.simulator"
#endif

    func readToken() -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecSuccess,
           let data = item as? Data {
            return String(data: data, encoding: .utf8)
        }
#if targetEnvironment(simulator)
        if status == errSecMissingEntitlement {
            return UserDefaults.standard.string(forKey: simulatorFallbackKey)
        }
#endif
        return nil
    }

    func saveToken(_ token: String) throws {
        let data = Data(token.utf8)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]
        let attributes: [CFString: Any] = [kSecValueData: data]
        let updateStatus = SecItemUpdate(
            query as CFDictionary,
            attributes as CFDictionary
        )

        if updateStatus == errSecMissingEntitlement {
#if targetEnvironment(simulator)
            UserDefaults.standard.set(token, forKey: simulatorFallbackKey)
            return
#else
            throw GatewayKeychainError(status: updateStatus)
#endif
        } else if updateStatus == errSecItemNotFound {
            var insertion = query
            insertion[kSecValueData] = data
            insertion[kSecAttrAccessible] =
                kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let status = SecItemAdd(insertion as CFDictionary, nil)
            if status == errSecMissingEntitlement {
#if targetEnvironment(simulator)
                UserDefaults.standard.set(token, forKey: simulatorFallbackKey)
                return
#else
                throw GatewayKeychainError(status: status)
#endif
            }
            guard status == errSecSuccess else {
                throw GatewayKeychainError(status: status)
            }
        } else if updateStatus != errSecSuccess {
            throw GatewayKeychainError(status: updateStatus)
        }
    }
}

private nonisolated struct GatewayKeychainError: LocalizedError {
    let status: OSStatus

    var errorDescription: String? {
        "无法保存 Gateway Token（Keychain 错误 \(status)）"
    }
}
