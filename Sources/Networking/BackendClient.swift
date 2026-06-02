import Foundation

/// Connects to the NestJS backend via Server-Sent Events and delivers new tasks to TaskManager.
final class BackendClient: NSObject, URLSessionDataDelegate {
    static let shared = BackendClient()

    private let streamURL = URL(string: "http://localhost:3001/tasks/stream")!
    private var session: URLSession!
    private var streamTask: URLSessionDataTask?
    private var buffer = ""

    private override init() {
        super.init()
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = .infinity
        config.timeoutIntervalForResource = .infinity
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    func connect() {
        guard streamTask == nil else { return }
        var request = URLRequest(url: streamURL)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.timeoutInterval = .infinity
        streamTask = session.dataTask(with: request)
        streamTask?.resume()
        print("[BackendClient] connecting to \(streamURL)")
    }

    func disconnect() {
        streamTask?.cancel()
        streamTask = nil
        buffer = ""
    }

    // MARK: - URLSessionDataDelegate

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask,
                    didReceive data: Data) {
        guard let chunk = String(data: data, encoding: .utf8) else { return }
        buffer += chunk
        flushBuffer()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        streamTask = nil
        buffer = ""
        guard let error = error as NSError?, error.code != NSURLErrorCancelled else { return }
        print("[BackendClient] stream ended: \(error.localizedDescription), reconnecting in 3s…")
        DispatchQueue.global().asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.connect()
        }
    }

    // MARK: - SSE Parsing

    private func flushBuffer() {
        while let range = buffer.range(of: "\n\n") {
            let block = String(buffer[buffer.startIndex..<range.lowerBound])
            buffer = String(buffer[range.upperBound...])
            parseEvent(block)
        }
    }

    private func parseEvent(_ block: String) {
        var eventName: String?
        var dataLines: [String] = []
        for line in block.components(separatedBy: "\n") {
            if line.hasPrefix("event:") {
                eventName = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("data:") {
                dataLines.append(String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces))
            }
        }

        // Only handle task creation events; ignore heartbeats, future event types, etc.
        guard eventName == "task:created" else { return }

        let json = dataLines.joined()
        guard !json.isEmpty, let data = json.data(using: .utf8) else { return }

        do {
            let decoder = JSONDecoder()
            // .iso8601 rejects fractional seconds; use a custom formatter that accepts both
            // "2026-06-02T20:53:55Z" and "2026-06-02T20:53:55.746Z" (Node's toISOString() output).
            let withMs = ISO8601DateFormatter()
            withMs.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let withoutMs = ISO8601DateFormatter()
            withoutMs.formatOptions = [.withInternetDateTime]
            decoder.dateDecodingStrategy = .custom { dec in
                let container = try dec.singleValueContainer()
                let str = try container.decode(String.self)
                if let date = withMs.date(from: str) { return date }
                if let date = withoutMs.date(from: str) { return date }
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot parse ISO8601 date: \(str)")
            }
            let task = try decoder.decode(CosmicTask.self, from: data)
            DispatchQueue.main.async {
                // Post fly-in notification before add() so CosmicScene can intercept
                // and animate instead of letting loadMeteors() do a plain fade-in.
                NotificationCenter.default.post(name: .taskReceivedFromBackend, object: task)
                TaskManager.shared.add(task)
            }
        } catch {
            print("[BackendClient] decode error: \(error)\njson: \(json)")
        }
    }
}
