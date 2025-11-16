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

// Include required files
require dirname(__FILE__) . '/vendor/autoload.php';
require dirname(__FILE__) . '/LandingService.php';
require dirname(__FILE__) . '/conn/Connection.php';
require dirname(__FILE__) . '/common/utils/VersionUtils.php';

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
            $log->warning("Invalid certificate configuration, falling back to insecure server");
            $server->addHttp2Port($port);
        } else {
            try {
                // Read certificate files
                $serverKey = file_get_contents($conn->keyPath);
                $serverCert = file_get_contents($conn->certPath);
                
                // Create SSL credentials
                // PHP gRPC ServerCredentials::createSsl signature:
                // createSsl(string $pem_root_certs, string $pem_private_key, string $pem_cert_chain)
                // For server-only auth (no client cert verification), use null for root certs
                $serverCredentials = ServerCredentials::createSsl(
                    null,           // Root certificate for client verification (null = no client auth)
                    $serverKey,     // Server private key
                    $serverCert     // Server certificate chain
                );
                
                // Add secure port
                $server->addHttp2Port($port, $serverCredentials);
                
                $actuallySecure = true;
                $log->info("TLS configuration successful - server is SECURE");
            } catch (Exception $e) {
                $log->error("Error setting up TLS: " . $e->getMessage(), ['exception' => $e]);
                $log->warning("Falling back to INSECURE server");
                $server->addHttp2Port($port);
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