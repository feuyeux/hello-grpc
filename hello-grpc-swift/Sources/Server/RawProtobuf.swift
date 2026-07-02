import Foundation
import GRPCCore

struct RawProtobufMessage: Sendable {
    var bytes: [UInt8]
}

struct RawProtobufSerializer: MessageSerializer, MessageDeserializer {
    func serialize<Bytes: GRPCContiguousBytes>(_ message: RawProtobufMessage) throws -> Bytes {
        Bytes(message.bytes)
    }

    func deserialize<Bytes: GRPCContiguousBytes>(_ serializedMessageBytes: Bytes) throws -> RawProtobufMessage {
        let bytes = serializedMessageBytes.withUnsafeBytes { buffer in
            Array(buffer.bindMemory(to: UInt8.self))
        }
        return RawProtobufMessage(bytes: bytes)
    }
}

enum ProtobufWire {
    struct VarintResult {
        let value: Int
        let next: Int
    }

    static func readVarint(_ bytes: [UInt8], from start: Int) throws -> VarintResult {
        var value = 0
        var shift = 0
        var pos = start
        while pos < bytes.count {
            let byte = Int(bytes[pos])
            pos += 1
            value |= (byte & 0x7f) << shift
            if (byte & 0x80) == 0 {
                return VarintResult(value: value, next: pos)
            }
            shift += 7
        }
        throw RPCError(code: .invalidArgument, message: "Malformed protobuf varint")
    }

    static func skipField(_ bytes: [UInt8], from start: Int, wireType: Int) throws -> Int {
        switch wireType {
        case 0:
            return try readVarint(bytes, from: start).next
        case 1:
            return start + 8
        case 2:
            let length = try readVarint(bytes, from: start)
            return length.next + length.value
        case 5:
            return start + 4
        default:
            throw RPCError(code: .invalidArgument, message: "Unsupported protobuf wire type: \(wireType)")
        }
    }

    static func varint(_ value: Int) -> [UInt8] {
        var current = value
        var out: [UInt8] = []
        while current > 0x7f {
            out.append(UInt8((current & 0x7f) | 0x80))
            current >>= 7
        }
        out.append(UInt8(current))
        return out
    }

    static func varintField(_ fieldNumber: Int, _ value: Int) -> [UInt8] {
        var out = varint((fieldNumber << 3) | 0)
        out.append(contentsOf: varint(value))
        return out
    }

    static func bytesField(_ fieldNumber: Int, _ value: [UInt8]) -> [UInt8] {
        var out = varint((fieldNumber << 3) | 2)
        out.append(contentsOf: varint(value.count))
        out.append(contentsOf: value)
        return out
    }

    static func stringField(_ fieldNumber: Int, _ value: String) -> [UInt8] {
        bytesField(fieldNumber, Array(value.utf8))
    }
}
