public struct RemotePeer: Codable, Sendable, Equatable {
    public let kind: DeviceKind
    public let id: String

    public init(kind: DeviceKind, id: String) {
        self.kind = kind
        self.id = id
    }
}
