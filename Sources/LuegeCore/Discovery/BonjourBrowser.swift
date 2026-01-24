import Foundation
import Network

/// Discovers SMB hosts on the local network using Bonjour/mDNS
public final class BonjourBrowser: HostDiscovering, @unchecked Sendable {
    private var browser: NWBrowser?
    private let queue = DispatchQueue(label: "com.luege.bonjour", qos: .userInitiated)
    private var continuation: AsyncStream<DiscoveredHost>.Continuation?

    public init() {}

    public func discoverHosts() -> AsyncStream<DiscoveredHost> {
        AsyncStream { [weak self] continuation in
            self?.continuation = continuation
            self?.startBrowsing(continuation: continuation)

            continuation.onTermination = { [weak self] _ in
                self?.stopDiscovery()
            }
        }
    }

    private func startBrowsing(continuation: AsyncStream<DiscoveredHost>.Continuation) {
        let browser = NWBrowser(
            for: .bonjour(type: "_smb._tcp", domain: "local"),
            using: .tcp
        )

        browser.browseResultsChangedHandler = { [weak self] results, changes in
            self?.handleResults(results, continuation: continuation)
        }

        browser.stateUpdateHandler = { state in
            switch state {
            case .failed(let error):
                print("Browser failed: \(error)")
                continuation.finish()
            case .cancelled:
                continuation.finish()
            default:
                break
            }
        }

        self.browser = browser
        browser.start(queue: queue)
    }

    private func handleResults(
        _ results: Set<NWBrowser.Result>,
        continuation: AsyncStream<DiscoveredHost>.Continuation
    ) {
        for result in results {
            guard case .service(let name, _, _, _) = result.endpoint else {
                continue
            }

            // Resolve the endpoint to get the IP address
            resolveEndpoint(result.endpoint, name: name, continuation: continuation)
        }
    }

    private func resolveEndpoint(
        _ endpoint: NWEndpoint,
        name: String,
        continuation: AsyncStream<DiscoveredHost>.Continuation
    ) {
        let parameters = NWParameters.tcp
        let connection = NWConnection(to: endpoint, using: parameters)

        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                if let innerEndpoint = connection.currentPath?.remoteEndpoint,
                   case .hostPort(let host, _) = innerEndpoint {
                    let address = self?.extractAddress(from: host) ?? ""
                    if !address.isEmpty {
                        let discoveredHost = DiscoveredHost(name: name, address: address)
                        continuation.yield(discoveredHost)
                    }
                }
                connection.cancel()
            case .failed, .cancelled:
                connection.cancel()
            default:
                break
            }
        }

        connection.start(queue: queue)

        // Timeout for resolution
        queue.asyncAfter(deadline: .now() + 5) {
            if connection.state != .cancelled {
                connection.cancel()
            }
        }
    }

    private func extractAddress(from host: NWEndpoint.Host) -> String {
        switch host {
        case .ipv4(let address):
            return "\(address)"
        case .ipv6(let address):
            return "\(address)"
        case .name(let name, _):
            return name
        @unknown default:
            return ""
        }
    }

    public func stopDiscovery() {
        browser?.cancel()
        browser = nil
        continuation?.finish()
        continuation = nil
    }
}
