<?php
/**
 * Landing Service Implementation for gRPC
 * 
 * Implements the four types of gRPC service patterns:
 * - Unary RPC (Talk)
 * - Server Streaming RPC (TalkOneAnswerMore)
 * - Client Streaming RPC (TalkMoreAnswerOne)
 * - Bidirectional Streaming RPC (TalkBidirectional)
 * 
 * Features:
 * - Backend service proxying
 * - Comprehensive error handling
 * - Tracing header propagation
 * - Performance optimizations
 */

use Grpc\ServerCallReader;
use Grpc\ServerCallWriter;
use Grpc\ServerContext;
use Hello\TalkRequest;
use Hello\TalkResponse;
use Hello\TalkResult;
use Hello\ResultType;
use Ramsey\Uuid\Uuid;
use Monolog\Logger;
use Monolog\Handler\StreamHandler;
use Monolog\Handler\RotatingFileHandler;
use Monolog\Formatter\LineFormatter;
use Common\Utils\Otel;

require_once __DIR__ . '/vendor/autoload.php';
require_once __DIR__ . '/common/msg/Hello/TalkRequest.php';
require_once __DIR__ . '/common/msg/Hello/TalkResponse.php';
require_once __DIR__ . '/common/msg/Hello/TalkResult.php';
require_once __DIR__ . '/common/svc/Hello/LandingServiceInterface.php';
require_once __DIR__ . '/common/svc/Hello/LandingServiceStub.php';
require_once __DIR__ . '/common/utils/Otel.php';

/**
 * Translation responses for different greetings
 */
$translations = [
    "你好" => "非常感谢",
    "Hello" => "Thank you very much",
    "Bonjour" => "Merci beaucoup",
    "Hola" => "Muchas Gracias",
    "こんにちは" => "どうも ありがとう ございます",
    "Ciao" => "Mille Grazie",
    "안녕하세요" => "대단히 감사합니다",
];

use Hello\LandingServiceInterface;

/**
 * Available greetings in different languages
 */
$greetings = [
    "Hello",      // English
    "Bonjour",    // French
    "Hola",       // Spanish
    "こんにちは",   // Japanese
    "Ciao",       // Italian
    "안녕하세요"    // Korean
];

// Define tracing headers to forward to backend
$tracingHeaders = [
    'x-request-id',
    'x-b3-traceid',
    'x-b3-spanid', 
    'x-b3-parentspanid',
    'x-b3-sampled',
    'x-b3-flags',
    'x-ot-span-context'
];

// Create logger
$log = new Logger('HelloTest');

// Create console handler with a specific format - 将日志级别设为DEBUG确保所有日志都能显示
$consoleHandler = new StreamHandler('php://stdout', Logger::DEBUG);
// 使用简单格式确保日志正确显示
$consoleFormat = new LineFormatter("[%datetime%] %message%\n");
$consoleHandler->setFormatter($consoleFormat);
$log->pushHandler($consoleHandler);

// Create file handler
$fileHandler = new RotatingFileHandler(__DIR__ . '/log/hello-grpc.log', 5, Logger::DEBUG);
$fileFormat = new LineFormatter("[%datetime%] %channel%.%level_name%: %message%\n");
$fileHandler->setFormatter($fileFormat);
$log->pushHandler($fileHandler);

// 添加启动时的测试日志，验证日志系统工作正常
$log->info("======= PHP gRPC服务端启动，日志系统初始化完成 =======");

/**
 * LandingService implementation with performance tracking and resiliency
 *
 * This class implements the gRPC LandingService for PHP with comprehensive
 * error handling, metrics tracking, and proxy support.
 *
 * @author Hello gRPC Team
 */

use Hello\LandingServiceStub;

class LandingService extends LandingServiceStub
{
    /**
     * Backend client for proxy mode
     * @var Hello\LandingServiceClient
     */
    private $backendClient;
    
    /**
     * Whether we're running in proxy mode
     * @var bool
     */
    private $isProxyMode;
    
    /**
     * Performance metrics tracker
     * @var array
     */
    private $metrics;

    /**
     * Service-level middleware chain.
     * @var array<int, callable>
     */
    private array $middleware;
    
    /**
     * Constructor
     *
     * @param Hello\LandingServiceClient|null $backendClient Backend client for proxy mode
     */
    public function __construct($backendClient = null)
    {
        global $log;
        
        $this->backendClient = $backendClient;
        $this->isProxyMode = ($backendClient !== null);
        
        if ($this->isProxyMode) {
            $log->info("LandingService initialized in proxy mode");
        } else {
            $log->info("LandingService initialized in standalone mode");
        }
        
        // Initialize metrics
        $this->metrics = [
            'request_count' => 0,
            'success_count' => 0,
            'error_count' => 0,
            'proxy_success' => 0,
            'proxy_error' => 0,
            'local_fallback' => 0,
        ];

        $this->middleware = [
            function (string $method, $context, callable $next) {
                global $log;
                $log->debug("[middleware] {$method} start");
                try {
                    return $next();
                } finally {
                    $log->debug("[middleware] {$method} end");
                }
            },
            function (string $method, $context, callable $next) {
                return Otel::wrapper($method, $next, [
                    'rpc.method' => $method,
                    'rpc.system' => 'grpc',
                    'rpc.service' => 'LandingService',
                ]);
            },
        ];
    }

    /**
     * Run a service handler through the configured middleware chain.
     */
    private function runWithMiddleware(string $method, $context, callable $handler)
    {
        $runner = array_reduce(
            array_reverse($this->middleware),
            function (callable $next, callable $middleware) use ($method, $context): callable {
                return function () use ($middleware, $method, $context, $next) {
                    return $middleware($method, $context, $next);
                };
            },
            $handler
        );

        return $runner();
    }
    
    /**
     * Destructor - log metrics
     */
    public function __destruct()
    {
        global $log;
        
        // Log metrics on shutdown if we handled any requests
        if ($this->metrics['request_count'] > 0) {
            $log->info(sprintf(
                "Service metrics: %d requests (%d successful, %d errors), " .
                "Proxy: %d successful, %d errors, %d local fallbacks",
                $this->metrics['request_count'],
                $this->metrics['success_count'],
                $this->metrics['error_count'],
                $this->metrics['proxy_success'],
                $this->metrics['proxy_error'],
                $this->metrics['local_fallback']
            ));
        }
    }
    
    /**
     * Extract and enhance the metadata from gRPC context
     * 
     * @param mixed $context The gRPC call context
     * @return array Enhanced metadata with tracing information
     */
    private function extractMetadata($context): array
    {
        $metadata = [];
        
        // Get metadata from context using clientMetadata() method
        $md = $context->clientMetadata();
        if (!empty($md)) {
            foreach ($md as $key => $value) {
                // Handle metadata values correctly - in PHP gRPC, metadata values should be strings, not arrays
                if (is_array($value)) {
                    // If an array is provided, use the first value
                    $metadata[$key] = $value[0] ?? '';
                } else {
                    $metadata[$key] = $value;
                }
            }
        }
        
        // Add or ensure request ID for tracing
        if (empty($metadata['request-id']) && empty($metadata['x-request-id'])) {
            $metadata['request-id'] = uniqid('php-', true);
        } else if (!empty($metadata['x-request-id']) && empty($metadata['request-id'])) {
            // Copy x-request-id to request-id for consistency
            $metadata['request-id'] = $metadata['x-request-id'];
        }
        
        // Add timestamp
        $metadata['timestamp'] = time();
        
        // Add originating service
        $metadata['service'] = 'php-landing-service';
        
        return $metadata;
    }

    /**
     * Convert extracted metadata to the flat string map expected by PHP gRPC clients.
     */
    private function toGrpcMetadata(array $metadata): array
    {
        $grpcMetadata = [];
        foreach ($metadata as $key => $value) {
            if (is_array($value)) {
                $first = $value[0] ?? '';
                $grpcMetadata[$key] = (string)$first;
            } else {
                $grpcMetadata[$key] = (string)$value;
            }
        }
        return $grpcMetadata;
    }
    
    /**
     * Log request context with metadata
     * 
     * @param string $method RPC method name
     * @param mixed $context gRPC context
     * @param mixed $request The request object (optional)
     */
    private function logRequest(string $method, $context, $request = null): void
    {
        global $log;
        
        $metadata = $this->extractMetadata($context);
        $requestId = $metadata['request-id'] ?? 'unknown';
        if (is_array($requestId)) {
            $requestId = $requestId[0] ?? 'unknown';
        }
        
        $requestData = '';
        $requestMeta = '';
        
        if ($request instanceof TalkRequest) {
            $requestData = $request->getData();
            $requestMeta = $request->getMeta();
            $log->info(sprintf(
                "[SERVER] RPC %s [%s]: data=%s, meta=%s", 
                $method, 
                $requestId, 
                $requestData, 
                $requestMeta
            ));
        } else {
            $log->info(sprintf("[SERVER] RPC %s [%s] - Request received", $method, $requestId));
        }
        
        $this->metrics['request_count']++;
    }
    
    /**
     * Log a successful response
     * 
     * @param string $method RPC method name
     * @param mixed $response The response object
     */
    private function logSuccess(string $method, $response = null): void
    {
        global $log;
        $this->metrics['success_count']++;
        
        if ($response instanceof TalkResponse) {
            $log->info(sprintf(
                "[SERVER] RPC %s completed: status=%d, results=%d",
                $method,
                $response->getStatus(),
                count($response->getResults())
            ));
        } else {
            $log->info(sprintf("[SERVER] RPC %s completed successfully", $method));
        }
    }
    
    /**
     * Log an error that occurred during RPC execution
     * 
     * @param string $method RPC method name 
     * @param string $error Error message
     * @param bool $isProxyError Whether error occurred in proxy mode
     */
    private function logError(string $method, string $error, bool $isProxyError = false): void
    {
        global $log;
        $this->metrics['error_count']++;
        
        if ($isProxyError) {
            $this->metrics['proxy_error']++;
            $log->error(sprintf("RPC %s proxy error: %s", $method, $error));
        } else {
            $log->error(sprintf("RPC %s error: %s", $method, $error));
        }
    }
    
    /**
     * Create a standardized response object
     * 
     * @param int $status Status code
     * @param array $results Array of result data
     * @return TalkResponse The response object
     */
    private function createResponse(int $status, array $results = []): TalkResponse
    {
        $response = new TalkResponse();
        $response->setStatus($status);
        
        $talkResults = [];
        foreach ($results as $index => $data) {
            $result = new TalkResult();
            $result->setId($index);
            $result->setType($data['type'] ?? ResultType::OK);
            
            // Set key-value map
            $kvMap = [
                'id' => (string)($data['id'] ?? $index),
                'idx' => (string)($data['idx'] ?? $index),
                'data' => (string)($data['data'] ?? ''),
                'meta' => (string)($data['meta'] ?? '')
            ];
            $result->setKv($kvMap);
            
            $talkResults[] = $result;
        }
        
        $response->setResults($talkResults);
        return $response;
    }
    
    /**
     * Process a request locally
     * 
     * @param TalkRequest $request The request to process
     * @param array $metadata Request metadata
     * @return TalkResponse The generated response
     */
    private function processLocally(TalkRequest $request, array $metadata = []): TalkResponse
    {
        $results = [];
        $status = 0;
        
        // Parse data parameter (might be comma-separated indices)
        $dataParam = $request->getData();
        $indices = explode(',', $dataParam);
        
        // Standard greetings to choose from
        $greetings = [
            'Hello',
            'Bonjour',
            'Hola',
            'こんにちは',
            'Ciao',
            '안녕하세요'
        ];
        
        foreach ($indices as $idx => $index) {
            if (!$this->isValidData((string)$index, count($greetings))) {
                throw new \InvalidArgumentException(
                    'data must be an integer between 0 and ' . (count($greetings) - 1)
                );
            }
            $greetingIndex = (int)$index;
            
            // Generate result data
            $results[] = [
                'id' => $idx,
                'idx' => $index,
                'type' => ResultType::OK,
                'data' => $greetings[$greetingIndex],
                'meta' => 'PHP'
            ];
        }
        
        return $this->createResponse($status, $results);
    }

    private function isValidData(string $data, int $size = 6): bool
    {
        return preg_match('/^\d+$/', $data) === 1
            && (int)$data >= 0
            && (int)$data < $size;
    }

    private function rejectInvalidData(ServerContext $context, string $data, int $size = 6): bool
    {
        if ($this->isValidData($data, $size)) {
            return false;
        }
        $context->setStatus(\Grpc\Status::status(
            \Grpc\STATUS_INVALID_ARGUMENT,
            'data must be an integer between 0 and ' . ($size - 1)
        ));
        return true;
    }
    
    /**
     * Implements the Talk unary RPC method
     */
    public function Talk(TalkRequest $request, \Grpc\ServerContext $context): ?TalkResponse
    {
        return $this->runWithMiddleware('Talk', $context, function () use ($request, $context) {
            $this->logRequest('Talk', $context, $request);
            $metadata = $this->extractMetadata($context);

            // If proxy mode is enabled, try to call backend first
            if ($this->isProxyMode) {
                try {
                    // Convert our internal metadata format to gRPC format
                    $md = $this->toGrpcMetadata($metadata);

                    // Set timeout
                    $options = ['timeout' => 5000000]; // 5 seconds (in microseconds)

                    // Call backend
                    list($response, $status) = $this->backendClient->Talk($request, $md, $options)->wait();

                    // Handle response from backend
                    if ($status->code === 0 && $response instanceof TalkResponse) {
                        $this->metrics['proxy_success']++;
                        $this->logSuccess('Talk', $response);
                        return $response;
                    } else {
                        throw new \Exception("Backend returned error code: " . $status->code);
                    }
                } catch (\Exception $e) {
                    $this->logError('Talk', $e->getMessage(), true);

                    // Fall back to local processing
                    $this->metrics['local_fallback']++;
                }
            }

            // Process locally
            try {
                if ($this->rejectInvalidData($context, $request->getData())) {
                    return null;
                }
                $response = $this->processLocally($request, $metadata);
                $this->logSuccess('Talk', $response);
                return $response;
            } catch (\Exception $e) {
                $this->logError('Talk', $e->getMessage());
                throw $e;
            }
        });
    }
    
    /**
     * Implements the TalkOneAnswerMore server streaming RPC method
     */
    public function TalkOneAnswerMore(
        TalkRequest $request,
        \Grpc\ServerCallWriter $writer,
        \Grpc\ServerContext $context
    ): void
    {
        $this->runWithMiddleware('TalkOneAnswerMore', $context, function () use ($request, $writer, $context) {
            $this->logRequest('TalkOneAnswerMore', $context, $request);
            $metadata = $this->extractMetadata($context);

            // If proxy mode, try to handle through backend
            if ($this->isProxyMode) {
                try {
                    // Convert metadata to gRPC format
                    $md = $this->toGrpcMetadata($metadata);

                    $options = ['timeout' => 15000000]; // 15 seconds
                    $call = $this->backendClient->TalkOneAnswerMore($request, $md, $options);
                    $responseStream = $call->responses();

                    // Proxy each response from backend
                    $responseCount = 0;
                    foreach ($responseStream as $response) {
                        // PHP gRPC doesn't support cancellation check

                        if ($response instanceof TalkResponse) {
                            $responseCount++;
                            $writer->write($response);
                        }
                    }

                    $this->metrics['proxy_success']++;
                    $this->logSuccess('TalkOneAnswerMore');
                    $writer->finish();
                    return;
                } catch (\Exception $e) {
                    $this->logError('TalkOneAnswerMore', $e->getMessage(), true);
                    // Fall back to local processing
                    $this->metrics['local_fallback']++;
                }
            }

            // Process locally - generate multiple responses
            try {
                // Parse data parameter (comma-separated indices)
                $dataParam = $request->getData();
                $indices = explode(',', $dataParam);

                foreach ($indices as $index) {
                    if ($this->rejectInvalidData($context, (string)$index)) {
                        $writer->finish();
                        return;
                    }
                }

                // For each index, create a separate response
                foreach ($indices as $idx => $index) {
                    // PHP gRPC doesn't support cancellation check

                    // Create individual response
                    $results = [[
                        'id' => $idx,
                        'idx' => $index,
                        'type' => ResultType::OK,
                        'data' => 'Stream message ' . ($idx + 1),
                        'meta' => 'PHP'
                    ]];

                    $response = $this->createResponse(0, $results);
                    $writer->write($response);

                    // Small delay between responses to simulate processing time
                    usleep(200000); // 200ms
                }

                // Explicitly finish the stream to signal end to the client
                $writer->finish();

                $this->logSuccess('TalkOneAnswerMore');
                $this->metrics['success_count']++;
            } catch (\Exception $e) {
                $this->logError('TalkOneAnswerMore', $e->getMessage());
                throw $e;
            }
        });
    }
    
    /**
     * Implements the TalkMoreAnswerOne client streaming RPC method
     * 
     * @param \Grpc\ServerCallReader $reader reader for client streaming
     * @param \Grpc\ServerContext $context gRPC context
     * @return ?TalkResponse Single response for all requests
     */
    public function TalkMoreAnswerOne(
        \Grpc\ServerCallReader $reader,
        \Grpc\ServerContext $context
    ): ?TalkResponse
    {
        return $this->runWithMiddleware('TalkMoreAnswerOne', $context, function () use ($reader, $context) {
            $this->logRequest('TalkMoreAnswerOne', $context);
            $metadata = $this->extractMetadata($context);
            $allResults = [];
            $requestCount = 0;
            $meta = '';

            // If proxy mode, try to handle through backend
            if ($this->isProxyMode) {
                try {
                    // Convert metadata
                    $md = $this->toGrpcMetadata($metadata);

                    $options = ['timeout' => 10000000]; // 10 seconds
                    $backendCall = $this->backendClient->TalkMoreAnswerOne($md, $options);

                    // Read all requests from the client and forward to backend
                    while ($requestObj = $reader->read()) {
                        if ($requestObj instanceof TalkRequest) {
                            $requestCount++;
                            // Store the meta from the last request received
                            $meta = $requestObj->getMeta();

                            // Forward to backend
                            $backendCall->write($requestObj);
                        }
                    }

                    // Close the call and wait for the response
                    list($response, $status) = $backendCall->wait();

                    if ($status->code === 0 && $response instanceof TalkResponse) {
                        $this->metrics['proxy_success']++;
                        $this->logSuccess('TalkMoreAnswerOne', $response);
                        return $response;
                    } else {
                        throw new \Exception("Backend returned error code: " . $status->code);
                    }
                } catch (\Exception $e) {
                    $this->logError('TalkMoreAnswerOne', $e->getMessage(), true);
                    // Fall back to local processing - but we need to read all requests first
                    while ($reader->read()) {
                        $requestCount++;
                    }
                    $this->metrics['local_fallback']++;
                }
            } else {
                // Read all requests and accumulate results
                while ($requestObj = $reader->read()) {
                    if ($requestObj instanceof TalkRequest) {
                        $requestCount++;

                        // Use meta from the last request
                        $meta = $requestObj->getMeta();

                        // Process each request
                        $data = $requestObj->getData();
                        if ($this->rejectInvalidData($context, $data)) {
                            return null;
                        }
                        $allResults[] = [
                            'id' => $requestCount,
                            'idx' => $data,
                            'type' => ResultType::OK,
                            'data' => 'Response from request ' . $requestCount,
                            'meta' => 'PHP'
                        ];
                    }
                }
            }

            // Process locally - create one response with all results
            try {
                $response = $this->createResponse(0, $allResults);
                $this->logSuccess('TalkMoreAnswerOne', $response);
                return $response;
            } catch (\Exception $e) {
                $this->logError('TalkMoreAnswerOne', $e->getMessage());
                throw $e;
            }
        });
    }
    
    /**
     * Implements the TalkBidirectional bidirectional streaming RPC method
     */
    public function TalkBidirectional(
        \Grpc\ServerCallReader $reader,
        \Grpc\ServerCallWriter $writer,
        \Grpc\ServerContext $context
    ): void
    {
        $this->runWithMiddleware('TalkBidirectional', $context, function () use ($reader, $writer, $context) {
            $this->logRequest('TalkBidirectional', $context);
            $metadata = $this->extractMetadata($context);
            $requestCount = 0;
            $responseCount = 0;

            // If proxy mode, try to handle through backend
            if ($this->isProxyMode) {
                try {
                    // Convert metadata
                    $md = $this->toGrpcMetadata($metadata);

                    $options = ['timeout' => 20000000]; // 20 seconds
                    $backendCall = $this->backendClient->TalkBidirectional($md, $options);

                    // Use non-blocking processing with cooperative multitasking
                    while (true) {
                        // PHP gRPC doesn't support cancellation check

                        // Try to read from client
                        $request = $reader->read();
                        if ($request !== null) {
                            $requestCount++;
                            // Forward to backend
                            $backendCall->write($request);
                        } else if ($reader->writesDone()) {
                            // Client is done writing
                            $backendCall->writesDone();
                            break;
                        }

                        // Try to read response from backend
                        $response = $backendCall->read();
                        if ($response !== null) {
                            $responseCount++;
                            // Forward to client
                            $writer->write($response);
                        }

                        // Small yield to avoid CPU spinning
                        usleep(50000); // 50ms
                    }

                    // Continue reading responses until end of stream
                    while ($response = $backendCall->read()) {
                        // PHP gRPC doesn't support cancellation check
                        $writer->write($response);
                    }

                    $this->metrics['proxy_success']++;
                    $this->logSuccess('TalkBidirectional');
                    $writer->finish();
                    return;
                } catch (\Exception $e) {
                    $this->logError('TalkBidirectional', $e->getMessage(), true);
                    // Fall back to local processing
                    $this->metrics['local_fallback']++;

                    // Clear the read buffer to avoid hanging
                    while ($reader->read() !== null) {
                        // Just drain the buffer
                    }
                }
            }

            // Process locally with bidirectional streaming
            try {
                $requestIndex = 0;

                // Keep processing until client is done or call is cancelled
                while (true) {
                    // Read request
                    $request = $reader->read();

                    if ($request === null) {
                        // Client closed the writing stream, we're done
                        break;
                    }

                    // Got a request, process it
                    $requestIndex++;
                    $requestCount++;

                    if ($request instanceof TalkRequest) {
                        if ($this->rejectInvalidData($context, $request->getData())) {
                            $writer->finish();
                            return;
                        }
                        // Create and send response
                        $results = [[
                            'id' => $requestIndex,
                            'idx' => $request->getData(),
                            'type' => ResultType::OK,
                            'data' => "Bidirectional response $requestIndex",
                            'meta' => 'PHP'
                        ]];

                        $response = $this->createResponse(0, $results);
                        $writer->write($response);
                        $responseCount++;
                    }
                }

                // Explicitly finish the stream to signal end to the client
                $writer->finish();

                $this->logSuccess('TalkBidirectional');
                $this->metrics['success_count']++;
            } catch (\Exception $e) {
                $this->logError('TalkBidirectional', $e->getMessage());
                throw $e;
            }
        });
    }
}
