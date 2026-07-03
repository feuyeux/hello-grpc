import * as assert from 'assert';
import * as grpc from '@grpc/grpc-js';
import { mapToStatusCode, getErrorMessage, toGrpcError } from '../src/lib/error_mapper';

describe('error_mapper', () => {
    describe('mapToStatusCode()', () => {
        it('returns OK for null/undefined errors', () => {
            assert.strictEqual(mapToStatusCode(null), grpc.status.OK);
            assert.strictEqual(mapToStatusCode(undefined), grpc.status.OK);
        });

        it('preserves existing gRPC status codes', () => {
            assert.strictEqual(
                mapToStatusCode({ code: grpc.status.NOT_FOUND, message: 'x' }),
                grpc.status.NOT_FOUND);
        });

        it('maps timeout errors to DEADLINE_EXCEEDED', () => {
            assert.strictEqual(
                mapToStatusCode(new Error('request timed out')),
                grpc.status.DEADLINE_EXCEEDED);
        });

        it('maps connection errors to UNAVAILABLE', () => {
            assert.strictEqual(
                mapToStatusCode(new Error('connect ECONNREFUSED 127.0.0.1:9996')),
                grpc.status.UNAVAILABLE);
        });

        it('maps validation errors to INVALID_ARGUMENT', () => {
            assert.strictEqual(
                mapToStatusCode(new Error('invalid input field')),
                grpc.status.INVALID_ARGUMENT);
        });

        it('maps auth errors to UNAUTHENTICATED', () => {
            assert.strictEqual(
                mapToStatusCode(new Error('authentication failed')),
                grpc.status.UNAUTHENTICATED);
        });

        it('maps missing-file errors to NOT_FOUND', () => {
            assert.strictEqual(
                mapToStatusCode(new Error('ENOENT: no such file or directory')),
                grpc.status.NOT_FOUND);
        });

        it('defaults to INTERNAL for unknown errors', () => {
            assert.strictEqual(
                mapToStatusCode(new Error('something exploded')),
                grpc.status.INTERNAL);
        });
    });

    describe('toGrpcError()', () => {
        it('produces a ServiceError with mapped code and message', () => {
            const err = toGrpcError(new Error('request timed out'), 'req-1');
            assert.strictEqual(err.code, grpc.status.DEADLINE_EXCEEDED);
            assert.ok(err.message.length > 0);
        });
    });

    describe('getErrorMessage()', () => {
        it('returns a non-empty message for plain errors', () => {
            assert.ok(getErrorMessage(new Error('boom')).includes('boom'));
        });
    });
});
