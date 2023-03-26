using System;
using System.IO;
using System.Reflection;
using System.Threading.Tasks;
using Common;
using Grpc.Core;
using log4net;
using log4net.Config;
using Org.Feuyeux.Grpc;

namespace HelloClient
{
    public class ProtoClient
    {
        private static readonly ILog Log = LogManager.GetLogger(typeof(ProtoClient));
        private readonly LandingService.LandingServiceClient _client;

        private ProtoClient(LandingService.LandingServiceClient client)
        {
            this._client = client;
        }

        public static void Main()
        {
            var logRepository = LogManager.GetRepository(Assembly.GetEntryAssembly());
            XmlConfigurator.Configure(logRepository, new FileInfo("log4net.config"));

            var channel = Connection.GetChannel();
            var client = new ProtoClient(new LandingService.LandingServiceClient(channel));
            Log.Info("Unary RPC");
            client.Talk();
            Log.Info("Server streaming RPC");
            client.TalkOneAnswerMore().Wait();
            Log.Info("Client streaming RPC");
            client.TalkMoreAnswerOne().Wait();
            Log.Info("Bidirectional streaming RPC");
            client.TalkBidirectional().Wait();
            channel.ShutdownAsync().Wait();
            Log.Info("DONE");
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
                Log.Info($"Request: data={request.Data},meta={request.Meta}");
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
                Log.Info($"Request: data={request.Data},meta={request.Meta}");
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
                var requests = Utils.BuildLinkRequests();
                foreach (var request in requests){
                    Log.Info($"Request: data={request.Data},meta={request.Meta}");
                    await call.RequestStream.WriteAsync(request);
                    await Task.Delay(Utils.HelloRandom.Next(100) + 100);
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
                var requests = Utils.BuildLinkRequests();
                foreach (var request in requests)
                {
                    Log.Info($"Request: data={request.Data},meta={request.Meta}");
                    await call.RequestStream.WriteAsync(request);
                    await Task.Delay(Utils.HelloRandom.Next(100) + 100);
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
                Log.Info($"{talkResponse.Status} {result.Id} [{kv["meta"]} {result.Type} {kv["id"]},{kv["idx"]}:{kv["data"]}]");
            }
        }
    }
}