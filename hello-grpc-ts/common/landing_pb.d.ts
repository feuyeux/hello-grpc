// package: hello
// file: landing.proto

/* tslint:disable */
/* eslint-disable */

import * as jspb from "google-protobuf";

export class TalkRequest extends jspb.Message { 
    getData(): string;
    setData(value: string): TalkRequest;
    getMeta(): string;
    setMeta(value: string): TalkRequest;

    serializeBinary(): Uint8Array;
    toObject(includeInstance?: boolean): TalkRequest.AsObject;
    static toObject(includeInstance: boolean, msg: TalkRequest): TalkRequest.AsObject;
    static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
    static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
    static serializeBinaryToWriter(message: TalkRequest, writer: jspb.BinaryWriter): void;
    static deserializeBinary(bytes: Uint8Array): TalkRequest;
    static deserializeBinaryFromReader(message: TalkRequest, reader: jspb.BinaryReader): TalkRequest;
}

export namespace TalkRequest {
    export type AsObject = {
        data: string,
        meta: string,
    }
}

export class TalkResponse extends jspb.Message { 
    getStatus(): number;
    setStatus(value: number): TalkResponse;
    clearResultsList(): void;
    getResultsList(): Array<TalkResult>;
    setResultsList(value: Array<TalkResult>): TalkResponse;
    addResults(value?: TalkResult, index?: number): TalkResult;

    serializeBinary(): Uint8Array;
    toObject(includeInstance?: boolean): TalkResponse.AsObject;
    static toObject(includeInstance: boolean, msg: TalkResponse): TalkResponse.AsObject;
    static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
    static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
    static serializeBinaryToWriter(message: TalkResponse, writer: jspb.BinaryWriter): void;
    static deserializeBinary(bytes: Uint8Array): TalkResponse;
    static deserializeBinaryFromReader(message: TalkResponse, reader: jspb.BinaryReader): TalkResponse;
}

export namespace TalkResponse {
    export type AsObject = {
        status: number,
        resultsList: Array<TalkResult.AsObject>,
    }
}

export class TalkResult extends jspb.Message { 
    getId(): number;
    setId(value: number): TalkResult;
    getType(): ResultType;
    setType(value: ResultType): TalkResult;

    getKvMap(): jspb.Map<string, string>;
    clearKvMap(): void;

    serializeBinary(): Uint8Array;
    toObject(includeInstance?: boolean): TalkResult.AsObject;
    static toObject(includeInstance: boolean, msg: TalkResult): TalkResult.AsObject;
    static extensions: {[key: number]: jspb.ExtensionFieldInfo<jspb.Message>};
    static extensionsBinary: {[key: number]: jspb.ExtensionFieldBinaryInfo<jspb.Message>};
    static serializeBinaryToWriter(message: TalkResult, writer: jspb.BinaryWriter): void;
    static deserializeBinary(bytes: Uint8Array): TalkResult;
    static deserializeBinaryFromReader(message: TalkResult, reader: jspb.BinaryReader): TalkResult;
}

export namespace TalkResult {
    export type AsObject = {
        id: number,
        type: ResultType,

        kvMap: Array<[string, string]>,
    }
}

export enum ResultType {
    OK = 0,
    FAIL = 1,
}
