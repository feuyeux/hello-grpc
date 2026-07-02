import Foundation
import GRPCCore

struct ReflectionService: RegistrableRPCService {
    private static let service = ServiceDescriptor(
        fullyQualifiedService: "grpc.reflection.v1alpha.ServerReflection"
    )
    private static let serverReflectionInfo = MethodDescriptor(
        service: service,
        method: "ServerReflectionInfo"
    )
    private static let landingFileDescriptorProto: [UInt8] = Array(
        Data(
            base64Encoded:
                "Cg1sYW5kaW5nLnByb3RvEgVoZWxsbyI1CgtUYWxrUmVxdWVzdBISCgRkYXRhGAEgASgJUgRkYXRhEhIKBG1ldGEYAiABKAlSBG1ldGEiUwoMVGFsa1Jlc3BvbnNlEhYKBnN0YXR1cxgBIAEoBVIGc3RhdHVzEisKB3Jlc3VsdHMYAiADKAsyES5oZWxsby5UYWxrUmVzdWx0UgdyZXN1bHRzIqUBCgpUYWxrUmVzdWx0Eg4KAmlkGAEgASgDUgJpZBIlCgR0eXBlGAIgASgOMhEuaGVsbG8uUmVzdWx0VHlwZVIEdHlwZRIpCgJrdhgDIAMoCzIZLmhlbGxvLlRhbGtSZXN1bHQuS3ZFbnRyeVICa3YaNQoHS3ZFbnRyeRIQCgNrZXkYASABKAlSA2tleRIUCgV2YWx1ZRgCIAEoCVIFdmFsdWU6AjgBKh4KClJlc3VsdFR5cGUSBgoCT0sQABIICgRGQUlMEAEyiwIKDkxhbmRpbmdTZXJ2aWNlEjEKBFRhbGsSEi5oZWxsby5UYWxrUmVxdWVzdBoTLmhlbGxvLlRhbGtSZXNwb25zZSIAEkAKEVRhbGtPbmVBbnN3ZXJNb3JlEhIuaGVsbG8uVGFsa1JlcXVlc3QaEy5oZWxsby5UYWxrUmVzcG9uc2UiADABEkAKEVRhbGtNb3JlQW5zd2VyT25lEhIuaGVsbG8uVGFsa1JlcXVlc3QaEy5oZWxsby5UYWxrUmVzcG9uc2UiACgBEkIKEVRhbGtCaWRpcmVjdGlvbmFsEhIuaGVsbG8uVGFsa1JlcXVlc3QaEy5oZWxsby5UYWxrUmVzcG9uc2UiACgBMAFCLgoWb3JnLmZldXlldXguZ3JwYy5wcm90b0IHTGFuZGluZ1ABWgljb21tb24vcGJiBnByb3RvMw=="
        ) ?? Data()
    )
    private static let serviceNames = [
        "hello.LandingService",
        "grpc.health.v1.Health",
        "grpc.reflection.v1alpha.ServerReflection",
    ]

    func registerMethods<Transport: ServerTransport>(with router: inout RPCRouter<Transport>) {
        let codec = RawProtobufSerializer()
        router.registerHandler(
            forMethod: Self.serverReflectionInfo,
            deserializer: codec,
            serializer: codec,
            handler: { request, _ in
                StreamingServerResponse(of: RawProtobufMessage.self) { writer in
                    for try await message in request.messages {
                        try await writer.write(RawProtobufMessage(bytes: try Self.respond(to: message.bytes)))
                    }
                    return [:]
                }
            }
        )
    }

    private static func respond(to originalRequest: [UInt8]) throws -> [UInt8] {
        let request = try ReflectionRequest(bytes: originalRequest)
        if request.listServices != nil {
            return response(
                originalRequest: originalRequest,
                fieldNumber: 6,
                payload: listServicesResponse()
            )
        }
        if matchesLandingFile(request.fileByFilename)
            || matchesLandingSymbol(request.fileContainingSymbol)
        {
            return fileDescriptorResponse(originalRequest: originalRequest)
        }
        return response(
            originalRequest: originalRequest,
            fieldNumber: 7,
            payload: ProtobufWire.varintField(1, 5)
                + ProtobufWire.stringField(2, "Symbol or file is not available from this Swift server")
        )
    }

    private static func fileDescriptorResponse(originalRequest: [UInt8]) -> [UInt8] {
        response(
            originalRequest: originalRequest,
            fieldNumber: 4,
            payload: ProtobufWire.bytesField(1, landingFileDescriptorProto)
        )
    }

    private static func response(
        originalRequest: [UInt8],
        fieldNumber: Int,
        payload: [UInt8]
    ) -> [UInt8] {
        ProtobufWire.stringField(1, "")
            + ProtobufWire.bytesField(2, originalRequest)
            + ProtobufWire.bytesField(fieldNumber, payload)
    }

    private static func listServicesResponse() -> [UInt8] {
        serviceNames.flatMap { serviceName in
            ProtobufWire.bytesField(1, ProtobufWire.stringField(1, serviceName))
        }
    }

    private static func matchesLandingFile(_ fileName: String?) -> Bool {
        fileName == "landing.proto" || fileName == "proto/landing.proto"
    }

    private static func matchesLandingSymbol(_ symbol: String?) -> Bool {
        guard let symbol, !symbol.isEmpty else { return false }
        return symbol == "hello"
            || symbol == "hello.LandingService"
            || symbol.hasPrefix("hello.LandingService.")
            || symbol == "hello.TalkRequest"
            || symbol == "hello.TalkResponse"
            || symbol == "hello.TalkResult"
            || symbol == "hello.ResultType"
    }
}

private struct ReflectionRequest {
    var fileByFilename: String?
    var fileContainingSymbol: String?
    var listServices: String?

    init(bytes: [UInt8]) throws {
        var pos = 0
        while pos < bytes.count {
            let tag = try ProtobufWire.readVarint(bytes, from: pos)
            pos = tag.next
            let fieldNumber = tag.value >> 3
            let wireType = tag.value & 0x07

            if wireType == 2 {
                let length = try ProtobufWire.readVarint(bytes, from: pos)
                pos = length.next
                let end = pos + length.value
                let value = String(decoding: bytes[pos..<end], as: UTF8.self)
                pos = end

                if fieldNumber == 3 {
                    self.fileByFilename = value
                } else if fieldNumber == 4 {
                    self.fileContainingSymbol = value
                } else if fieldNumber == 7 {
                    self.listServices = value
                }
            } else {
                pos = try ProtobufWire.skipField(bytes, from: pos, wireType: wireType)
            }
        }
    }
}
