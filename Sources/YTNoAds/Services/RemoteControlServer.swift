import AppKit
import Combine
import Foundation
import Hummingbird
import HummingbirdWebSocket
import HTTPTypes
import Logging
import NIOCore

final class RemoteControlServer: @unchecked Sendable {
    private weak var appModel: AppModel?
    private var applicationTask: Task<Void, Never>?
    private var token: String?
    private let broadcaster = RemoteStateBroadcaster()

    init(appModel: AppModel) {
        self.appModel = appModel
    }

    func start(port: Int) async throws -> RemoteServerStatus {
        let token = Self.makeToken()
        self.token = token

        let router = Router(context: BasicRequestContext.self)
        router.get("/") { _, _ in
            RemoteHTMLResponse.html(Self.indexHTML)
        }
        router.get("app.css") { _, _ in
            RemoteHTMLResponse.css(Self.css)
        }
        router.get("app.js") { _, _ in
            RemoteHTMLResponse.javascript(Self.javascript)
        }
        router.get("api/state") { [weak self] request, _ async throws -> RemotePlaybackState in
            guard let self else {
                throw HTTPError(.serviceUnavailable, message: "Remote server is unavailable.")
            }
            try self.validateToken(request)
            return await MainActor.run {
                self.appModel?.remoteStateSnapshot() ?? .empty(selectedQuality: .fastStart, volume: 0)
            }
        }
        router.post("api/control") { [weak self] request, context async throws -> RemoteCommandResponse in
            guard let self else {
                throw HTTPError(.serviceUnavailable, message: "Remote server is unavailable.")
            }
            try self.validateToken(request)
            let command = try await request.decode(as: RemoteControlCommand.self, context: context)
            let state = await MainActor.run {
                self.appModel?.handleRemoteCommand(command) ?? .empty(selectedQuality: .fastStart, volume: 0)
            }
            await self.broadcaster.publish(state)
            return RemoteCommandResponse(ok: true, state: state)
        }
        router.post("api/search") { [weak self] request, context async throws -> RemoteSearchResponse in
            guard let self else {
                throw HTTPError(.serviceUnavailable, message: "Remote server is unavailable.")
            }
            try self.validateToken(request)
            let searchRequest = try await request.decode(as: RemoteSearchRequest.self, context: context)
            guard let appModel = self.appModel else {
                throw HTTPError(.serviceUnavailable, message: "Remote app model is unavailable.")
            }
            let results = try await appModel.search(query: searchRequest.query)
            return RemoteSearchResponse(results: results)
        }
        router.post("api/play") { [weak self] request, context async throws -> RemoteCommandResponse in
            guard let self else {
                throw HTTPError(.serviceUnavailable, message: "Remote server is unavailable.")
            }
            try self.validateToken(request)
            let playRequest = try await request.decode(as: RemotePlayRequest.self, context: context)
            let state = try await self.playRemoteResult(videoID: playRequest.videoID)
            await self.broadcaster.publish(state)
            return RemoteCommandResponse(ok: true, state: state)
        }

        let wsRouter = Router(context: BasicWebSocketRequestContext.self)
        wsRouter.ws("ws") { [weak self] request, _ in
            guard let self else {
                return .dontUpgrade
            }
            return self.isAuthorized(request) ? .upgrade([:]) : .dontUpgrade
        } onUpgrade: { [weak self] inbound, outbound, _ in
            guard let self else { return }
            await self.broadcaster.addClient()
            await self.updateConnectedClientCount()

            do {
                let initialState = await MainActor.run {
                    self.appModel?.remoteStateSnapshot() ?? .empty(selectedQuality: .fastStart, volume: 0)
                }
                let stream = await self.broadcaster.subscribe(initialState: initialState)

                try await withThrowingTaskGroup(of: Void.self) { group in
                    group.addTask {
                        for try await _ in inbound.messages(maxSize: 64 * 1024) {}
                    }
                    group.addTask {
                        for await state in stream {
                            let data = try JSONEncoder.remote.encode(state)
                            if let text = String(data: data, encoding: .utf8) {
                                try await outbound.write(.text(text))
                            }
                        }
                    }
                    try await group.next()
                    group.cancelAll()
                }
            } catch {
                // Connection cleanup happens below; transient browser disconnects are expected.
            }

            await self.broadcaster.removeClient()
            await self.updateConnectedClientCount()
        }

        var logger = Logger(label: "YTNoAds.RemoteControl")
        logger.logLevel = .info

        let app = Application(
            router: router,
            server: .http1WebSocketUpgrade(webSocketRouter: wsRouter),
            configuration: .init(
                address: .hostname("0.0.0.0", port: port),
                serverName: "YTNoAdsRemote"
            ),
            logger: logger
        )

        applicationTask = Task {
            do {
                try await app.runService(gracefulShutdownSignals: [])
            } catch is CancellationError {
            } catch {
                await MainActor.run {
                    self.appModel?.remoteServerStatus.errorMessage = error.localizedDescription
                }
            }
        }

        return await MainActor.run {
            RemoteServerStatus(
                isEnabled: true,
                isStarting: false,
                port: port,
                token: token,
                localURLs: Self.localRemoteURLs(port: port, token: token),
                connectedClients: 0,
                errorMessage: nil
            )
        }
    }

    func stop() async {
        applicationTask?.cancel()
        applicationTask = nil
        token = nil
        await broadcaster.finish()
    }

    func publish(_ state: RemotePlaybackState) async {
        await broadcaster.publish(state)
    }

    private func validateToken(_ request: Request) throws {
        guard isAuthorized(request) else {
            throw HTTPError(.unauthorized, message: "Pair this device from the Mac app first.")
        }
    }

    private func playRemoteResult(videoID: String) async throws -> RemotePlaybackState {
        try await MainActor.run {
            guard let appModel = self.appModel else {
                throw HTTPError(.serviceUnavailable, message: "Remote app model is unavailable.")
            }

            guard let video = appModel.results.first(where: { $0.id == videoID }) else {
                throw HTTPError(.notFound, message: "Search result is no longer available.")
            }

            appModel.selectAndDownload(video)
            return appModel.remoteStateSnapshot()
        }
    }

    private func isAuthorized(_ request: Request) -> Bool {
        guard let token else {
            return false
        }

        if request.uri.queryParameters["t"].map(String.init) == token {
            return true
        }

        if let header = request.headers[.authorization],
           header == "Bearer \(token)" {
            return true
        }

        return false
    }

    private func updateConnectedClientCount() async {
        let count = await broadcaster.connectedClientCount
        await MainActor.run {
            guard var status = self.appModel?.remoteServerStatus else {
                return
            }
            status.connectedClients = count
            self.appModel?.setRemoteServerStatus(status)
        }
    }

    private static func makeToken() -> String {
        var bytes = [UInt8](repeating: 0, count: 18)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)

        if status == errSecSuccess {
            return Data(bytes).base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        }

        return UUID().uuidString.replacingOccurrences(of: "-", with: "")
    }

    private static func localRemoteURLs(port: Int, token: String) -> [URL] {
        var urls: [URL] = []
        let encodedToken = token.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? token

        if let hostName = Host.current().name, !hostName.isEmpty {
            let localName = hostName.hasSuffix(".local") ? String(hostName.dropLast(6)) : hostName
            if let url = URL(string: "http://\(localName).local:\(port)/?t=\(encodedToken)") {
                urls.append(url)
            }
        }

        for address in IPv4AddressResolver.localAddresses() {
            if let url = URL(string: "http://\(address):\(port)/?t=\(encodedToken)") {
                urls.append(url)
            }
        }

        if urls.isEmpty, let url = URL(string: "http://localhost:\(port)/?t=\(encodedToken)") {
            urls.append(url)
        }

        return urls
    }
}

actor RemoteStateBroadcaster {
    private var continuations: [UUID: AsyncStream<RemotePlaybackState>.Continuation] = [:]
    private var clientCount = 0

    var connectedClientCount: Int {
        clientCount
    }

    func addClient() {
        clientCount += 1
    }

    func removeClient() {
        clientCount = max(0, clientCount - 1)
    }

    func subscribe(initialState: RemotePlaybackState) -> AsyncStream<RemotePlaybackState> {
        let id = UUID()

        return AsyncStream { continuation in
            continuations[id] = continuation
            continuation.yield(initialState)
            continuation.onTermination = { [weak self] _ in
                Task {
                    await self?.removeSubscription(id)
                }
            }
        }
    }

    func publish(_ state: RemotePlaybackState) {
        for continuation in continuations.values {
            continuation.yield(state)
        }
    }

    func finish() {
        for continuation in continuations.values {
            continuation.finish()
        }
        continuations.removeAll()
        clientCount = 0
    }

    private func removeSubscription(_ id: UUID) {
        continuations[id] = nil
    }
}

struct RemoteHTMLResponse: ResponseGenerator {
    let status: HTTPResponse.Status
    let contentType: String
    let body: String

    static func html(_ body: String) -> RemoteHTMLResponse {
        RemoteHTMLResponse(status: .ok, contentType: "text/html; charset=utf-8", body: body)
    }

    static func css(_ body: String) -> RemoteHTMLResponse {
        RemoteHTMLResponse(status: .ok, contentType: "text/css; charset=utf-8", body: body)
    }

    static func javascript(_ body: String) -> RemoteHTMLResponse {
        RemoteHTMLResponse(status: .ok, contentType: "application/javascript; charset=utf-8", body: body)
    }

    func response(from request: Request, context: some RequestContext) -> Response {
        let buffer = ByteBuffer(string: body)
        return Response(
            status: status,
            headers: [
                .contentType: contentType,
                .cacheControl: "no-store"
            ],
            body: .init(byteBuffer: buffer)
        )
    }
}

private extension JSONEncoder {
    static var remote: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        return encoder
    }
}
