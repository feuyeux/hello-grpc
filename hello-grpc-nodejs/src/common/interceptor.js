'use strict';

/**
 * Wraps a gRPC service implementation with a logging middleware.
 * @param {Object} impl - The service implementation object
 * @returns {Object} - Wrapped implementation with logging
 */
function withLogging(impl) {
    const wrapped = {};
    for (const [methodName, handler] of Object.entries(impl)) {
        wrapped[methodName] = function(call, callback) {
            console.log(`[gRPC] ${methodName} called`);
            return handler.call(impl, call, callback);
        };
    }
    return wrapped;
}

module.exports = { withLogging };
