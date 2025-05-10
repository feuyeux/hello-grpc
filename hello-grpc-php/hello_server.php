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
    
    // Configure server with TLS if enabled
    if ($conn->isSecure) {
        $log->info("TLS is enabled, configuring secure server");
        
        // Validate certificates
        if (!$conn->validateCertificates()) {
            $log->warning("Invalid certificate configuration, falling back to insecure server");
            $server->addHttp2Port('0.0.0.0:' . $conn->port);
        } else {
            try {
                // Read certificate files
                $serverKey = file_get_contents($conn->keyPath);
                $serverCert = file_get_contents($conn->certPath);
                
                // Create secure server
                $server->addHttp2Port(
                    '0.0.0.0:' . $conn->port,
                    ServerCredentials::createSsl(
                        null,  // Root certificates for client authentication (null for no client auth)
                        [['private_key' => $serverKey, 'cert_chain' => $serverCert]]
                    )
                );
                
                $log->info("TLS configuration successful");
            } catch (Exception $e) {
                $log->error("Error setting up TLS: " . $e->getMessage(), ['exception' => $e]);
                $log->info("Starting insecure server instead");
                $server->addHttp2Port('0.0.0.0:' . $conn->port);
            }
        }
    } else {
        $log->info("TLS is disabled, starting insecure gRPC server");
        $server->addHttp2Port('0.0.0.0:' . $conn->port);
    }
    
    // Try to explicitly bind to the port
    try {
        $port = '0.0.0.0:' . $conn->port;
        $log->info("Attempting to bind to: " . $port);
        
        if ($conn->isSecure && $conn->validateCertificates()) {
            // Create secure server with certificates
            // ...existing secure code...
        } else {
            $log->info("Using insecure port binding");
            $result = $server->addHttp2Port($port);
            $log->info("Port binding result: " . $result . " (should be non-zero if successful)");
        }
    } catch (Exception $e) {
        $log->error("Failed to bind to port: " . $e->getMessage());
        exit(1);
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
    
    // Log server startup information
    if ($conn->isSecure) {
        $log->info(sprintf("Starting secure gRPC server on port %s [%s]", $conn->port, getVersion()));
    } else {
        $log->info(sprintf("Starting insecure gRPC server on port %s [%s]", $conn->port, getVersion()));
    }
    
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