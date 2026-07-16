import * as grpc from '@grpc/grpc-js'

export function parseDataIndex(data: string, size: number): number {
    if (!/^\d+$/.test(data)) {
        throw invalidDataError(size)
    }

    const index = Number(data)
    if (!Number.isSafeInteger(index) || index < 0 || index >= size) {
        throw invalidDataError(size)
    }
    return index
}

function invalidDataError(size: number): grpc.ServiceError {
    const error = new Error(
        `data must be an integer between 0 and ${size - 1}`
    ) as grpc.ServiceError
    error.code = grpc.status.INVALID_ARGUMENT
    error.details = error.message
    error.metadata = new grpc.Metadata()
    return error
}
