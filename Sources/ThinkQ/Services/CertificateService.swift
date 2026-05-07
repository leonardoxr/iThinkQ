import Foundation

struct ClientCertificateBundle: Sendable {
    var privateKeyPEM: String
    var csrBody: String
    var certificatePEM: String?
    var subscriptions: [String]
}

enum CertificateServiceError: LocalizedError {
    case opensslFailed(String)
    case missingCSR

    var errorDescription: String? {
        switch self {
        case .opensslFailed(let message): "OpenSSL CSR generation failed: \(message)"
        case .missingCSR: "CSR output was empty."
        }
    }
}

struct CertificateService: Sendable {
    func generateCSR(commonName: String = "lg_thinq") throws -> ClientCertificateBundle {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let keyURL = directory.appendingPathComponent("client.key")
        let csrURL = directory.appendingPathComponent("client.csr")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/openssl")
        process.arguments = [
            "req", "-new", "-newkey", "rsa:2048", "-nodes",
            "-keyout", keyURL.path,
            "-out", csrURL.path,
            "-subj", "/CN=\(commonName)"
        ]

        let errorPipe = Pipe()
        process.standardError = errorPipe
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw CertificateServiceError.opensslFailed(message)
        }

        let key = try String(contentsOf: keyURL, encoding: .utf8)
        let csr = try String(contentsOf: csrURL, encoding: .utf8)
        let body = csr
            .replacingOccurrences(of: "-----BEGIN CERTIFICATE REQUEST-----", with: "")
            .replacingOccurrences(of: "-----END CERTIFICATE REQUEST-----", with: "")
            .components(separatedBy: .whitespacesAndNewlines)
            .joined()

        guard !body.isEmpty else { throw CertificateServiceError.missingCSR }
        return ClientCertificateBundle(privateKeyPEM: key, csrBody: body, certificatePEM: nil, subscriptions: [])
    }
}
