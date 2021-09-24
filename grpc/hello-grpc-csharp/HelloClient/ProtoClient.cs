using System;
using System.Threading.Tasks;
using Grpc.Core;
using Org.Feuyeux.Grpc;

namespace HelloClient
{
    public class ProtoClient
    {
        private readonly LandingService.LandingServiceClient _client;
        private readonly Random _random = new Random();

        private ProtoClient(LandingService.LandingServiceClient client)
        {
            this._client = client;
        }

        private static string GetGrcServer()
        {
            var server = Environment.GetEnvironmentVariable("GRPC_SERVER");
            return server ?? "localhost";
        }

        public static void Main()
        {
            var host = GetGrcServer();
            const string port = "9996";
            var endpoint = host + ":" + port;
            Console.WriteLine("\nEndpoint={0}", endpoint);
            var channel = new Channel(endpoint, ChannelCredentials.Insecure);
            var client = new ProtoClient(new LandingService.LandingServiceClient(channel));
            Console.WriteLine("Unary RPC");
            client.Talk();
            Console.WriteLine("Server streaming RPC");
            client.TalkOneAnswerMore().Wait();
            Console.WriteLine("Client streaming RPC");
            client.TalkMoreAnswerOne().Wait();
            Console.WriteLine("Bidirectional streaming RPC");
            client.TalkBidirectional().Wait();
            channel.ShutdownAsync().Wait();
        }

        private void Talk()
        {
            var request = new TalkRequest
            {
                Data = "0",
                Meta = "C#"
            };
            try
            {
                Console.WriteLine("Request: data={0},meta={1}", request.Data, request.Meta);
                var talkResponse = _client.Talk(request, BuildHeaders());
                PrintResponse(talkResponse);
            }
            catch (RpcException e)
            {
                Console.Error.WriteLine(e);
            }
        }

        private async Task TalkOneAnswerMore()
        {
            try
            {
                var request = new TalkRequest
                {
                    Data = "0,1,2",
                    Meta = "C#"
                };
                Console.WriteLine("Request: data={0},meta={1}", request.Data, request.Meta);
                using var call = _client.TalkOneAnswerMore(request, BuildHeaders());
                var responseStream = call.ResponseStream;
                while (await responseStream.MoveNext())
                {
                    var talkResponse = responseStream.Current;
                    PrintResponse(talkResponse);
                }
            }
            catch (RpcException e)
            {
                Console.Error.WriteLine(e);
            }
        }

        private async Task TalkMoreAnswerOne()
        {
            try
            {
                using var call = _client.TalkMoreAnswerOne(BuildHeaders());
                for (var i = 0; i < 3; ++i)
                {
                    var request = new TalkRequest
                    {
                        Data = _random.Next(5).ToString(),
                        Meta = "C#"
                    };
                    Console.WriteLine("Request: data={0},meta={1}", request.Data, request.Meta);
                    await call.RequestStream.WriteAsync(request);
                    await Task.Delay(_random.Next(100) + 100);
                }
                await call.RequestStream.CompleteAsync();
                var talkResponse = await call.ResponseAsync;
                PrintResponse(talkResponse);
            }
            catch (RpcException e)
            {
                Console.Error.WriteLine(e);
            }
        }

        private async Task TalkBidirectional()
        {
            try
            {
                using var call = _client.TalkBidirectional(BuildHeaders());
                var responseReaderTask = Task.Run(async () =>
                {
                    while (await call.ResponseStream.MoveNext())
                    {
                        var talkResponse = call.ResponseStream.Current;
                        PrintResponse(talkResponse);
                    }
                });

                for (var i = 0; i < 3; ++i)
                {
                    var request = new TalkRequest
                    {
                        Data = _random.Next(5).ToString(),
                        Meta = "C#"
                    };
                    Console.WriteLine("Request: data={0},meta={1}", request.Data, request.Meta);
                    await call.RequestStream.WriteAsync(request);
                    await Task.Delay(_random.Next(100) + 100);
                }
                await call.RequestStream.CompleteAsync();
                await responseReaderTask;
            }
            catch (RpcException e)
            {
                Console.Error.WriteLine(e);
            }
        }

        private static Metadata BuildHeaders()
        {
            var headers = new Metadata
            {
                new Metadata.Entry("k1", "v1"),
                new Metadata.Entry("k2", "v2")
            };
            return headers;
        }

        private static void PrintResponse(TalkResponse talkResponse)
        {
            foreach (var result in talkResponse.Results)
            {
                var kv = result.Kv;
                Console.WriteLine("{0} {1} [{2} {3} {4},{5}:{6}]", talkResponse.Status, result.Id,
                    kv["meta"], result.Type, kv["id"], kv["idx"], kv["data"]);
            }
        }
    }
}