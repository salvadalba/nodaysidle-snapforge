import Foundation
import Network
import Security
import OSLog

private let logger = Logger(subsystem: "com.snapforge", category: "AutomationBridge")

// MARK: - HTTPRequest

private struct HTTPRequest: Sendable {
    let method: String
    let path: String
    let query: [String: String]
    let body: Data?
    let authorization: String?

    init(rawRequest: String, body: Data?) {
        var lines = rawRequest.components(separatedBy: "\r\n")
        let requestLine = lines.first ?? ""
        let parts = requestLine.components(separatedBy: " ")
        self.method = parts.count > 0 ? parts[0] : "GET"

        let rawPath = parts.count > 1 ? parts[1] : "/"
        if let questionMark = rawPath.firstIndex(of: "?") {
            self.path = String(rawPath[..<questionMark])
            let queryString = String(rawPath[rawPath.index(after: questionMark)...])
            var queryItems: [String: String] = [:]
            for pair in queryString.components(separatedBy: "&") {
                let kv = pair.components(separatedBy: "=")
                if kv.count == 2 {
                    let key   = kv[0].removingPercentEncoding ?? kv[0]
                    let value = kv[1].removingPercentEncoding ?? kv[1]
                    queryItems[key] = value
                }
            }
            self.query = queryItems
        } else {
            self.path = rawPath
            self.query = [:]
        }

        lines.removeFirst()
        var auth: String?
        for line in lines {
            if line.lowercased().hasPrefix("authorization:") {
                auth = String(line.dropFirst("authorization:".count)).trimmingCharacters(in: .whitespaces)
                break
            }
        }
        self.authorization = auth
        self.body = body
    }
}

// MARK: - AutomationBridge

/// Lightweight localhost HTTP server that exposes SnapForge functionality to
/// automation clients (Shortcuts, scripts, third-party tools) via a REST API
/// secured by a bearer token stored in Keychain.
actor AutomationBridge {

    // MARK: - Constants

    static let port: UInt16 = 48721
    private static let keychainService = "com.snapforge.automation"
    private static let keychainAccount = "bearer-token"
    private static let maxConcurrentConnections = 10

    // MARK: - Properties

    private var listener: NWListener?
    private var activeConnections: Set<ObjectIdentifier> = []
    private let captureService: any CaptureServiceProtocol
    private let libraryService: any LibraryServiceProtocol
    private let sharingService: SharingService
    private let bearerToken: String

    // MARK: - Init

    init(captureService: any CaptureServiceProtocol,
         libraryService: any LibraryServiceProtocol,
         sharingService: SharingService) {
        self.captureService = captureService
        self.libraryService = libraryService
        self.sharingService = sharingService
        self.bearerToken = Self.loadOrCreateBearerToken()
    }

    // MARK: - Lifecycle

    func start() throws {
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true

        let port = NWEndpoint.Port(rawValue: Self.port)!
        let newListener = try NWListener(using: params, on: port)

        newListener.newConnectionHandler = { [weak self] connection in
            Task { [weak self] in
                await self?.handleNewConnection(connection)
            }
        }

        newListener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                logger.info("AutomationBridge: listening on localhost:\(AutomationBridge.port)")
            case .failed(let error):
                logger.error("AutomationBridge: listener failed: \(error.localizedDescription)")
            default:
                break
            }
        }

        newListener.start(queue: .global(qos: .utility))
        self.listener = newListener
    }

    func stop() {
        listener?.cancel()
        listener = nil
        logger.info("AutomationBridge: stopped")
    }

    // MARK: - Connection Handling

    private func handleNewConnection(_ connection: NWConnection) {
        guard activeConnections.count < Self.maxConcurrentConnections else {
            connection.cancel()
            logger.warning("AutomationBridge: max connections reached, rejecting")
            return
        }

        let id = ObjectIdentifier(connection as AnyObject)
        activeConnections.insert(id)
        connection.start(queue: .global(qos: .utility))
        receiveRequest(from: connection, connectionID: id)
    }

    private func receiveRequest(from connection: NWConnection, connectionID: ObjectIdentifier) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            Task { [weak self] in
                guard let self else { return }

                if let error {
                    logger.error("AutomationBridge: receive error: \(error.localizedDescription)")
                    await self.closeConnection(connection, id: connectionID)
                    return
                }

                guard let data, !data.isEmpty else {
                    await self.closeConnection(connection, id: connectionID)
                    return
                }

                let rawHeader = String(data: data, encoding: .utf8) ?? ""
                let request = HTTPRequest(rawRequest: rawHeader, body: nil)
                let response = await self.route(request: request)
                await self.sendResponse(response, on: connection, id: connectionID)
            }
        }
    }

    private func sendResponse(_ response: String, on connection: NWConnection, id: ObjectIdentifier) {
        let responseData = response.data(using: .utf8) ?? Data()
        connection.send(content: responseData, completion: .contentProcessed { [weak self] error in
            Task { [weak self] in
                if let error {
                    logger.error("AutomationBridge: send error: \(error.localizedDescription)")
                }
                await self?.closeConnection(connection, id: id)
            }
        })
    }

    private func closeConnection(_ connection: NWConnection, id: ObjectIdentifier) {
        connection.cancel()
        activeConnections.remove(id)
    }

    // MARK: - Routing

    private func route(request: HTTPRequest) async -> String {
        // Validate bearer token
        guard isAuthorized(request.authorization) else {
            return httpResponse(status: 401, body: #"{"error":"Unauthorized"}"#)
        }

        let path = request.path
        let method = request.method

        switch (method, path) {

        // GET /api/v1/capture/types
        case ("GET", "/api/v1/capture/types"):
            return await handleGetCaptureTypes()

        // POST /api/v1/capture
        case ("POST", "/api/v1/capture"):
            return await handleTriggerCapture(request: request)

        // GET /api/v1/library/search?q=
        case ("GET", "/api/v1/library/search"):
            return await handleLibrarySearch(request: request)

        // GET /api/v1/library/captures/{id}
        case ("GET", _) where path.hasPrefix("/api/v1/library/captures/"):
            let idStr = String(path.dropFirst("/api/v1/library/captures/".count))
            return await handleFetchCapture(idString: idStr)

        // DELETE /api/v1/library/captures/{id}
        case ("DELETE", _) where path.hasPrefix("/api/v1/library/captures/"):
            let idStr = String(path.dropFirst("/api/v1/library/captures/".count))
            return await handleDeleteCapture(idString: idStr)

        // POST /api/v1/ai/explain
        case ("POST", "/api/v1/ai/explain"):
            return httpResponse(status: 200, body: #"{"result":"AI explain not yet implemented"}"#)

        // POST /api/v1/sharing/upload
        case ("POST", "/api/v1/sharing/upload"):
            return await handleSharingUpload(request: request)

        default:
            return httpResponse(status: 404, body: #"{"error":"Not found"}"#)
        }
    }

    // MARK: - Handlers

    private func handleGetCaptureTypes() async -> String {
        let types = CaptureType.allCases.map { ["id": $0.rawValue, "label": $0.displayLabel] }
        guard let data = try? JSONSerialization.data(withJSONObject: types),
              let json = String(data: data, encoding: .utf8) else {
            return httpResponse(status: 500, body: #"{"error":"Serialization failed"}"#)
        }
        return httpResponse(status: 200, body: json)
    }

    private func handleTriggerCapture(request: HTTPRequest) async -> String {
        do {
            let result = try await captureService.captureScreenshot(region: nil)
            let payload: [String: Any] = [
                "id":        result.id.uuidString,
                "type":      result.captureType.rawValue,
                "filePath":  result.filePath,
                "fileSize":  result.fileSize
            ]
            guard let data = try? JSONSerialization.data(withJSONObject: payload),
                  let json = String(data: data, encoding: .utf8) else {
                return httpResponse(status: 500, body: #"{"error":"Serialization failed"}"#)
            }
            return httpResponse(status: 200, body: json)
        } catch {
            return httpResponse(status: 500, body: #"{"error":"\#(error.localizedDescription)"}"#)
        }
    }

    private func handleLibrarySearch(request: HTTPRequest) async -> String {
        let query = request.query["q"] ?? ""
        do {
            let results = try await libraryService.search(
                query: query,
                filters: LibraryFilters(),
                sort: .relevance,
                limit: 20,
                offset: 0
            )
            let items = results.records.map { snap -> [String: Any] in
                var dict: [String: Any] = [
                    "id":          snap.id.uuidString,
                    "type":        snap.captureType,
                    "filePath":    snap.filePath,
                    "fileSize":    snap.fileSize,
                    "createdAt":   ISO8601DateFormatter().string(from: snap.createdAt)
                ]
                if let title = snap.windowTitle { dict["windowTitle"] = title }
                if let app   = snap.sourceAppName { dict["sourceApp"] = app }
                return dict
            }
            let payload: [String: Any] = ["total": results.totalCount, "items": items]
            guard let data = try? JSONSerialization.data(withJSONObject: payload),
                  let json = String(data: data, encoding: .utf8) else {
                return httpResponse(status: 500, body: #"{"error":"Serialization failed"}"#)
            }
            return httpResponse(status: 200, body: json)
        } catch {
            return httpResponse(status: 500, body: #"{"error":"\#(error.localizedDescription)"}"#)
        }
    }

    private func handleFetchCapture(idString: String) async -> String {
        guard let uuid = UUID(uuidString: idString) else {
            return httpResponse(status: 400, body: #"{"error":"Invalid UUID"}"#)
        }
        do {
            guard let snap = try await libraryService.fetch(id: uuid) else {
                return httpResponse(status: 404, body: #"{"error":"Not found"}"#)
            }
            let payload: [String: Any] = [
                "id":          snap.id.uuidString,
                "type":        snap.captureType,
                "filePath":    snap.filePath,
                "fileSize":    snap.fileSize,
                "isStarred":   snap.isStarred,
                "tags":        snap.tagArray,
                "createdAt":   ISO8601DateFormatter().string(from: snap.createdAt)
            ]
            guard let data = try? JSONSerialization.data(withJSONObject: payload),
                  let json = String(data: data, encoding: .utf8) else {
                return httpResponse(status: 500, body: #"{"error":"Serialization failed"}"#)
            }
            return httpResponse(status: 200, body: json)
        } catch {
            return httpResponse(status: 500, body: #"{"error":"\#(error.localizedDescription)"}"#)
        }
    }

    private func handleDeleteCapture(idString: String) async -> String {
        guard let uuid = UUID(uuidString: idString) else {
            return httpResponse(status: 400, body: #"{"error":"Invalid UUID"}"#)
        }
        do {
            try await libraryService.delete(id: uuid, deleteFile: true)
            return httpResponse(status: 200, body: #"{"deleted":true}"#)
        } catch {
            return httpResponse(status: 500, body: #"{"error":"\#(error.localizedDescription)"}"#)
        }
    }

    private func handleSharingUpload(request: HTTPRequest) async -> String {
        // Parse minimal JSON body: {"captureId":"...","expiryDays":7,"password":"..."}
        guard let bodyData = request.body,
              let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
              let idStr  = json["captureId"] as? String,
              let uuid   = UUID(uuidString: idStr) else {
            return httpResponse(status: 400, body: #"{"error":"Invalid request body"}"#)
        }

        let expiryDays = json["expiryDays"] as? Int ?? 7
        let password   = json["password"] as? String
        let expiry     = Date().addingTimeInterval(TimeInterval(expiryDays * 86400))

        do {
            let result = try await sharingService.upload(captureID: uuid, expiry: expiry, password: password)
            let payload: [String: Any] = [
                "shareURL":  result.shareURL.absoluteString,
                "expiry":    ISO8601DateFormatter().string(from: result.expiry),
                "encrypted": result.encrypted
            ]
            guard let data = try? JSONSerialization.data(withJSONObject: payload),
                  let responseJSON = String(data: data, encoding: .utf8) else {
                return httpResponse(status: 500, body: #"{"error":"Serialization failed"}"#)
            }
            return httpResponse(status: 200, body: responseJSON)
        } catch {
            return httpResponse(status: 500, body: #"{"error":"\#(error.localizedDescription)"}"#)
        }
    }

    // MARK: - URL Scheme Handling

    /// Parses a `snapforge://` x-callback-url and maps it to an internal action.
    func handleURLScheme(_ url: URL) async {
        guard url.scheme == "snapforge" else { return }

        let host    = url.host ?? ""
        let params  = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let paramDict = Dictionary(uniqueKeysWithValues: params.compactMap { item -> (String, String)? in
            guard let value = item.value else { return nil }
            return (item.name, value)
        })

        logger.info("AutomationBridge: handling URL scheme \(url.absoluteString)")

        switch host {
        case "capture":
            _ = try? await captureService.captureScreenshot(region: nil)
        case "search":
            let query = paramDict["q"] ?? ""
            _ = try? await libraryService.search(query: query, filters: LibraryFilters(), sort: .relevance, limit: 20, offset: 0)
        default:
            logger.warning("AutomationBridge: unknown URL scheme host '\(host)'")
        }
    }

    // MARK: - Auth

    private func isAuthorized(_ authHeader: String?) -> Bool {
        guard let authHeader else { return false }
        let prefix = "Bearer "
        guard authHeader.hasPrefix(prefix) else { return false }
        let token = String(authHeader.dropFirst(prefix.count))
        return token == bearerToken
    }

    // MARK: - Token Management

    private static func loadOrCreateBearerToken() -> String {
        if let existing = keychainLoad() { return existing }
        let token = generateToken()
        keychainStore(token: token)
        logger.info("AutomationBridge: generated new bearer token")
        return token
    }

    private static func generateToken() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    private static func keychainStore(token: String) {
        guard let data = token.data(using: .utf8) else { return }
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: keychainAccount,
            kSecValueData:   data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func keychainLoad() -> String? {
        let query: [CFString: Any] = [
            kSecClass:        kSecClassGenericPassword,
            kSecAttrService:  keychainService,
            kSecAttrAccount:  keychainAccount,
            kSecReturnData:   true,
            kSecMatchLimit:   kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - HTTP Helpers

    private func httpResponse(status: Int, body: String) -> String {
        let statusText: String
        switch status {
        case 200: statusText = "OK"
        case 400: statusText = "Bad Request"
        case 401: statusText = "Unauthorized"
        case 404: statusText = "Not Found"
        case 500: statusText = "Internal Server Error"
        default:  statusText = "Unknown"
        }
        let bodyData = body.data(using: .utf8) ?? Data()
        return """
        HTTP/1.1 \(status) \(statusText)\r\n\
        Content-Type: application/json\r\n\
        Content-Length: \(bodyData.count)\r\n\
        Connection: close\r\n\
        \r\n\
        \(body)
        """
    }
}

// MARK: - CaptureType Display

private extension CaptureType {
    var displayLabel: String {
        switch self {
        case .screenshot: return "Screenshot"
        case .scrolling:  return "Scrolling"
        case .video:      return "Video"
        case .gif:        return "GIF"
        case .ocr:        return "OCR"
        case .pin:        return "Pin"
        }
    }
}

// MARK: - CaptureRecordSnapshot convenience

private extension CaptureRecordSnapshot {
    var tagArray: [String] {
        tags.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
