const grpc = require('@grpc/grpc-js');

function parseDataIndex(data, size) {
    if (!/^\d+$/.test(data)) {
        throw invalidDataError(size);
    }

    const index = Number(data);
    if (!Number.isSafeInteger(index) || index < 0 || index >= size) {
        throw invalidDataError(size);
    }
    return index;
}

function invalidDataError(size) {
    const error = new Error(`data must be an integer between 0 and ${size - 1}`);
    error.code = grpc.status.INVALID_ARGUMENT;
    error.details = error.message;
    error.metadata = new grpc.Metadata();
    return error;
}

module.exports = { parseDataIndex };
