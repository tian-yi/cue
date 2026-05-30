import Foundation
import XCTest
@testable import Cue

@MainActor
final class RemoteControlServerTests: XCTestCase {
    func testRemoteServerServesStateWithTokenAndRejectsMissingToken() async throws {
        let appModel = AppModel()
        let server = RemoteControlServer(appModel: appModel)
        let port = 49_152 + Int.random(in: 0..<1_000)
        let status = try await server.start(port: port)

        do {
            let state = try await fetchState(port: port, token: status.token)

            XCTAssertFalse(state.hasVideo)
            XCTAssertEqual(state.appName, "Cue")
            XCTAssertEqual(state.selectedQuality, appModel.downloadQuality)

            let rejectedStatus = try await httpStatusCode(URL(string: "http://127.0.0.1:\(port)/api/state")!)
            XCTAssertEqual(rejectedStatus, 401)

            let rejectedSearchStatus = try await httpStatusCode(
                URL(string: "http://127.0.0.1:\(port)/api/search")!,
                method: "POST",
                body: Data(#"{"query":"ballet"}"#.utf8)
            )
            XCTAssertEqual(rejectedSearchStatus, 401)

            let rejectedPlayStatus = try await httpStatusCode(
                URL(string: "http://127.0.0.1:\(port)/api/play")!,
                method: "POST",
                body: Data(#"{"videoID":"abc123DEF45"}"#.utf8)
            )
            XCTAssertEqual(rejectedPlayStatus, 401)
        } catch {
            await server.stop()
            throw error
        }

        await server.stop()
    }

    private func fetchState(port: Int, token: String?) async throws -> RemotePlaybackState {
        let token = try XCTUnwrap(token)
        let url = URL(string: "http://127.0.0.1:\(port)/api/state?t=\(token)")!
        var lastError: Error?

        for _ in 0..<20 {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                let httpResponse = try XCTUnwrap(response as? HTTPURLResponse)
                if httpResponse.statusCode == 200 {
                    return try JSONDecoder().decode(RemotePlaybackState.self, from: data)
                }
                XCTFail("Unexpected status code \(httpResponse.statusCode)")
                break
            } catch {
                lastError = error
                try await Task.sleep(nanoseconds: 100_000_000)
            }
        }

        throw lastError ?? URLError(.cannotConnectToHost)
    }

    private func httpStatusCode(
        _ url: URL,
        method: String = "GET",
        body: Data? = nil
    ) async throws -> Int {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "content-type")
        }

        let (_, response) = try await URLSession.shared.data(for: request)
        let httpResponse = try XCTUnwrap(response as? HTTPURLResponse)
        return httpResponse.statusCode
    }
}
