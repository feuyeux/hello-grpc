using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Threading.Tasks;
using Grpc.Core;
using Org.Feuyeux.Grpc;

namespace HelloServer
{
    public class LandingServiceImpl : LandingService.LandingServiceBase
    {
        private readonly List<string> _helloList = new List<string>()
        {
            "Hello", "Bonjour", "Hola", "こんにちは", "Ciao",
            "안녕하세요"
        };

        public override Task<TalkResponse> Talk(TalkRequest request, ServerCallContext context)
        {
            Console.WriteLine("TALK REQUEST: data={0},meta={1}", request.Data, request.Meta);
            PrintHeaders(context);
            var response = new TalkResponse
            {
                Status = 200,
                Results = { BuildResult(request.Data) }
            };
            return Task.FromResult(response);
        }

        public override async Task TalkOneAnswerMore(TalkRequest request, IServerStreamWriter<TalkResponse> responseStream, ServerCallContext context)
        {
            Console.WriteLine("TalkOneAnswerMore REQUEST: data={0},meta={1}", request.Data, request.Meta);
            PrintHeaders(context);
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

        public override async Task<TalkResponse> TalkMoreAnswerOne(IAsyncStreamReader<TalkRequest> requestStream, ServerCallContext context)
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
                Console.WriteLine("TalkMoreAnswerOne REQUEST: data={0},meta={1}", request.Data, request.Meta);
                talkResponse.Results.Add(BuildResult(request.Data));
            }
            PrintHeaders(context);
            stopwatch.Stop();
            return talkResponse;
        }

        public override async Task TalkBidirectional(IAsyncStreamReader<TalkRequest> requestStream, IServerStreamWriter<TalkResponse> responseStream,
            ServerCallContext context)
        {
            while (await requestStream.MoveNext())
            {
                var request = requestStream.Current;
                Console.WriteLine("TalkBidirectional REQUEST: data={0},meta={1}", request.Data, request.Meta);

                var response = new TalkResponse
                {
                    Status = 200,
                    Results = { BuildResult(request.Data) }
                };

                await responseStream.WriteAsync(response);
            }
            PrintHeaders(context);
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
        private void PrintHeaders(ServerCallContext context)
        {
            var headers = context.RequestHeaders;
            foreach (var header in headers)
            {
                Console.WriteLine("->H {0}:{1}", header.Key, header.Value);
            }
        }
    }
}