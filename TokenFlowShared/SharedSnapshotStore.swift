import Foundation

enum SharedSnapshotStore {
    static let fileName = "usage-snapshot.json"
    static let appGroup = "MKAFV9VL9V.com.adriendonot.tokenflow"

    static func read() -> TokenFlowSnapshot {
        for url in candidateURLs() {
            guard let data = try? Data(contentsOf: url) else { continue }
            if let snapshot = try? JSONDecoder.tokenFlow.decode(TokenFlowSnapshot.self, from: data) {
                return snapshot
            }
        }
        return .empty
    }

    static func write(_ snapshot: TokenFlowSnapshot) {
        guard let data = try? JSONEncoder.tokenFlow.encode(snapshot) else { return }
        for url in candidateURLs() {
            do {
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try data.write(to: url, options: .atomic)
                NSLog("TokenFlow snapshot wrote %@", url.path)
            } catch {
                NSLog("TokenFlow snapshot write failed at %@: %@", url.path, error.localizedDescription)
            }
        }
    }

    private static func candidateURLs() -> [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        var urls: [URL] = []
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) {
            urls.append(groupURL.appendingPathComponent("Library/Application Support/TokenFlow/\(fileName)"))
        }
        urls.append(URL(fileURLWithPath: "\(home.path)/Library/Group Containers/\(appGroup)/Library/Application Support/TokenFlow/\(fileName)"))
        urls.append(contentsOf: [
            URL(fileURLWithPath: "\(home.path)/Library/Application Support/TokenFlow/\(fileName)"),
            URL(fileURLWithPath: "\(home.path)/.tokenflow/\(fileName)")
        ])
        return urls
    }
}

extension JSONDecoder {
    static var tokenFlow: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

extension JSONEncoder {
    static var tokenFlow: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
