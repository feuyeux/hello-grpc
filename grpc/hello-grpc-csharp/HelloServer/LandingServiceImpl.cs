using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Threading.Tasks;
using Grpc.Core;
using HelloClient;
using log4net;
using Org.Feuyeux.Grpc;

namespace HelloServer
{
    public class LandingServiceImpl : LandingService.LandingServiceBase
    {
        private readonly ILog _log = LogManager.GetLogger(typeof(LandingServiceImpl));
        private LandingService.LandingServiceClient _protoClient;

        public void SetProtoClient(LandingService.LandingServiceClient protoClient)
        {
            this._protoClient = protoClient;
        }

        private readonly List<string> _helloList = new List<string>()
        {
            "Hello", "Bonjour", "Hola", "こんにちは", "Ciao",
            "안녕하세요"
        };

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
                var response = _protoClient.Talk(request);
                return Task.FromResult(response);
            }
        }

        public override async Task TalkOneAnswerMore(TalkRequest request, IServerStreamWriter<TalkResponse> responseStream, ServerCallContext context)
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
                using var call = _protoClient.TalkOneAnswerMore(request, headers);
                var nextStream = call.ResponseStream;
                while (await nextStream.MoveNext())
                {
                    var talkResponse = nextStream.Current;
                    await responseStream.WriteAsync(talkResponse);
                }
            }
        }

        public override async Task<TalkResponse> TalkMoreAnswerOne(IAsyncStreamReader<TalkRequest> requestStream, ServerCallContext context)
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
                using var call = _protoClient.TalkMoreAnswerOne(context.RequestHeaders);
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

        public override async Task TalkBidirectional(IAsyncStreamReader<TalkRequest> requestStream, IServerStreamWriter<TalkResponse> responseStream,
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
                using var call = _protoClient.TalkBidirectional(context.RequestHeaders);
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
            return new TalkResult
            {
                Id = DateTimeOffset.Now.ToUnixTimeSeconds(),
                Type = ResultType.Ok,
                Kv =
                {
                    ["id"] = Guid.NewGuid().ToString(),
                    ["idx"] = id,
                    ["data"] = _helloList[int.Parse(id)],
                    ["meta"] = "C#"
                }
            };
        }

        private Metadata PrintHeaders(ServerCallContext context)
        {
            var headers = context.RequestHeaders;
            foreach (var header in headers)
            {
                _log.Info($"->H ${header.Key}:${header.Value}");
            }
            return headers;
        }
    }
}