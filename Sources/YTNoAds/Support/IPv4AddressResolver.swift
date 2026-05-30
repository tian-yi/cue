import Foundation

enum IPv4AddressResolver {
    static func localAddresses() -> [String] {
        var addresses: [String] = []
        var interfacePointer: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&interfacePointer) == 0, let firstInterface = interfacePointer else {
            return addresses
        }

        defer {
            freeifaddrs(interfacePointer)
        }

        for pointer in sequence(first: firstInterface, next: { $0.pointee.ifa_next }) {
            let interface = pointer.pointee
            let flags = Int32(interface.ifa_flags)
            let isUp = (flags & IFF_UP) == IFF_UP
            let isLoopback = (flags & IFF_LOOPBACK) == IFF_LOOPBACK

            guard isUp, !isLoopback, interface.ifa_addr.pointee.sa_family == UInt8(AF_INET) else {
                continue
            }

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result = getnameinfo(
                interface.ifa_addr,
                socklen_t(interface.ifa_addr.pointee.sa_len),
                &hostname,
                socklen_t(hostname.count),
                nil,
                0,
                NI_NUMERICHOST
            )

            if result == 0 {
                addresses.append(String(cString: hostname))
            }
        }

        return Array(Set(addresses)).sorted()
    }
}
