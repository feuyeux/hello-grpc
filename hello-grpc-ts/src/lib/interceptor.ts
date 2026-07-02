/**
 * Wraps a gRPC service implementation with a logging middleware.
 * @grpc/grpc-js does not support server-side interceptors natively,
 * so we use a wrapper approach instead.
 */
export function withLogging<T extends Record<string, Function>>(impl: T): T {
    const wrapped = {} as T;
    for (const [methodName, handler] of Object.entries(impl)) {
        (wrapped as any)[methodName] = function(call: any, callback: any) {
            console.log(`[gRPC] ${methodName} called`);
            return (handler as Function).call(impl, call, callback);
        };
    }
    return wrapped;
}
