var assert = require('assert');
const utils = require("../common/utils");
const {ResultType} = require("../common/landing_pb");
const uuid = require("uuid");

describe('List&Map', function () {
    it('should return -1 when the value is not present', function () {
        let hello = utils.hellos[1]
        let ans = utils.ans().get(hello);
        assert.equal(ans, "Merci beaucoup");
    });
});
