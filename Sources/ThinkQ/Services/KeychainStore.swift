import Foundation
import Security

struct KeychainStore: Sendable {
    let service: String

    func string(for account: String) throws -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
        guard let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    func setString(_ value: String, for account: String) throws {
        let data = Data(value.utf8)
        var query = baseQuery(account: account)
        let deleteStatus = SecItemDelete(query as CFDictionary)
        guard deleteStatus == errSecSuccess || deleteStatus == errSecItemNotFound else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(deleteStatus))
        }

        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        if let access = Self.currentAppAccess(label: service) {
            query[kSecAttrAccess as String] = access
        }

        let addStatus = SecItemAdd(query as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(addStatus))
        }
    }

    func remove(account: String) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    private static func currentAppAccess(label: String) -> SecAccess? {
        guard let executablePath = Bundle.main.executableURL?.path else { return nil }

        var trustedApplication: SecTrustedApplication?
        let trustedStatus = SecTrustedApplicationCreateFromPath(executablePath, &trustedApplication)
        guard trustedStatus == errSecSuccess, let trustedApplication else { return nil }

        var access: SecAccess?
        let accessStatus = SecAccessCreate(
            "\(label) token" as CFString,
            [trustedApplication] as CFArray,
            &access
        )
        guard accessStatus == errSecSuccess else { return nil }
        return access
    }
}
