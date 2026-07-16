const assert = require('assert');
const grpc = require('@grpc/grpc-js');
const { parseDataIndex } = require('../src/common/validation');

describe('request validation', () => {
    it('accepts both valid boundaries', () => {
        assert.strictEqual(parseDataIndex('0', 6), 0);
        assert.strictEqual(parseDataIndex('5', 6), 5);
    });

    for (const data of ['', '-1', 'abc', '6', '9007199254740992']) {
        it(`rejects invalid data ${JSON.stringify(data)} with INVALID_ARGUMENT`, () => {
            assert.throws(
                () => parseDataIndex(data, 6),
                error => error.code === grpc.status.INVALID_ARGUMENT
            );
        });
    }
});
