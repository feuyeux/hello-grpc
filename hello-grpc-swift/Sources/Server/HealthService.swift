import GRPCCore

struct HealthService: RegistrableRPCService {
    private static let service = ServiceDescriptor(fullyQualifiedService: "grpc.health.v1.Health")
    private static let check = MethodDescriptor(service: service, method: "Check")
    private static let watch = MethodDescriptor(service: service, method: "Watch")
    private static let serving = RawProtobufMessage(bytes: [0x08, 0x01])

    func registerMethods<Transport: ServerTransport>(with router: inout RPCRouter<Transport>) {
        let codec = RawProtobufSerializer()

        router.registerHandler(
            forMethod: Self.check,
            deserializer: codec,
            serializer: codec,
            handler: { _, _ in
                StreamingServerResponse(single: ServerResponse(message: Self.serving))
            }
        )

        router.registerHandler(
            forMethod: Self.watch,
            deserializer: codec,
            serializer: codec,
            handler: { _, _ in
                StreamingServerResponse(of: RawProtobufMessage.self) { writer in
                    try await writer.write(Self.serving)
                    return [:]
                }
            }
        )
    }
}
