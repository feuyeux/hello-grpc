<?php

use Monolog\Logger;

/**
 * Connection configuration for the gRPC server and client
 * 
 * This class handles all connection-related configuration including:
 * - TLS certificate loading and validation
 * - Backend service discovery and connection management
 * - Environment variable configuration
 * 
 * Handles TLS certificate management, server/client port configuration,
 * and backend connection details.
 * 
 * @author Hello gRPC Team
 */
class Connection
{
    /** @var string Server port */
    public $port;
    
    /** @var bool Whether to use TLS */
    public $isSecure;
    
    /** @var string Backend host (for proxying requests) */
    public $backendHost;
    
    /** @var string Backend port (for proxying requests) */
    public $backendPort;
    
    /** @var string Path to server certificate */
    public $certPath;
    
    /** @var string Path to server private key */
    public $keyPath;
    
    /** @var string Path to server certificate chain */
    public $chainPath;
    
    /** @var string Path to root certificate */
    public $rootCertPath;
    
    /** @var \Psr\Log\LoggerInterface Logger instance */
    private $logger;

    /**
     * Constructor
     */
    public function __construct()
    {
        global $log;
        $this->logger = $log ?? new Logger('Connection');
        
        // Initialize from environment variables with defaults
        $this->port = getenv('GRPC_SERVER_PORT') ?: '9996';
        $this->isSecure = getenv('GRPC_HELLO_SECURE') === 'Y';
        
        // Check for backend configuration
        $this->backendHost = getenv('GRPC_HELLO_BACKEND');
        $this->backendPort = getenv('GRPC_HELLO_BACKEND_PORT');
        
        // Get certificate paths based on platform
        $this->setupCertificatePaths();
        
        $this->logger->info(sprintf("Connection configuration: port=%s, tls=%s", 
            $this->port, $this->isSecure ? 'enabled' : 'disabled'));
            
        if ($this->hasBackend()) {
            $this->logger->info(sprintf("Backend configuration: host=%s, port=%s", 
                $this->backendHost, $this->backendPort ?: $this->port));
        }
    }

    /**
     * Check if a backend service is configured
     * @return bool True if backend is configured
     */
    public function hasBackend(): bool
    {
        return !empty($this->backendHost);
    }
    
    /**
     * Setup certificate paths based on the current platform (Windows/macOS/Linux)
     */
    private function setupCertificatePaths(): void
    {
        // Use custom base path from environment if available
        $basePath = getenv('CERT_BASE_PATH');
        
        // Otherwise, use platform-specific default
        if (empty($basePath)) {
            $osName = PHP_OS_FAMILY;
            
            if ($osName === 'Windows') {
                $basePath = 'd:\\garden\\var\\hello_grpc\\server_certs';
            } elseif ($osName === 'Darwin') {
                // macOS uses a different path structure
                $basePath = '/var/hello_grpc/server_certs';
            } else {
                // Linux/Unix default
                $basePath = '/var/hello_grpc/server_certs';
            }
            
            $this->logger->info(sprintf("Using platform-specific (%s) certificate path: %s", 
                $osName, $basePath));
        } else {
            $this->logger->info(sprintf("Using custom certificate path from environment: %s", 
                $basePath));
        }
        
        // Define certificate paths
        $this->certPath = $basePath . DIRECTORY_SEPARATOR . 'cert.pem';
        $this->keyPath = $basePath . DIRECTORY_SEPARATOR . 'private.key';
        $this->chainPath = $basePath . DIRECTORY_SEPARATOR . 'full_chain.pem';
        $this->rootCertPath = $basePath . DIRECTORY_SEPARATOR . 'myssl_root.cer';
    }
    
    /**
     * Validate certificate files exist and are readable
     * @return bool True if certificates are valid, false otherwise
     */
    public function validateCertificates(): bool
    {
        if (!$this->isSecure) {
            return false;
        }
        
        // Check required certificate files
        $certFiles = [
            'Certificate' => $this->certPath,
            'Private key' => $this->keyPath
        ];
        
        foreach ($certFiles as $name => $path) {
            if (!file_exists($path)) {
                $this->logger->warning("$name file not found: $path");
                return false;
            }
            
            if (!is_readable($path)) {
                $this->logger->warning("$name file not readable: $path");
                return false;
            }
        }
        
        // Optional root certificate
        if (file_exists($this->rootCertPath)) {
            if (is_readable($this->rootCertPath)) {
                $this->logger->info("Root certificate found: " . $this->rootCertPath);
            } else {
                $this->logger->warning("Root certificate found but not readable: " . $this->rootCertPath);
            }
        } else {
            $this->logger->info("Root certificate not found, client verification disabled");
        }
        
        return true;
    }
}