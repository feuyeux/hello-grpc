<?php

use Grpc\ChannelCredentials;
use Hello\LandingServiceClient;
use Hello\TalkRequest;
use Hello\TalkResponse;
use Hello\TalkResult;
use Monolog\Logger;
use Monolog\Handler\StreamHandler;
use Monolog\Handler\RotatingFileHandler;
use Monolog\Formatter\LineFormatter;

require dirname(__FILE__) . '/vendor/autoload.php';
require dirname(__FILE__) . '/conn/Connection.php';

// Constants for configuration
const MAX_RETRIES = 3;
const BASE_BACKOFF_MS = 500;
const STREAM_TIMEOUT_MS = 10000;
const DEFAULT_REQUEST_TIMEOUT_MS = 5000;
const BIDIRECTIONAL_READ_TIMEOUT_MS = 100;

// Create logger
$log = new Logger('HelloClient');

// Create console handler with a specific format
$consoleHandler = new StreamHandler('php://stdout', Logger::INFO);
$consoleFormat = new LineFormatter("[%datetime%] %level_name%: %message%\n");
$consoleHandler->setFormatter($consoleFormat);
$log->pushHandler($consoleHandler);

// Ensure log directory exists
$logDir = __DIR__ . '/log';
if (!is_dir($logDir)) {
    mkdir($logDir, 0777, true);
}

// Create file handler
$fileHandler = new RotatingFileHandler($logDir . '/hello-client.log', 5, Logger::INFO);
$fileFormat = new LineFormatter("[%datetime%] %channel%.%level_name%: %message%\n");
$fileHandler->setFormatter($fileFormat);
$log->pushHandler($fileHandler);

// Track execution metrics
$metrics = [
    'start_time' => microtime(true),
    'rpc_calls' => 0,
    'successful_calls' => 0,
    'failed_calls' => 0,
    'retries' => 0,
];

// Initialize connection configuration
$conn = new Connection();

// Setup signal handling for graceful shutdown
$shutdown = false;
if (function_exists('pcntl_signal')) {
    pcntl_signal(SIGTERM, function($signal) use (&$shutdown, $log) {
        $log->info("Received SIGTERM signal, initiating graceful shutdown");
        $shutdown = true;
    });

    pcntl_signal(SIGINT, function($signal) use (&$shutdown, $log) {
        $log->info("Received SIGINT signal, initiating graceful shutdown");
        $shutdown = true;
    });
}

// Check for signal if available
function checkShutdown() {
    global $shutdown;
    if (function_exists('pcntl_signal_dispatch')) {
        pcntl_signal_dispatch();
    }
    return $shutdown;
}

// Get server connection details
$host = getenv('GRPC_SERVER');
if (empty($host)) {
    $host = 'localhost';
}
$hostWithPort = $host . ':' . $conn->port;
$log->info(sprintf("Starting PHP gRPC client [version: %s]", getVersion()));
$log->info(sprintf("Connecting to: %s", $hostWithPort));

// Configure channel with TLS if needed
if ($conn->isSecure) {
    $log->info("Using TLS connection");
    // Check if certificate files exist
    if (!file_exists($conn->rootCertPath) || !file_exists($conn->certPath) || !file_exists($conn->keyPath)) {
        $log->warning("TLS certificate files not found, falling back to insecure connection");
        $credentials = ChannelCredentials::createInsecure();
    } else {
        try {
            // Configure TLS credentials
            $rootCert = file_get_contents($conn->rootCertPath);
            $clientCert = file_get_contents($conn->certPath);
            $clientKey = file_get_contents($conn->keyPath);
            
            $credentials = ChannelCredentials::createSsl(
                $rootCert,
                $clientKey,
                $clientCert
            );
            $log->info("TLS credentials created successfully");
        } catch (Exception $e) {
            $log->error("Error setting up TLS: " . $e->getMessage());
            $log->info("Falling back to insecure connection");
            $credentials = ChannelCredentials::createInsecure();
        }
    }
} else {
    $log->info("Using insecure connection");
    $credentials = ChannelCredentials::createInsecure();
}

// Create the gRPC client with optimized channel options
$client = new LandingServiceClient($hostWithPort, [
    'credentials' => $credentials,
    'grpc.keepalive_time_ms' => 30000,              // Send keepalive ping every 30 seconds
    'grpc.keepalive_timeout_ms' => 10000,           // Keepalive ping timeout after 10 seconds
    'grpc.http2.max_pings_without_data' => 0,       // Allow keepalive pings when there's no data
    'grpc.http2.min_time_between_pings_ms' => 25000,// Minimum time between pings
    'grpc.max_receive_message_length' => 8 * 1024 * 1024, // 8MB max message size
    'grpc.primary_user_agent' => 'hello-grpc-php-client/1.0.0',
]);

// Create a request ID for distributed tracing
$requestId = sprintf('%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
    mt_rand(0, 0xffff), mt_rand(0, 0xffff),
    mt_rand(0, 0xffff),
    mt_rand(0, 0x0fff) | 0x4000,
    mt_rand(0, 0x3fff) | 0x8000,
    mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff)
);

// Define standard metadata for all requests - using simple strings
// In PHP gRPC, metadata values must be strings, not arrays
$metadata = [];
// Keeping it minimal to avoid any potential issues

// Parse command arguments
$data = isset($argv[1]) ? $argv[1] : "0";
$meta = isset($argv[2]) ? $argv[2] : "PHP";
$iterations = isset($argv[3]) ? (int)$argv[3] : 1;

// Execute all four RPC types sequentially
try {
    for ($i = 1; $i <= $iterations; $i++) {
        if (checkShutdown()) {
            $log->info("Shutdown requested, stopping execution");
            break;
        }
        
        $log->info("====== Starting iteration $i/$iterations ======");
        
        // 1. Unary RPC
        $log->info("----- Executing unary RPC -----");
        measurePerformance("Unary RPC", function() use ($client, $data, $meta) {
            return unaryCall($client, $data, $meta);
        });
        
        if (checkShutdown()) break;
        
        // 2. Server streaming RPC
        $log->info("----- Executing server streaming RPC -----");
        measurePerformance("Server streaming RPC", function() use ($client, $data, $meta) {
            return serverStreaming($client, $data, $meta);
        });
        
        if (checkShutdown()) break;
        
        // 3. Client streaming RPC
        $log->info("----- Executing client streaming RPC -----");
        measurePerformance("Client streaming RPC", function() use ($client, $data, $meta) {
            return clientStreaming($client, $data, $meta);
        });
        
        if (checkShutdown()) break;
        
        // 4. Bidirectional streaming RPC
        $log->info("----- Executing bidirectional streaming RPC -----");
        measurePerformance("Bidirectional streaming RPC", function() use ($client, $data, $meta) {
            return bidirectionalStreaming($client, $data, $meta);
        });
        
        // Sleep between iterations unless it's the last one
        if ($i < $iterations && !checkShutdown()) {
            $log->info("Waiting 2 seconds before next iteration...");
            sleep(2);
        }
    }
} catch (Exception $e) {
    $metrics['failed_calls']++;
    $log->error("Fatal error executing RPC calls: " . $e->getMessage() . "\n" . $e->getTraceAsString());
} finally {
    // Print execution summary
    $executionTime = microtime(true) - $metrics['start_time'];
    $log->info(sprintf(
        "Execution completed in %.2f seconds: %d calls (%d successful, %d failed, %d retries)",
        $executionTime,
        $metrics['rpc_calls'],
        $metrics['successful_calls'],
        $metrics['failed_calls'],
        $metrics['retries']
    ));
}

/**
 * Get the client version
 */
function getVersion(): string {
    return "1.0.0"; // Placeholder - implement actual version retrieval if available
}

/**
 * Executes a unary RPC with retry mechanism
 */
function unaryCall($client, $data, $meta): void
{
    global $log, $metrics, $shutdown;
    $request = new TalkRequest();
    $request->setData($data);
    $request->setMeta($meta);
    
    // Using empty metadata to avoid "Bad metadata value given" errors
    $callMetadata = [];
    
    printRequest("Talk->", $request);
    $metrics['rpc_calls']++;
    
    $maxRetries = MAX_RETRIES;
    $retryCount = 0;
    $backoffMs = BASE_BACKOFF_MS;
    
    $options = [
        'timeout' => DEFAULT_REQUEST_TIMEOUT_MS * 1000, // Convert to microseconds
    ];
    
    while ($retryCount <= $maxRetries) {
        if ($shutdown) {
            $log->info("Shutdown requested during unary call, aborting");
            return;
        }
        
        try {
            list($response, $status) = $client->Talk($request, $callMetadata, $options)->wait();
            
            if ($status->code === \Grpc\STATUS_OK) {
                if ($response) {
                    printResponse("Talk<-", $response);
                    $metrics['successful_calls']++;
                }
                return;
            }
            
            // Handle retriable status codes
            if (in_array($status->code, [
                \Grpc\STATUS_UNAVAILABLE,
                \Grpc\STATUS_ABORTED,
                \Grpc\STATUS_DEADLINE_EXCEEDED
            ])) {
                $retryCount++;
                $metrics['retries']++;
                $log->warning("RPC failed, retrying ({$retryCount}/{$maxRetries}): " . $status->details);
                
                // Exponential backoff with jitter
                $jitter = mt_rand(-100, 100) / 1000; // +/- 100ms jitter
                $sleepMs = $backoffMs * pow(2, $retryCount - 1) + $jitter * $backoffMs;
                usleep($sleepMs * 1000);
                
                continue;
            }
            
            // Non-retriable error
            $log->error("Non-retriable gRPC error: " . $status->details);
            $metrics['failed_calls']++;
            break;
        } catch (Exception $e) {
            $log->error("Exception during RPC call: " . $e->getMessage());
            $retryCount++;
            $metrics['retries']++;
            
            if ($retryCount > $maxRetries) {
                $metrics['failed_calls']++;
                break;
            }
            
            // Exponential backoff with jitter for exceptions
            $jitter = mt_rand(-100, 100) / 1000;
            $sleepMs = $backoffMs * pow(2, $retryCount - 1) + $jitter * $backoffMs;
            usleep($sleepMs * 1000);
        }
    }
    
    $log->error("RPC failed after {$retryCount} attempts");
}

/**
 * Executes a server streaming RPC with tracing and timeout
 */
function serverStreaming($client, $data, $meta): void
{
    global $log, $metrics, $shutdown;
    $request = new TalkRequest();
    // Use a comma-separated list like Java implementation
    $request->setData("0,1,2");
    $request->setMeta($meta);
    
    // Using empty metadata to avoid "Bad metadata value given" errors
    $streamingMetadata = [];
    
    printRequest("TalkOneAnswerMore->", $request);
    $metrics['rpc_calls']++;
    
    $options = [
        'timeout' => STREAM_TIMEOUT_MS * 1000, // Convert to microseconds
    ];
    
    $startTime = microtime(true);
    try {
        $call = $client->TalkOneAnswerMore($request, $streamingMetadata, $options);
        $responses = $call->responses();
        $responseCount = 0;
        
        foreach ($responses as $response) {
            if ($shutdown) {
                $log->info("Shutdown requested during server streaming, breaking loop");
                break;
            }
            
            $responseCount++;
            if (!is_null($response)) {
                printResponse("TalkOneAnswerMore<-", $response);
            }
        }
        
        $duration = (microtime(true) - $startTime) * 1000;
        $log->info("Stream completed: {$responseCount} responses in {$duration}ms");
        $metrics['successful_calls']++;
    } catch (Exception $e) {
        $metrics['failed_calls']++;
        $log->error("Error in server streaming: " . $e->getMessage());
    }
}

/**
 * Executes a client streaming RPC with better error handling
 */
function clientStreaming($client, $data, $meta): void
{
    global $log, $metrics, $shutdown;
    
    // Using empty metadata to avoid "Bad metadata value given" errors
    $streamingMetadata = [];
    
    $log->info("Client streaming RPC - sending multiple requests");
    $metrics['rpc_calls']++;
    
    $options = [
        'timeout' => STREAM_TIMEOUT_MS * 1000, // Convert to microseconds
    ];
    
    try {
        $call = $client->TalkMoreAnswerOne($streamingMetadata, $options);
        $request = new TalkRequest();
        $request->setMeta($meta);
        
        // Send multiple requests with different data
        $requestCount = 3;
        for ($i = 0; $i < $requestCount; $i++) {
            if ($shutdown) {
                $log->info("Shutdown requested during client streaming, aborting");
                $call->cancel();
                return;
            }
            
            $request->setData(randomId());
            printRequest("TalkMoreAnswerOne->", $request);
            $call->write($request);
            usleep(500000); // 500ms delay
        }
        
        // Wait for response
        list($response, $status) = $call->wait();
        
        if ($status->code !== \Grpc\STATUS_OK) {
            checkStatus($status);
            $metrics['failed_calls']++;
            return;
        }
        
        if ($response) {
            printResponse("TalkMoreAnswerOne<-", $response);
            $metrics['successful_calls']++;
        }
    } catch (Exception $e) {
        $metrics['failed_calls']++;
        $log->error("Error in client streaming: " . $e->getMessage());
    }
}

/**
 * Improved bidirectional streaming implementation
 */
function bidirectionalStreaming($client, $data, $meta): void
{
    global $log, $metrics, $shutdown;
    
    // Using empty metadata to avoid "Bad metadata value given" errors
    $streamingMetadata = [];
    
    $log->info("Bidirectional streaming RPC");
    $metrics['rpc_calls']++;
    
    $options = [
        'timeout' => STREAM_TIMEOUT_MS * 1000, // Convert to microseconds
    ];
    
    try {
        $call = $client->TalkBidirectional($streamingMetadata, $options);
        $request = new TalkRequest();
        $request->setMeta($meta);
        
        // Send requests and read responses concurrently
        $requestCount = 5;
        $responseCount = 0;
        $requestsSent = 0;
        $completed = false;
        
        // Track last response time to detect end of stream
        $lastResponseTime = microtime(true);
        
        while (!$shutdown && !$completed) {
            // Send requests if we still have more to send
            if ($requestsSent < $requestCount) {
                $request->setData(randomId());
                printRequest("TalkBidirectional->", $request);
                $call->write($request);
                $requestsSent++;
                
                // Short delay between writes
                usleep(200000); // 200ms
            } else if ($requestsSent === $requestCount) {
                // Close sending side of stream once we've sent all requests
                $call->writesDone();
                $requestsSent++; // Increment to prevent calling writesDone multiple times
            }
            
            // Try to read a response if available
            $response = $call->read();
            if ($response !== null) {
                $responseCount++;
                printResponse("TalkBidirectional<-", $response);
                $lastResponseTime = microtime(true);
            } else {
                // No response available right now
                // If we've waited long enough since the last response and we're done sending,
                // assume the server is done too
                if ($requestsSent > $requestCount && 
                    microtime(true) - $lastResponseTime > (BIDIRECTIONAL_READ_TIMEOUT_MS / 1000)) {
                    $completed = true;
                } else {
                    // Small pause to avoid CPU spinning
                    usleep(50000); // 50ms
                }
            }
        }
        
        // Make sure stream is properly closed
        $call->cancel();
        
        if ($shutdown) {
            $log->info("Bidirectional streaming interrupted by shutdown request");
        } else {
            $log->info("Bidirectional streaming completed: sent {$requestCount} requests, received {$responseCount} responses");
            $metrics['successful_calls']++;
        }
    } catch (Exception $e) {
        $metrics['failed_calls']++;
        $log->error("Error in bidirectional streaming: " . $e->getMessage());
    }
}

/**
 * @return TalkRequest[]
 */
function buildLinkRequests(TalkRequest $baseRequest): iterable
{
    $requests = array();
    for ($i = 0; $i < 3; $i++) {
        $request = new TalkRequest();
        $request->setData(randomId());
        $request->setMeta($baseRequest->getMeta());
        $requests[$i] = $request;
    }
    return $requests;
}

/**
 * Generate a random ID from 0 to 5
 */
function randomId(): string
{
    return sprintf("%d", rand(0, 5));
}

/**
 * Print formatted request
 * 
 * @param string $callName
 * @param TalkRequest $request
 */
function printRequest(string $callName, TalkRequest $request): void
{
    global $log;
    $log->info(sprintf("%s data=%s, meta=%s", $callName, $request->getData(), $request->getMeta()));
}

/**
 * Print formatted response
 * 
 * @param string $callName
 * @param TalkResponse $response)
 */
function printResponse(string $callName, TalkResponse $response): void
{
    global $log;
    $resultsList = $response->getResults();
    $prefix = $callName;
    $length = count($resultsList);
    
    $log->info(sprintf("%s: status=%d, results=%d", $prefix, $response->getStatus(), $length));
    
    for ($i = 0; $i < $length; $i++) {
        $result = $resultsList[$i];
        $kv = $result->getKv();
        if (!is_array($kv)) {
            $log->info(sprintf("%s result #%d: id=%d, type=%s, kv=empty", 
                $prefix, $i+1, $result->getId(), $result->getType()));
            continue;
        }
        
        // Extract values with null safety
        $id = isset($kv["id"]) ? $kv["id"] : "unknown";
        $idx = isset($kv["idx"]) ? $kv["idx"] : "unknown";
        $data = isset($kv["data"]) ? $kv["data"] : "unknown";
        $meta = isset($kv["meta"]) ? $kv["meta"] : "unknown";
        
        $log->info(sprintf("%s result #%d: id=%d, type=%s, data=%s, meta=%s, id=%s, idx=%s",
            $prefix,
            $i+1,
            $result->getId(),
            $result->getType(), 
            $data,
            $meta,
            $id,
            $idx
        ));
    }
}

/**
 * Checks gRPC status and provides detailed error information
 * 
 * @param object $status The gRPC status object
 * @return void
 */
function checkStatus($status): void
{
    global $log;
    
    if ($status->code !== \Grpc\STATUS_OK) {
        $statusMap = [
            \Grpc\STATUS_CANCELLED => 'CANCELLED',
            \Grpc\STATUS_UNKNOWN => 'UNKNOWN',
            \Grpc\STATUS_INVALID_ARGUMENT => 'INVALID_ARGUMENT',
            \Grpc\STATUS_DEADLINE_EXCEEDED => 'DEADLINE_EXCEEDED',
            \Grpc\STATUS_NOT_FOUND => 'NOT_FOUND',
            \Grpc\STATUS_ALREADY_EXISTS => 'ALREADY_EXISTS',
            \Grpc\STATUS_PERMISSION_DENIED => 'PERMISSION_DENIED',
            \Grpc\STATUS_RESOURCE_EXHAUSTED => 'RESOURCE_EXHAUSTED',
            \Grpc\STATUS_FAILED_PRECONDITION => 'FAILED_PRECONDITION',
            \Grpc\STATUS_ABORTED => 'ABORTED',
            \Grpc\STATUS_OUT_OF_RANGE => 'OUT_OF_RANGE',
            \Grpc\STATUS_UNIMPLEMENTED => 'UNIMPLEMENTED',
            \Grpc\STATUS_INTERNAL => 'INTERNAL',
            \Grpc\STATUS_UNAVAILABLE => 'UNAVAILABLE',
            \Grpc\STATUS_DATA_LOSS => 'DATA_LOSS',
            \Grpc\STATUS_UNAUTHENTICATED => 'UNAUTHENTICATED',
        ];
        
        $statusName = $statusMap[$status->code] ?? "UNKNOWN_CODE_{$status->code}";
        $log->error("Call failed with status: {$statusName} ({$status->code}) - {$status->details}");
    }
}

/**
 * Measures and logs performance metrics for RPC calls
 * 
 * @param string $operation The operation name
 * @param callable $callback The callback function to measure
 * @return mixed The result of the callback
 */
function measurePerformance(string $operation, callable $callback)
{
    global $log;
    $startTime = microtime(true);
    $memoryStart = memory_get_usage();
    
    try {
        $result = $callback();
        $success = true;
    } catch (Exception $e) {
        $log->error("{$operation} failed with exception: {$e->getMessage()}");
        $success = false;
        throw $e; // Re-throw to handle at higher level
    } finally {
        $duration = (microtime(true) - $startTime) * 1000;
        $memoryUsed = memory_get_usage() - $memoryStart;
        
        if ($success) {
            $log->info(sprintf("%s completed in %.2fms (memory: %.2fKB)", 
                $operation, 
                $duration, 
                $memoryUsed / 1024
            ));
        }
    }
    
    return $result;
}