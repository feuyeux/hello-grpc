using System;
using System.IO;
using System.Reflection;
using System.Threading.Tasks;
using Common;
using Grpc.Core;
using Hello;
using log4net;
using log4net.Config;

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
            // 获取程序集所在目录作为基准目录
            string baseDirectory = AppDomain.CurrentDomain.BaseDirectory;
            string configPath = Path.Combine(baseDirectory, "log4net.config");
            
            if (!File.Exists(configPath))
            {
                // 如果在基准目录中找不到文件，尝试在当前目录或项目目录中查找
                string currentDirectory = Directory.GetCurrentDirectory();
                string projectDir = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location) ?? "";
                
                if (File.Exists("log4net.config"))
                    configPath = "log4net.config";
                else if (File.Exists(Path.Combine(currentDirectory, "log4net.config")))
                    configPath = Path.Combine(currentDirectory, "log4net.config");
                else if (File.Exists(Path.Combine(projectDir, "log4net.config")))
                    configPath = Path.Combine(projectDir, "log4net.config");
                else
                    Console.WriteLine($"Warning: log4net.config not found at {configPath}, {currentDirectory}, or {projectDir}");
            }
            
            Console.WriteLine($"Loading log4net configuration from: {configPath}");
            
            var logRepository = LogManager.GetRepository(Assembly.GetEntryAssembly()!);
            XmlConfigurator.Configure(logRepository, new FileInfo(configPath));
            
            Console.WriteLine("Log4net configuration loaded, starting client...");

            // 确保控制台输出使用最低的缓冲区设置
            Console.SetOut(new StreamWriter(Console.OpenStandardOutput()) { AutoFlush = true });
            
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