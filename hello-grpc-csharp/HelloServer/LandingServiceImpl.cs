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
    public class LandingServiceImpl : LandingService.LandingServiceBase
    {
        private readonly ILog _log = LogManager.GetLogger(typeof(LandingServiceImpl));
        private LandingService.LandingServiceClient? _protoClient;

        public void SetProtoClient(LandingService.LandingServiceClient protoClient)
        {
            this._protoClient = protoClient;
        }

        public override Task<TalkResponse> Talk(TalkRequest request, ServerCallContext context)
        {
            _log.Info($"TALK REQUEST: data={request.Data},meta={request.Meta}");
            if (_protoClient == null)
            {
                PrintHeaders(context);
                var response = new TalkResponse
                {
                    Status = 200,
                    Results = { BuildResult(request.Data) }
                };
                return Task.FromResult(response);
            }
            else
            {
                // Add proxy headers
                var headers = CreateProxyHeaders(context.RequestHeaders);
                var response = _protoClient.Talk(request, headers);
                return Task.FromResult(response);
            }
        }

        public override async Task TalkOneAnswerMore(TalkRequest request,
            IServerStreamWriter<TalkResponse> responseStream, ServerCallContext context)
        {
            _log.Info($"TalkOneAnswerMore REQUEST: data={request.Data},meta={request.Meta}");

            var headers = PrintHeaders(context);

            if (_protoClient == null)
            {
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
                // Add proxy headers
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

        public override async Task<TalkResponse> TalkMoreAnswerOne(IAsyncStreamReader<TalkRequest> requestStream,
            ServerCallContext context)
        {
            if (_protoClient == null)
            {
                var talkResponse = new TalkResponse()
                {
                    Status = 200
                };

                var stopwatch = new Stopwatch();
                stopwatch.Start();
                while (await requestStream.MoveNext())
                {
                    var request = requestStream.Current;
                    _log.Info($"TalkMoreAnswerOne REQUEST: data={request.Data},meta={request.Meta}");
                    talkResponse.Results.Add(BuildResult(request.Data));
                }

                PrintHeaders(context);
                stopwatch.Stop();
                return talkResponse;
            }
            else
            {
                // Add proxy headers
                var headers = CreateProxyHeaders(context.RequestHeaders);
                using var call = _protoClient.TalkMoreAnswerOne(headers);
                var stopwatch = new Stopwatch();
                stopwatch.Start();
                while (await requestStream.MoveNext())
                {
                    var request = requestStream.Current;
                    _log.Info($"Request: data={request.Data},meta={request.Meta}");
                    await call.RequestStream.WriteAsync(request);
                }

                stopwatch.Stop();
                await call.RequestStream.CompleteAsync();
                var talkResponse = await call.ResponseAsync;
                return talkResponse;
            }
        }

        public override async Task TalkBidirectional(IAsyncStreamReader<TalkRequest> requestStream,
            IServerStreamWriter<TalkResponse> responseStream,
            ServerCallContext context)
        {
            if (_protoClient == null)
            {
                while (await requestStream.MoveNext())
                {
                    var request = requestStream.Current;
                    _log.Info($"TalkBidirectional REQUEST: data={request.Data},meta={request.Meta}");

                    var response = new TalkResponse
                    {
                        Status = 200,
                        Results = { BuildResult(request.Data) }
                    };

                    await responseStream.WriteAsync(response);
                }

                PrintHeaders(context);
            }
            else
            {
                // Add proxy headers
                var headers = CreateProxyHeaders(context.RequestHeaders);
                using var call = _protoClient.TalkBidirectional(headers);
                var responseReaderTask = Task.Run(async () =>
                {
                    while (await call.ResponseStream.MoveNext())
                    {
                        var talkResponse = call.ResponseStream.Current;
                        await responseStream.WriteAsync(talkResponse);
                    }
                });

                while (await requestStream.MoveNext())
                {
                    var request = requestStream.Current;
                    _log.Info($"Request: data={request.Data},meta={request.Meta}");
                    await call.RequestStream.WriteAsync(request);
                }

                await call.RequestStream.CompleteAsync();
                await responseReaderTask;
            }
        }

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

        private Metadata PrintHeaders(ServerCallContext context)
        {
            var headers = context.RequestHeaders;
            foreach (var header in headers)
            {
                _log.Info($"->H {header.Key}:{header.Value}");
            }

            return headers;
        }

        /// <summary>
        /// Creates a new Metadata object with proxy identification headers added
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