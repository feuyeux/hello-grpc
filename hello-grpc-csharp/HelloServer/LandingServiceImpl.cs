using System;
using System.Diagnostics;
using System.Threading.Tasks;
using Common;
using Grpc.Core;
using Hello;
using log4net;
using Microsoft.Extensions.Logging;

namespace HelloServer
{
    /// <summary>
    /// Implementation of the LandingService gRPC service.
    /// Supports all four RPC patterns: unary, server streaming, client streaming, and bidirectional streaming.
    /// Can operate in proxy mode to forward requests to a backend server.
    /// </summary>
    public class LandingServiceImpl : LandingService.LandingServiceBase
    {
        private readonly ILog _log = LogManager.GetLogger(typeof(LandingServiceImpl));
        private LandingService.LandingServiceClient? _protoClient;

        /// <summary>
        /// Sets the backend client for proxy mode operation.
        /// </summary>
        /// <param name="protoClient">The client to use for forwarding requests</param>
        public void SetProtoClient(LandingService.LandingServiceClient protoClient)
        {
            this._protoClient = protoClient;
        }

        /// <summary>
        /// Handles unary RPC calls (single request, single response).
        /// </summary>
        /// <param name="request">The incoming request</param>
        /// <param name="context">The server call context</param>
        /// <returns>The response</returns>
        public override Task<TalkResponse> Talk(TalkRequest request, ServerCallContext context)
        {
            _log.Info($"Talk REQUEST: data={request.Data}, meta={request.Meta}");
            
            if (_protoClient == null)
            {
                // Direct mode: handle request locally
                LogHeaders(context);
                var response = new TalkResponse
                {
                    Status = 200,
                    Results = { BuildResult(request.Data) }
                };
                return Task.FromResult(response);
            }
            else
            {
                // Proxy mode: forward request to backend
                var headers = CreateProxyHeaders(context.RequestHeaders);
                var response = _protoClient.Talk(request, headers);
                return Task.FromResult(response);
            }
        }

        /// <summary>
        /// Handles server streaming RPC calls (single request, multiple responses).
        /// </summary>
        /// <param name="request">The incoming request</param>
        /// <param name="responseStream">The stream to write responses to</param>
        /// <param name="context">The server call context</param>
        public override async Task TalkOneAnswerMore(TalkRequest request,
            IServerStreamWriter<TalkResponse> responseStream, ServerCallContext context)
        {
            _log.Info($"TalkOneAnswerMore REQUEST: data={request.Data}, meta={request.Meta}");

            var headers = LogHeaders(context);

            if (_protoClient == null)
            {
                // Direct mode: generate responses locally
                var datas = request.Data.Split(",");
                foreach (var data in datas)
                {
                    var response = new TalkResponse
                    {
                        Status = 200,
                        Results = { BuildResult(data) }
                    };
                    await responseStream.WriteAsync(response);
                }
            }
            else
            {
                // Proxy mode: forward stream to backend
                headers = CreateProxyHeaders(headers);
                using var call = _protoClient.TalkOneAnswerMore(request, headers);
                var nextStream = call.ResponseStream;
                while (await nextStream.MoveNext())
                {
                    var talkResponse = nextStream.Current;
                    await responseStream.WriteAsync(talkResponse);
                }
            }
        }

        /// <summary>
        /// Handles client streaming RPC calls (multiple requests, single response).
        /// </summary>
        /// <param name="requestStream">The stream to read requests from</param>
        /// <param name="context">The server call context</param>
        /// <returns>The aggregated response</returns>
        public override async Task<TalkResponse> TalkMoreAnswerOne(IAsyncStreamReader<TalkRequest> requestStream,
            ServerCallContext context)
        {
            if (_protoClient == null)
            {
                // Direct mode: aggregate requests locally
                var talkResponse = new TalkResponse()
                {
                    Status = 200
                };

                var stopwatch = Stopwatch.StartNew();
                while (await requestStream.MoveNext())
                {
                    var request = requestStream.Current;
                    _log.Info($"TalkMoreAnswerOne REQUEST: data={request.Data}, meta={request.Meta}");
                    talkResponse.Results.Add(BuildResult(request.Data));
                }

                LogHeaders(context);
                stopwatch.Stop();
                _log.Info($"Client streaming completed in {stopwatch.ElapsedMilliseconds}ms");
                return talkResponse;
            }
            else
            {
                // Proxy mode: forward stream to backend
                var headers = CreateProxyHeaders(context.RequestHeaders);
                using var call = _protoClient.TalkMoreAnswerOne(headers);
                var stopwatch = Stopwatch.StartNew();
                
                while (await requestStream.MoveNext())
                {
                    var request = requestStream.Current;
                    _log.Info($"TalkMoreAnswerOne REQUEST: data={request.Data}, meta={request.Meta}");
                    await call.RequestStream.WriteAsync(request);
                }

                await call.RequestStream.CompleteAsync();
                var talkResponse = await call.ResponseAsync;
                
                stopwatch.Stop();
                _log.Info($"Client streaming completed in {stopwatch.ElapsedMilliseconds}ms");
                return talkResponse;
            }
        }

        /// <summary>
        /// Handles bidirectional streaming RPC calls (multiple requests, multiple responses).
        /// </summary>
        /// <param name="requestStream">The stream to read requests from</param>
        /// <param name="responseStream">The stream to write responses to</param>
        /// <param name="context">The server call context</param>
        public override async Task TalkBidirectional(IAsyncStreamReader<TalkRequest> requestStream,
            IServerStreamWriter<TalkResponse> responseStream,
            ServerCallContext context)
        {
            if (_protoClient == null)
            {
                // Direct mode: process requests and send responses
                while (await requestStream.MoveNext())
                {
                    var request = requestStream.Current;
                    _log.Info($"TalkBidirectional REQUEST: data={request.Data}, meta={request.Meta}");

                    var response = new TalkResponse
                    {
                        Status = 200,
                        Results = { BuildResult(request.Data) }
                    };

                    await responseStream.WriteAsync(response);
                }

                LogHeaders(context);
            }
            else
            {
                // Proxy mode: forward bidirectional stream to backend
                var headers = CreateProxyHeaders(context.RequestHeaders);
                using var call = _protoClient.TalkBidirectional(headers);
                
                // Start receiving responses in a separate task
                var responseReaderTask = Task.Run(async () =>
                {
                    while (await call.ResponseStream.MoveNext())
                    {
                        var talkResponse = call.ResponseStream.Current;
                        await responseStream.WriteAsync(talkResponse);
                    }
                });

                // Forward all requests
                while (await requestStream.MoveNext())
                {
                    var request = requestStream.Current;
                    _log.Info($"TalkBidirectional REQUEST: data={request.Data}, meta={request.Meta}");
                    await call.RequestStream.WriteAsync(request);
                }

                await call.RequestStream.CompleteAsync();
                await responseReaderTask;
            }
        }

        /// <summary>
        /// Builds a TalkResult from the given data ID.
        /// </summary>
        /// <param name="id">The ID to use for building the result</param>
        /// <returns>A TalkResult with generated data</returns>
        private TalkResult BuildResult(string id)
        {
            var hello = Utils.HelloList[int.Parse(id)];
            return new TalkResult
            {
                Id = DateTimeOffset.Now.ToUnixTimeSeconds(),
                Type = ResultType.Ok,
                Kv =
                {
                    ["id"] = Guid.NewGuid().ToString(),
                    ["idx"] = id,
                    ["data"] = hello + "," + Utils.AnsMap[hello],
                    ["meta"] = "C#"
                }
            };
        }

        /// <summary>
        /// Logs all request headers in a standardized format.
        /// </summary>
        /// <param name="context">The server call context</param>
        /// <returns>The request headers</returns>
        private Metadata LogHeaders(ServerCallContext context)
        {
            var headers = context.RequestHeaders;
            foreach (var header in headers)
            {
                _log.Info($"->H {header.Key}:{header.Value}");
            }

            return headers;
        }

        /// <summary>
        /// Creates a new Metadata object with proxy identification headers added.
        /// </summary>
        /// <param name="originalHeaders">The original request headers</param>
        /// <returns>A new Metadata object with proxy headers</returns>
        private Metadata CreateProxyHeaders(Metadata originalHeaders)
        {
            // Create a new metadata object with all original headers
            var headers = new Metadata();
            foreach (var header in originalHeaders)
            {
                headers.Add(header);
            }

            // Add proxy identification headers
            headers.Add("x-proxy-by", "csharp-proxy");
            headers.Add("x-proxy-timestamp", DateTimeOffset.Now.ToUnixTimeMilliseconds().ToString());
            
            // Log the headers we're sending
            _log.Info("Proxying request with headers:");
            foreach (var header in headers)
            {
                _log.Info($"->H {header.Key}:{header.Value}");
            }

            return headers;
        }
    }
}