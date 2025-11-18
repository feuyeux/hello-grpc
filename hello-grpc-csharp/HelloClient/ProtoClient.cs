using System;
using System.Diagnostics;
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
    /// <summary>
    /// gRPC client implementation demonstrating all four RPC patterns.
    /// 
    /// This client follows the standardized structure:
    /// 1. Configuration constants
    /// 2. Logger initialization
    /// 3. Connection setup
    /// 4. RPC method implementations (unary, server streaming, client streaming, bidirectional)
    /// 5. Helper functions
    /// 6. Main execution function
    /// 7. Cleanup and shutdown
    /// </summary>
    public class ProtoClient
    {
        private static readonly ILog Log = LogManager.GetLogger(typeof(ProtoClient));
        
        // Configuration constants
        private const int RetryAttempts = 3;
        private const int RetryDelayMs = 2000;
        private const int IterationCount = 3;
        private const int RequestDelayMs = 200;
        private const int SendDelayMs = 2;
        private const int RequestTimeoutSeconds = 5;
        
        private readonly LandingService.LandingServiceClient _client;

        private ProtoClient(LandingService.LandingServiceClient client)
        {
            this._client = client;
        }

        public static void Main()
        {
            // Configure log4net
            ConfigureLogging();
            
            Log.Info($"Starting gRPC client [version: {Utils.GetVersion()}]");

            ProtoClient? protoClient = null;
            bool success = false;

            // Attempt to establish connection and run all patterns
            for (int attempt = 1; attempt <= RetryAttempts; attempt++)
            {
                Log.Info($"Connection attempt {attempt}/{RetryAttempts}");

                try
                {
                    var channel = Connection.GetChannel();
                    protoClient = new ProtoClient(new LandingService.LandingServiceClient(channel));

                    // Run all the gRPC patterns
                    RunGrpcCalls(protoClient, RequestDelayMs, IterationCount).Wait();
                    success = true;
                    
                    // Cleanup
                    channel.ShutdownAsync().Wait();
                    break; // Success, no retry needed
                }
                catch (Exception e)
                {
                    Log.Error($"Connection attempt {attempt} failed: {e.Message}");
                    if (attempt < RetryAttempts)
                    {
                        Log.Info($"Retrying in {RetryDelayMs}ms...");
                        Task.Delay(RetryDelayMs).Wait();
                    }
                    else
                    {
                        Log.Error("Maximum connection attempts reached, exiting");
                    }
                }
            }

            if (!success)
            {
                Log.Error("Failed to execute all gRPC calls successfully");
                Environment.Exit(1);
            }

            Log.Info("Client execution completed successfully");
        }

        /// <summary>
        /// Configures log4net logging framework
        /// </summary>
        private static void ConfigureLogging()
        {
            string baseDirectory = AppDomain.CurrentDomain.BaseDirectory;
            string configPath = Path.Combine(baseDirectory, "log4net.config");
            
            if (!File.Exists(configPath))
            {
                string currentDirectory = Directory.GetCurrentDirectory();
                string projectDir = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location) ?? "";
                
                if (File.Exists("log4net.config"))
                    configPath = "log4net.config";
                else if (File.Exists(Path.Combine(currentDirectory, "log4net.config")))
                    configPath = Path.Combine(currentDirectory, "log4net.config");
                else if (File.Exists(Path.Combine(projectDir, "log4net.config")))
                    configPath = Path.Combine(projectDir, "log4net.config");
            }
            
            var logRepository = LogManager.GetRepository(Assembly.GetEntryAssembly()!);
            XmlConfigurator.Configure(logRepository, new FileInfo(configPath));
            
            // Ensure console output uses auto-flush
            Console.SetOut(new StreamWriter(Console.OpenStandardOutput()) { AutoFlush = true });
        }

        /// <summary>
        /// Executes all four gRPC patterns multiple times
        /// </summary>
        /// <param name="client">The client instance to use</param>
        /// <param name="delayMs">Delay between iterations in milliseconds</param>
        /// <param name="iterations">Number of times to run all patterns</param>
        private static async Task RunGrpcCalls(ProtoClient client, int delayMs, int iterations)
        {
            for (int iteration = 1; iteration <= iterations; iteration++)
            {
                Log.Info($"====== Starting iteration {iteration}/{iterations} ======");

                // 1. Unary RPC
                Log.Info("----- Executing unary RPC -----");
                var unaryRequest = new TalkRequest { Data = "0", Meta = "C#" };
                var response = client.ExecuteUnaryCall(unaryRequest);
                LogResponse(response);

                // 2. Server streaming RPC
                Log.Info("----- Executing server streaming RPC -----");
                var serverStreamRequest = new TalkRequest { Data = "0,1,2", Meta = "C#" };
                await client.ExecuteServerStreamingCall(serverStreamRequest);

                // 3. Client streaming RPC
                Log.Info("----- Executing client streaming RPC -----");
                var clientStreamResponse = await client.ExecuteClientStreamingCall(Utils.BuildLinkRequests());
                LogResponse(clientStreamResponse);

                // 4. Bidirectional streaming RPC
                Log.Info("----- Executing bidirectional streaming RPC -----");
                await client.ExecuteBidirectionalStreamingCall(Utils.BuildLinkRequests());

                // Wait before next iteration, unless it's the last one
                if (iteration < iterations)
                {
                    Log.Info($"Waiting {delayMs}ms before next iteration...");
                    await Task.Delay(delayMs);
                }
            }

            Log.Info("All gRPC calls completed successfully");
        }

        /// <summary>
        /// Demonstrates the unary RPC pattern (single request, single response)
        /// </summary>
        /// <param name="request">The request to send</param>
        /// <returns>The response from the server</returns>
        public TalkResponse ExecuteUnaryCall(TalkRequest request)
        {
            string requestId = $"unary-{DateTime.Now.Ticks}";
            Log.Info($"Sending unary request: data={request.Data}, meta={request.Meta}");

            var stopwatch = Stopwatch.StartNew();
            try
            {
                var response = _client.Talk(request, BuildHeaders());
                stopwatch.Stop();
                Log.Info($"Unary call successful in {stopwatch.ElapsedMilliseconds}ms");
                return response;
            }
            catch (RpcException e)
            {
                ErrorMapper.LogError(e, requestId, "Talk");
                throw;
            }
        }

        /// <summary>
        /// Demonstrates the server streaming RPC pattern (single request, multiple responses)
        /// </summary>
        /// <param name="request">The request to send</param>
        public async Task ExecuteServerStreamingCall(TalkRequest request)
        {
            string requestId = $"server-stream-{DateTime.Now.Ticks}";
            Log.Info($"Starting server streaming with request: data={request.Data}, meta={request.Meta}");

            var stopwatch = Stopwatch.StartNew();
            int responseCount = 0;

            try
            {
                using var call = _client.TalkOneAnswerMore(request, BuildHeaders());
                var responseStream = call.ResponseStream;
                
                while (await responseStream.MoveNext())
                {
                    responseCount++;
                    var response = responseStream.Current;
                    Log.Info($"Received server streaming response #{responseCount}:");
                    LogResponse(response);
                }

                stopwatch.Stop();
                Log.Info($"Server streaming completed: received {responseCount} responses in {stopwatch.ElapsedMilliseconds}ms");
            }
            catch (RpcException e)
            {
                ErrorMapper.LogError(e, requestId, "TalkOneAnswerMore");
                throw;
            }
        }

        /// <summary>
        /// Demonstrates the client streaming RPC pattern (multiple requests, single response)
        /// </summary>
        /// <param name="requests">The list of requests to send</param>
        /// <returns>The response from the server</returns>
        public async Task<TalkResponse> ExecuteClientStreamingCall(System.Collections.Generic.LinkedList<TalkRequest> requests)
        {
            string requestId = $"client-stream-{DateTime.Now.Ticks}";
            Log.Info($"Starting client streaming with {requests.Count} requests");

            var stopwatch = Stopwatch.StartNew();
            int requestCount = 0;

            try
            {
                using var call = _client.TalkMoreAnswerOne(BuildHeaders());
                
                foreach (var request in requests)
                {
                    requestCount++;
                    Log.Info($"Sending client streaming request #{requestCount}: data={request.Data}, meta={request.Meta}");
                    await call.RequestStream.WriteAsync(request);
                    await Task.Delay(SendDelayMs);
                }
                
                await call.RequestStream.CompleteAsync();
                var response = await call.ResponseAsync;
                
                stopwatch.Stop();
                Log.Info($"Client streaming completed: sent {requestCount} requests in {stopwatch.ElapsedMilliseconds}ms");
                
                return response;
            }
            catch (RpcException e)
            {
                ErrorMapper.LogError(e, requestId, "TalkMoreAnswerOne");
                throw;
            }
        }

        /// <summary>
        /// Demonstrates the bidirectional streaming RPC pattern (multiple requests, multiple responses)
        /// </summary>
        /// <param name="requests">The list of requests to send</param>
        public async Task ExecuteBidirectionalStreamingCall(System.Collections.Generic.LinkedList<TalkRequest> requests)
        {
            string requestId = $"bidirectional-{DateTime.Now.Ticks}";
            Log.Info($"Starting bidirectional streaming with {requests.Count} requests");

            var stopwatch = Stopwatch.StartNew();
            int requestCount = 0;
            int responseCount = 0;

            try
            {
                using var call = _client.TalkBidirectional(BuildHeaders());
                
                // Start receiving responses in a separate task
                var responseReaderTask = Task.Run(async () =>
                {
                    while (await call.ResponseStream.MoveNext())
                    {
                        responseCount++;
                        var response = call.ResponseStream.Current;
                        Log.Info($"Received bidirectional streaming response #{responseCount}:");
                        LogResponse(response);
                    }
                });
                
                // Send all requests
                foreach (var request in requests)
                {
                    requestCount++;
                    Log.Info($"Sending bidirectional streaming request #{requestCount}: data={request.Data}, meta={request.Meta}");
                    await call.RequestStream.WriteAsync(request);
                    await Task.Delay(SendDelayMs);
                }
                
                // Close sending side
                Log.Info("Closing send side of bidirectional stream");
                await call.RequestStream.CompleteAsync();
                
                // Wait for receiving side to complete
                await responseReaderTask;
                
                stopwatch.Stop();
                Log.Info($"Bidirectional streaming completed in {stopwatch.ElapsedMilliseconds}ms");
            }
            catch (RpcException e)
            {
                ErrorMapper.LogError(e, requestId, "TalkBidirectional");
                throw;
            }
        }

        /// <summary>
        /// Builds standard metadata headers for requests
        /// </summary>
        /// <returns>Metadata with standard headers</returns>
        private static Metadata BuildHeaders()
        {
            var headers = new Metadata
            {
                new Metadata.Entry("k1", "v1"),
                new Metadata.Entry("k2", "v2")
            };
            return headers;
        }

        /// <summary>
        /// Logs the response in a standardized format
        /// </summary>
        /// <param name="response">The response to log</param>
        private static void LogResponse(TalkResponse response)
        {
            if (response == null)
            {
                Log.Warn("Received nil response");
                return;
            }

            int resultsCount = response.Results.Count;
            Log.Info($"Response status: {response.Status}, results: {resultsCount}");

            for (int i = 0; i < resultsCount; i++)
            {
                var result = response.Results[i];
                var kv = result.Kv;

                string meta = kv.ContainsKey("meta") ? kv["meta"] : "";
                string id = kv.ContainsKey("id") ? kv["id"] : "";
                string idx = kv.ContainsKey("idx") ? kv["idx"] : "";
                string data = kv.ContainsKey("data") ? kv["data"] : "";

                Log.Info($"  Result #{i + 1}: id={result.Id}, type={result.Type}, meta={meta}, id={id}, idx={idx}, data={data}");
            }
        }
    }
}