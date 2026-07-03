<?php
/**
 * gRPC server implementation for PHP
 * 
 * This file implements a gRPC server with TLS support, backend proxying capabilities,
 * and comprehensive error handling.
 * 
 * @author Hello gRPC Team
 */

use Grpc\RpcServer;
use Grpc\ServerCredentials;
use Monolog\Logger;
use Monolog\Handler\StreamHandler;
use Monolog\Handler\RotatingFileHandler;
use Monolog\Formatter\LineFormatter;
use Common\Utils\VersionUtils;
use Common\Utils\Otel;

// Include required files
require dirname(__FILE__) . '/vendor/autoload.php';
require dirname(__FILE__) . '/LandingService.php';
require dirname(__FILE__) . '/conn/Connection.php';
require dirname(__FILE__) . '/common/utils/VersionUtils.php';
require_once dirname(__FILE__) . '/common/utils/Otel.php';
// B7 — gRPC health check service (grpc.health.v1.Health)
require dirname(__FILE__) . '/common/svc/Hello/HealthServiceImpl.php';

// Set up global logger with improved formatting first
$log = new Logger('HelloGrpc');

// Create console handler with a specific format
$consoleHandler = new StreamHandler('php://stdout', Logger::DEBUG); // Changed to DEBUG level
$consoleFormat = new LineFormatter("[%datetime%] %channel% %level_name%: %message%\n");
$consoleHandler->setFormatter($consoleFormat);
$log->pushHandler($consoleHandler);

// Create rotating log file handler
$logDir = __DIR__ . '/log';
if (!is_dir($logDir)) {
    mkdir($logDir, 0777, true);
}

$fileHandler = new RotatingFileHandler($logDir . '/hello-grpc.log', 5, Logger::DEBUG); // Changed to DEBUG level
$fileFormat = new LineFormatter("[%datetime%] %channel%.%level_name%: %message% %context% %extra%\n");
$fileHandler->setFormatter($fileFormat);
$log->pushHandler($fileHandler);

// Make logger globally available
$GLOBALS['log'] = $log;

// Print initial debug message to verify logging is working
$log->debug("Logger initialized");

// Parse command line arguments
$options = getopt('', ['tls', 'addr:', 'log:']);

// Set TLS mode from command line if provided
if (isset($options['tls'])) {
    putenv('GRPC_HELLO_SECURE=Y');
}

// Set address if provided
if (isset($options['addr'])) {
    $addrParts = explode(':', $options['addr']);
    if (count($addrParts) === 2) {
        putenv('GRPC_SERVER_PORT=' . $addrParts[1]);
    }
}

// Define signal handler function
/**
 * Signal handler for graceful shutdown
 * 
 * @param int $signal Signal number
 */
function handleShutdown($signal) {
    global $log;
    
    if ($signal === SIGTERM) {
        $log->info("Received SIGTERM signal, shutting down gracefully");
    } else {
        $log->info("Received SIGINT signal, shutting down gracefully");
    }
    
    exit(0);
}

// Setup signal handling for graceful shutdown
if (function_exists('pcntl_signal')) {
    // Register signal handlers
    pcntl_signal(SIGTERM, 'handleShutdown');
    pcntl_signal(SIGINT, 'handleShutdown');
    $log->debug("Signal handlers registered");
}

/**
 * Get the gRPC version string
 * @return string The gRPC version string in format "grpc.version=X.Y.Z"
 */
function getVersion(): string {
    return VersionUtils::getVersion();
}

try {
    $log->info("Initializing gRPC server");

    // Initialize OpenTelemetry when GRPC_HELLO_OTEL=Y. Returns null
    // when the env var is unset; a follow-up PR will wrap each
    // service handler in hello_server.php / LandingServiceImpl.php
    // with a tracer->spanBuilder() call so per-gRPC-call spans get
    // emitted. The C extension's grpc RpcServer does not currently
    // expose an interceptor slot, so the wiring is partial in this
    // PR; OTel::initOtel just installs the SDK + exporter so future
    // handler-side spans have a configured Tracer to use.
    Otel::initOtel("hello-grpc-php-server");

    // Initialize connection configuration
    $conn = new Connection();
    
    $server = new RpcServer();
    
    $port = '0.0.0.0:' . $conn->port;
    $actuallySecure = false;
    
    // Configure server with TLS if enabled
    if ($conn->isSecure) {
        $log->info("TLS is enabled, configuring secure server");
        
        // Validate certificates
        if (!$conn->validateCertificates()) {
            if (getenv('GRPC_HELLO_INSECURE_FALLBACK') === 'Y') {
                $log->warning("Invalid certificate configuration, GRPC_HELLO_INSECURE_FALLBACK=Y - falling back to insecure server");
                $server->addHttp2Port($port);
            } else {
                $log->error("GRPC_HELLO_SECURE=Y but certificate configuration is invalid. Set CERT_BASE_PATH to the certificate directory, or set GRPC_HELLO_INSECURE_FALLBACK=Y to explicitly allow an insecure server.");
                exit(1);
            }
        } else {
            try {
                // Read certificate files  
                $serverKey = file_get_contents($conn->keyPath);
                $serverCert = file_get_contents($conn->certPath);
                $rootCert = file_exists($conn->rootCertPath) ? file_get_contents($conn->rootCertPath) : null;
                
                // Create SSL credentials
                // ServerCredentials::createSsl expects exactly 3 string parameters:
                // 1. Root certificate (for client verification, use null or empty string for server-only auth)
                // 2. Server private key
                // 3. Server certificate chain
                $serverCredentials = ServerCredentials::createSsl(
                    $rootCert ?: null,  // Root certificate for client verification
                    $serverKey,         // Server private key
                    $serverCert         // Server certificate chain
                );
                
                $log->info("SSL credentials created successfully");
                
                // Add secure port using addSecureHttp2Port
                $server->addSecureHttp2Port($port, $serverCredentials);
                
                $actuallySecure = true;
                $log->info("TLS configuration successful - server is SECURE");
            } catch (Exception $e) {
                $log->error("Error setting up TLS: " . $e->getMessage(), ['exception' => $e]);
                if (getenv('GRPC_HELLO_INSECURE_FALLBACK') === 'Y') {
                    $log->warning("GRPC_HELLO_INSECURE_FALLBACK=Y - falling back to INSECURE server");
                    $server->addHttp2Port($port);
                } else {
                    $log->error("GRPC_HELLO_SECURE=Y but TLS setup failed. Set GRPC_HELLO_INSECURE_FALLBACK=Y to explicitly allow an insecure server.");
                    exit(1);
                }
            }
        }
    } else {
        $log->info("TLS is disabled, starting INSECURE gRPC server");
        $server->addHttp2Port($port);
    }

    // Create backend client if proxy is enabled
    $backendClient = null;
    if ($conn->hasBackend()) {
        $log->info("Setting up backend connection to {$conn->backendHost}:" . ($conn->backendPort ?? $conn->port));
        
        $backendHost = $conn->backendHost . ':' . ($conn->backendPort ?? $conn->port);
        
        try {
            // Configure TLS for backend connection if needed
            if ($conn->isSecure && $conn->validateCertificates()) {
                $log->info("Using TLS for backend connection");
                
                // Read certificate files and create secure credentials
                $rootCert = file_get_contents($conn->rootCertPath);
                $clientCert = file_get_contents($conn->certPath);
                $clientKey = file_get_contents($conn->keyPath);
                
                $credentials = \Grpc\ChannelCredentials::createSsl(
                    $rootCert,
                    $clientKey,
                    $clientCert
                );
            } else {
                $log->info("Using insecure backend connection");
                $credentials = \Grpc\ChannelCredentials::createInsecure();
            }
            
            // Create backend client
            $backendClient = new \Hello\LandingServiceClient($backendHost, [
                'credentials' => $credentials,
                'grpc.primary_user_agent' => 'hello-grpc-php/' . getVersion(),
            ]);
            
            $log->info("Backend client created successfully");
        } catch (Exception $e) {
            $log->error("Failed to create backend client: " . $e->getMessage(), ['exception' => $e]);
            $backendClient = null;
        }
    }
    
    // Create service with backend client if available
    $service = new LandingService($backendClient);
    
    // Register service handler
    $server->handle($service);

    // B7 — gRPC Health Check (grpc.health.v1.Health)
    // Registers the standard health-checking protocol so tools such as
    // grpc_health_probe and grpcurl can query server health.
    $server->handle(new \Grpc\Health\V1\HealthServiceImpl());

    // C4 — gRPC Server Reflection
    // The PHP grpc/grpc C-extension (RpcServer) does not implement the
    // gRPC server reflection protocol (grpc.reflection.v1alpha.ServerReflection).
    // No reflection package exists for PHP in the grpc/grpc ecosystem.
    //
    // Workaround: pass the .proto file directly to grpcurl:
    //   grpcurl -plaintext -proto landing.proto \
    //       -d '{"data":"0","meta":"PHP"}' \
    //       localhost:9996 hello.LandingService/Talk
    //
    // Alternatively, use a reflection-capable proxy (e.g. Envoy) in front
    // of this server if reflection support is required.

    // Log server startup information with actual security status
    $securityStatus = $actuallySecure ? "SECURE (TLS enabled)" : "INSECURE (no TLS)";
    $log->info(sprintf("========================================"));
    $log->info(sprintf("Starting gRPC server: %s", $securityStatus));
    $log->info(sprintf("Port: %s", $conn->port));
    $log->info(sprintf("Version: %s", getVersion()));
    $log->info(sprintf("========================================"));
    
    // Enable signal polling if pcntl extension is available
    if (function_exists('pcntl_signal_dispatch')) {
        // Register a timer to check for signals
        register_tick_function(function() {
            pcntl_signal_dispatch();
        });
        
        // Enable ticks for the main loop
        declare(ticks = 1);
    }
    
    // Start the server
    $server->run();
    
} catch (Exception $e) {
    $log->critical("Server failed with error: " . $e->getMessage(), [
        'exception' => $e,
        'file' => $e->getFile(),
        'line' => $e->getLine()
    ]);
    
    exit(1);
}
