// DO NOT EDIT.
// swift-format-ignore-file
//
// Generated by the Swift generator plugin for the protocol buffer compiler.
// Source: landing.proto
//
// For information on using the generated types, please see the documentation:
//   https://github.com/apple/swift-protobuf/

import Foundation
import SwiftProtobuf

// If the compiler emits an error on this type, it is because this file
// was generated by a version of the `protoc` Swift plug-in that is
// incompatible with the version of SwiftProtobuf to which you are linking.
// Please ensure that you are building against the same version of the API
// that was used to generate this file.
fileprivate struct _GeneratedWithProtocGenSwiftVersion: SwiftProtobuf.ProtobufAPIVersionCheck {
  struct _2: SwiftProtobuf.ProtobufAPIVersion_2 {}
  typealias Version = _2
}

public enum Org_Feuyeux_Grpc_ResultType: SwiftProtobuf.Enum {
  public typealias RawValue = Int
  case ok // = 0
  case fail // = 1
  case UNRECOGNIZED(Int)

  public init() {
    self = .ok
  }

  public init?(rawValue: Int) {
    switch rawValue {
    case 0: self = .ok
    case 1: self = .fail
    default: self = .UNRECOGNIZED(rawValue)
    }
  }

  public var rawValue: Int {
    switch self {
    case .ok: return 0
    case .fail: return 1
    case .UNRECOGNIZED(let i): return i
    }
  }

}

#if swift(>=4.2)

extension Org_Feuyeux_Grpc_ResultType: CaseIterable {
  // The compiler won't synthesize support with the UNRECOGNIZED case.
  public static var allCases: [Org_Feuyeux_Grpc_ResultType] = [
    .ok,
    .fail,
  ]
}

#endif  // swift(>=4.2)

public struct Org_Feuyeux_Grpc_TalkRequest {
  // SwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
  // methods supported on all messages.

  ///language index
  public var data: String = String()

  ///clientside language
  public var meta: String = String()

  public var unknownFields = SwiftProtobuf.UnknownStorage()

  public init() {}
}

public struct Org_Feuyeux_Grpc_TalkResponse {
  // SwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
  // methods supported on all messages.

  public var status: Int32 = 0

  public var results: [Org_Feuyeux_Grpc_TalkResult] = []

  public var unknownFields = SwiftProtobuf.UnknownStorage()

  public init() {}
}

public struct Org_Feuyeux_Grpc_TalkResult {
  // SwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
  // methods supported on all messages.

  ///timestamp
  public var id: Int64 = 0

  ///enum
  public var type: Org_Feuyeux_Grpc_ResultType = .ok

  /// id:result uuid
  /// idx:language index
  /// data: hello
  /// meta: serverside language
  public var kv: Dictionary<String,String> = [:]

  public var unknownFields = SwiftProtobuf.UnknownStorage()

  public init() {}
}

#if swift(>=5.5) && canImport(_Concurrency)
extension Org_Feuyeux_Grpc_ResultType: @unchecked Sendable {}
extension Org_Feuyeux_Grpc_TalkRequest: @unchecked Sendable {}
extension Org_Feuyeux_Grpc_TalkResponse: @unchecked Sendable {}
extension Org_Feuyeux_Grpc_TalkResult: @unchecked Sendable {}
#endif  // swift(>=5.5) && canImport(_Concurrency)

// MARK: - Code below here is support for the SwiftProtobuf runtime.

fileprivate let _protobuf_package = "org.feuyeux.grpc"

extension Org_Feuyeux_Grpc_ResultType: SwiftProtobuf._ProtoNameProviding {
  public static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    0: .same(proto: "OK"),
    1: .same(proto: "FAIL"),
  ]
}

extension Org_Feuyeux_Grpc_TalkRequest: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  public static let protoMessageName: String = _protobuf_package + ".TalkRequest"
  public static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    1: .same(proto: "data"),
    2: .same(proto: "meta"),
  ]

  public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeSingularStringField(value: &self.data) }()
      case 2: try { try decoder.decodeSingularStringField(value: &self.meta) }()
      default: break
      }
    }
  }

  public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    if !self.data.isEmpty {
      try visitor.visitSingularStringField(value: self.data, fieldNumber: 1)
    }
    if !self.meta.isEmpty {
      try visitor.visitSingularStringField(value: self.meta, fieldNumber: 2)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  public static func ==(lhs: Org_Feuyeux_Grpc_TalkRequest, rhs: Org_Feuyeux_Grpc_TalkRequest) -> Bool {
    if lhs.data != rhs.data {return false}
    if lhs.meta != rhs.meta {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension Org_Feuyeux_Grpc_TalkResponse: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  public static let protoMessageName: String = _protobuf_package + ".TalkResponse"
  public static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    1: .same(proto: "status"),
    2: .same(proto: "results"),
  ]

  public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeSingularInt32Field(value: &self.status) }()
      case 2: try { try decoder.decodeRepeatedMessageField(value: &self.results) }()
      default: break
      }
    }
  }

  public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    if self.status != 0 {
      try visitor.visitSingularInt32Field(value: self.status, fieldNumber: 1)
    }
    if !self.results.isEmpty {
      try visitor.visitRepeatedMessageField(value: self.results, fieldNumber: 2)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  public static func ==(lhs: Org_Feuyeux_Grpc_TalkResponse, rhs: Org_Feuyeux_Grpc_TalkResponse) -> Bool {
    if lhs.status != rhs.status {return false}
    if lhs.results != rhs.results {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension Org_Feuyeux_Grpc_TalkResult: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  public static let protoMessageName: String = _protobuf_package + ".TalkResult"
  public static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    1: .same(proto: "id"),
    2: .same(proto: "type"),
    3: .same(proto: "kv"),
  ]

  public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeSingularInt64Field(value: &self.id) }()
      case 2: try { try decoder.decodeSingularEnumField(value: &self.type) }()
      case 3: try { try decoder.decodeMapField(fieldType: SwiftProtobuf._ProtobufMap<SwiftProtobuf.ProtobufString,SwiftProtobuf.ProtobufString>.self, value: &self.kv) }()
      default: break
      }
    }
  }

  public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    if self.id != 0 {
      try visitor.visitSingularInt64Field(value: self.id, fieldNumber: 1)
    }
    if self.type != .ok {
      try visitor.visitSingularEnumField(value: self.type, fieldNumber: 2)
    }
    if !self.kv.isEmpty {
      try visitor.visitMapField(fieldType: SwiftProtobuf._ProtobufMap<SwiftProtobuf.ProtobufString,SwiftProtobuf.ProtobufString>.self, value: self.kv, fieldNumber: 3)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  public static func ==(lhs: Org_Feuyeux_Grpc_TalkResult, rhs: Org_Feuyeux_Grpc_TalkResult) -> Bool {
    if lhs.id != rhs.id {return false}
    if lhs.type != rhs.type {return false}
    if lhs.kv != rhs.kv {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}