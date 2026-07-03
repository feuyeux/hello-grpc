using System.Threading.Tasks;
using System.Diagnostics;
using Grpc.Core;
using Grpc.Core.Interceptors;
using log4net;

namespace HelloServer
{
    /// <summary>
    /// C5 — Server-side gRPC interceptor that logs the method name for each call.
    /// </summary>
    public class LoggingInterceptor : Interceptor
    {
        private static readonly ILog Logger = LogManager.GetLogger(typeof(LoggingInterceptor));

        public override async Task<TResponse> UnaryServerHandler<TRequest, TResponse>(
            TRequest request,
            ServerCallContext context,
            UnaryServerMethod<TRequest, TResponse> continuation)
        {
            Logger.Info($"gRPC call: {context.Method}");
            using var activity = Common.Otel.StartRpcSpan(context.Method);
            try
            {
                return await continuation(request, context);
            }
            catch (RpcException ex)
            {
                activity?.SetStatus(ActivityStatusCode.Error, ex.Status.Detail);
                throw;
            }
        }

        public override async Task ServerStreamingServerHandler<TRequest, TResponse>(
            TRequest request,
            IServerStreamWriter<TResponse> responseStream,
            ServerCallContext context,
            ServerStreamingServerMethod<TRequest, TResponse> continuation)
        {
            Logger.Info($"gRPC call: {context.Method}");
            using var activity = Common.Otel.StartRpcSpan(context.Method);
            try
            {
                await continuation(request, responseStream, context);
            }
            catch (RpcException ex)
            {
                activity?.SetStatus(ActivityStatusCode.Error, ex.Status.Detail);
                throw;
            }
        }

        public override async Task<TResponse> ClientStreamingServerHandler<TRequest, TResponse>(
            IAsyncStreamReader<TRequest> requestStream,
            ServerCallContext context,
            ClientStreamingServerMethod<TRequest, TResponse> continuation)
        {
            Logger.Info($"gRPC call: {context.Method}");
            using var activity = Common.Otel.StartRpcSpan(context.Method);
            try
            {
                return await continuation(requestStream, context);
            }
            catch (RpcException ex)
            {
                activity?.SetStatus(ActivityStatusCode.Error, ex.Status.Detail);
                throw;
            }
        }

        public override async Task DuplexStreamingServerHandler<TRequest, TResponse>(
            IAsyncStreamReader<TRequest> requestStream,
            IServerStreamWriter<TResponse> responseStream,
            ServerCallContext context,
            DuplexStreamingServerMethod<TRequest, TResponse> continuation)
        {
            Logger.Info($"gRPC call: {context.Method}");
            using var activity = Common.Otel.StartRpcSpan(context.Method);
            try
            {
                await continuation(requestStream, responseStream, context);
            }
            catch (RpcException ex)
            {
                activity?.SetStatus(ActivityStatusCode.Error, ex.Status.Detail);
                throw;
            }
        }
    }
}
