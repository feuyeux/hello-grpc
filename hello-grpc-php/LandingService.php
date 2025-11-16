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
use Ramsey\Uuid\Uuid;
use Monolog\Logger;
use Monolog\Handler\StreamHandler;
use Monolog\Handler\RotatingFileHandler;
use Monolog\Formatter\LineFormatter;

require_once __DIR__ . '/vendor/autoload.php';
require_once __DIR__ . '/common/msg/Hello/TalkRequest.php';
require_once __DIR__ . '/common/msg/Hello/TalkResponse.php';
require_once __DIR__ . '/common/msg/Hello/TalkResult.php';

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

class LandingService
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
        
        // Get metadata from context
        $md = $context->getMetadata();
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
            $result->setType($data['type'] ?? 0);
            
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
            'Hi',
            'Hey',
            'Greetings',
            'Welcome',
            'Bonjour',
            'Hola'
        ];
        
        foreach ($indices as $idx => $index) {
            // Parse index safely
            $greetingIndex = is_numeric($index) ? (int)$index : 0;
            
            // Ensure index is within bounds
            if ($greetingIndex < 0 || $greetingIndex >= count($greetings)) {
                $greetingIndex = 0;
            }
            
            // Generate result data
            $results[] = [
                'id' => $idx,
                'idx' => $index,
                'type' => 1,
                'data' => $greetings[$greetingIndex],
                'meta' => $request->getMeta()
            ];
        }
        
        return $this->createResponse($status, $results);
    }
    
    /**
     * Required by gRPC server to register service methods
     * Returns an array of method descriptors for the service
     *
     * @return array Method descriptors for the service
     */
    public static function getMethodDescriptors(): array
    {
        return [
            [
                'name' => 'Talk',
                'input_type' => '\Hello\TalkRequest',
                'output_type' => '\Hello\TalkResponse',
                'client_streaming' => false,
                'server_streaming' => false
            ],
            [
                'name' => 'TalkOneAnswerMore',
                'input_type' => '\Hello\TalkRequest',
                'output_type' => '\Hello\TalkResponse',
                'client_streaming' => false,
                'server_streaming' => true
            ],
            [
                'name' => 'TalkMoreAnswerOne',
                'input_type' => '\Hello\TalkRequest',
                'output_type' => '\Hello\TalkResponse',
                'client_streaming' => true,
                'server_streaming' => false
            ],
            [
                'name' => 'TalkBidirectional',
                'input_type' => '\Hello\TalkRequest',
                'output_type' => '\Hello\TalkResponse',
                'client_streaming' => true,
                'server_streaming' => true
            ]
        ];
    }
    
    /**
     * Implements the Talk unary RPC method
     */
    public function Talk(TalkRequest $request, $context): TalkResponse
    {
        $this->logRequest('Talk', $context, $request);
        $metadata = $this->extractMetadata($context);
        
        // If proxy mode is enabled, try to call backend first
        if ($this->isProxyMode) {
            try {
                // Convert our internal metadata format to gRPC format
                $md = [];
                foreach ($metadata as $key => $values) {
                    foreach ($values as $value) {
                        $md[$key] = $value;
                    }
                }
                
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
            $response = $this->processLocally($request, $metadata);
            $this->logSuccess('Talk', $response);
            return $response;
        } catch (\Exception $e) {
            $this->logError('Talk', $e->getMessage());
            throw $e;
        }
    }
    
    /**
     * Implements the TalkOneAnswerMore server streaming RPC method
     */
    public function TalkOneAnswerMore(TalkRequest $request, $context): void
    {
        $this->logRequest('TalkOneAnswerMore', $context, $request);
        $metadata = $this->extractMetadata($context);
        
        // If proxy mode, try to handle through backend
        if ($this->isProxyMode) {
            try {
                // Convert metadata to gRPC format
                $md = [];
                foreach ($metadata as $key => $values) {
                    foreach ($values as $value) {
                        $md[$key] = $value;
                    }
                }
                
                $options = ['timeout' => 15000000]; // 15 seconds
                $call = $this->backendClient->TalkOneAnswerMore($request, $md, $options);
                $responseStream = $call->responses();
                
                // Proxy each response from backend
                $responseCount = 0;
                foreach ($responseStream as $response) {
                    if ($context->isCancelled()) {
                        break; // Client cancelled the call
                    }
                    
                    if ($response instanceof TalkResponse) {
                        $responseCount++;
                        $context->write($response);
                    }
                }
                
                $this->metrics['proxy_success']++;
                $this->logSuccess('TalkOneAnswerMore');
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
            
            // For each index, create a separate response
            foreach ($indices as $idx => $index) {
                if ($context->isCancelled()) {
                    break; // Client cancelled, stop sending
                }
                
                // Create individual response
                $results = [[
                    'id' => $idx,
                    'idx' => $index,
                    'type' => 2,
                    'data' => 'Stream message ' . ($idx + 1),
                    'meta' => $request->getMeta()
                ]];
                
                $response = $this->createResponse(0, $results);
                $context->write($response);
                
                // Small delay between responses to simulate processing time
                usleep(200000); // 200ms
            }
            
            $this->logSuccess('TalkOneAnswerMore');
            $this->metrics['success_count']++;
        } catch (\Exception $e) {
            $this->logError('TalkOneAnswerMore', $e->getMessage());
            throw $e;
        }
    }
    
    /**
     * Implements the TalkMoreAnswerOne client streaming RPC method
     * 
     * @param $context gRPC context used for reading client streams
     * @return TalkResponse Single response for all requests
     */
    public function TalkMoreAnswerOne($context): TalkResponse
    {
        $this->logRequest('TalkMoreAnswerOne', $context);
        $metadata = $this->extractMetadata($context);
        $allResults = [];
        $requestCount = 0;
        $meta = '';
        
        // If proxy mode, try to handle through backend
        if ($this->isProxyMode) {
            try {
                // Convert metadata
                $md = [];
                foreach ($metadata as $key => $values) {
                    foreach ($values as $value) {
                        $md[$key] = $value;
                    }
                }
                
                $options = ['timeout' => 10000000]; // 10 seconds
                $backendCall = $this->backendClient->TalkMoreAnswerOne($md, $options);
                
                // Read all requests from the client and forward to backend
                while ($request = $context->read()) {
                    if ($request instanceof TalkRequest) {
                        $requestCount++;
                        // Store the meta from the last request received
                        $meta = $request->getMeta();
                        
                        // Forward to backend
                        $backendCall->write($request);
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
                while ($context->read()) {
                    $requestCount++;
                }
                $this->metrics['local_fallback']++;
            }
        } else {
            // Read all requests and accumulate results
            while ($request = $context->read()) {
                if ($request instanceof TalkRequest) {
                    $requestCount++;
                    
                    // Use meta from the last request
                    $meta = $request->getMeta();
                    
                    // Process each request
                    $data = $request->getData();
                    $allResults[] = [
                        'id' => $requestCount,
                        'idx' => $data,
                        'type' => 3,
                        'data' => 'Response from request ' . $requestCount,
                        'meta' => $meta
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
    }
    
    /**
     * Implements the TalkBidirectional bidirectional streaming RPC method
     */
    public function TalkBidirectional($context): void
    {
        $this->logRequest('TalkBidirectional', $context);
        $metadata = $this->extractMetadata($context);
        $requestCount = 0;
        $responseCount = 0;
        
        // If proxy mode, try to handle through backend
        if ($this->isProxyMode) {
            try {
                // Convert metadata
                $md = [];
                foreach ($metadata as $key => $values) {
                    foreach ($values as $value) {
                        $md[$key] = $value;
                    }
                }
                
                $options = ['timeout' => 20000000]; // 20 seconds
                $backendCall = $this->backendClient->TalkBidirectional($md, $options);
                
                // Use non-blocking processing with cooperative multitasking
                while (true) {
                    // Check if call was cancelled by client
                    if ($context->isCancelled()) {
                        $backendCall->cancel();
                        break;
                    }
                    
                    // Try to read from client
                    $request = $context->read();
                    if ($request !== null) {
                        $requestCount++;
                        // Forward to backend
                        $backendCall->write($request);
                    } else if ($context->writesDone()) {
                        // Client is done writing
                        $backendCall->writesDone();
                        break;
                    }
                    
                    // Try to read response from backend
                    $response = $backendCall->read();
                    if ($response !== null) {
                        $responseCount++;
                        // Forward to client
                        $context->write($response);
                    }
                    
                    // Small yield to avoid CPU spinning
                    usleep(50000); // 50ms
                }
                
                // Continue reading responses until end of stream
                while ($response = $backendCall->read()) {
                    if ($context->isCancelled()) {
                        break;
                    }
                    $responseCount++;
                    $context->write($response);
                }
                
                $this->metrics['proxy_success']++;
                $this->logSuccess('TalkBidirectional');
                return;
            } catch (\Exception $e) {
                $this->logError('TalkBidirectional', $e->getMessage(), true);
                // Fall back to local processing
                $this->metrics['local_fallback']++;
                
                // Clear the read buffer to avoid hanging
                while (!$context->isCancelled() && $context->read() !== null) {
                    // Just drain the buffer
                }
            }
        }
        
        // Process locally with bidirectional streaming
        try {
            $requestIndex = 0;
            
            // Keep processing until client is done or call is cancelled
            while (!$context->isCancelled()) {
                // Read request
                $request = $context->read();
                
                if ($request === null) {
                    if ($context->writesDone()) {
                        // Client closed the writing stream, we're done
                        break;
                    }
                    
                    // No new request yet, wait a bit
                    usleep(100000); // 100ms
                    continue;
                }
                
                // Got a request, process it
                $requestIndex++;
                $requestCount++;
                
                if ($request instanceof TalkRequest) {
                    // Create and send response
                    $results = [[
                        'id' => $requestIndex,
                        'idx' => $request->getData(),
                        'type' => 4,
                        'data' => "Bidirectional response $requestIndex",
                        'meta' => $request->getMeta()
                    ]];
                    
                    $response = $this->createResponse(0, $results);
                    $context->write($response);
                    $responseCount++;
                }
            }
            
            $this->logSuccess('TalkBidirectional');
            $this->metrics['success_count']++;
        } catch (\Exception $e) {
            $this->logError('TalkBidirectional', $e->getMessage());
            throw $e;
        }
    }
}