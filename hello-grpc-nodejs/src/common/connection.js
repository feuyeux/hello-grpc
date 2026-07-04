const grpc = require("@grpc/grpc-js")
const fs = require("fs")
const path = require('path')
const os = require('os')
const { LandingServiceClient } = require("../proto/landing_grpc_pb")
const { createLogger, format, transports } = require('winston')

// Function to get certificate base path based on OS and environment variable
function getCertBasePath() {
  // Use CERT_BASE_PATH from environment if available
  if (process.env.CERT_BASE_PATH) {
    return process.env.CERT_BASE_PATH;
  }
  
  // Otherwise use OS-specific default paths
  const platform = os.platform()
  if (platform === 'win32') {
    return "d:\\garden\\var\\hello_grpc\\client_certs"
  } else if (platform === 'darwin' || platform === 'linux') {
    return "/var/hello_grpc/client_certs"
  } else {
    return path.join(__dirname, '..', 'certs');
  }
}

// Get certificate path
const certPath = getCertBasePath();
const rootCert = path.join(certPath, "myssl_root.cer");
const serverName = process.env.TLS_SERVER_NAME || "hello.grpc.io";

// Ensure log directory exists
try {
  fs.mkdirSync('log', { recursive: true });
} catch (e) {
  // Directory already exists or cannot be created
}

// Create custom log formats
const consoleFormat = format.printf(({ timestamp, message }) => {
  return `${timestamp} ${message}`;
});

const fileFormat = format.printf(({ timestamp, level, message }) => {
  return `${timestamp} [${process.pid}] ${level.toUpperCase()} Server - ${message}`;
});

// Create logger instance
const logger = createLogger({
  level: 'info',
  format: format.combine(
    format.splat(),
    format.timestamp({
      format: 'YYYY-MM-DD HH:mm:ss,SSS'
    }),
    fileFormat
  ),
  transports: [
    // Console output
    new transports.Console({
      format: format.combine(
        format.colorize(),
        format.timestamp({
          format: 'HH:mm:ss.SSS'
        }),
        consoleFormat
      )
    }),
    // File output
    new transports.File({
      filename: path.join('log', 'hello-grpc.log'),
      maxsize: 19500 * 1024,
      maxFiles: 5
    })
  ]
});

/**
 * Client resilience defaults shared by secure and insecure channels:
 * HTTP/2 keepalive pings plus transparent retries per gRPC A6
 * (https://github.com/grpc/proposal/blob/master/A6-client-retries.md).
 */
const RESILIENCE_OPTIONS = {
    "grpc.keepalive_time_ms": 120000,
    "grpc.keepalive_timeout_ms": 20000,
    "grpc.keepalive_permit_without_calls": 1,
    "grpc.http2.min_time_between_pings_ms": 120000,
    "grpc.http2.max_pings_without_data": 0,
    "grpc.enable_retries": 1,
    // Enables gzip compression of outgoing messages on this channel.
    "grpc.default_compression_algorithm": 2,
    "grpc.service_config": JSON.stringify({
        methodConfig: [{
            name: [{ service: "hello.LandingService" }],
            waitForReady: true,
            retryPolicy: {
                maxAttempts: 4,
                initialBackoff: "0.1s",
                maxBackoff: "1s",
                backoffMultiplier: 2,
                retryableStatusCodes: ["UNAVAILABLE"]
            }
        }]
    })
};

/**
 * Creates a gRPC client with proper connection settings
 * @returns {LandingServiceClient} The configured gRPC client
 */
function getClient() {
    const connectTo = process.env.GRPC_HELLO_BACKEND || grpcServerHost();
    const port = process.env.GRPC_HELLO_BACKEND_PORT || process.env.GRPC_SERVER_PORT || "9996";
    const address = `${connectTo}:${port}`;
    const secure = process.env.GRPC_HELLO_SECURE;
    
    if (secure === "Y") {
        try {
            logger.info("Connect With TLS to %s", address);

            // Check if root certificate file exists
            if (!fs.existsSync(rootCert)) {
                logger.error("Root certificate file not found: %s", rootCert);
                throw new Error(`Root certificate file not found: ${rootCert}`);
            }

            // Read root certificate
            const rootCertContent = fs.readFileSync(rootCert);
            logger.info("Loaded root certificate from: %s", rootCert);

            // When GRPC_HELLO_REQUIRE_CLIENT_CERT=Y is set, mirror server-side
            // mTLS by attaching the client cert + key to the channel. Path is
            // <certBasePath>/{cert.pem,private.key}. Default is one-way TLS
            // (no client identity, matches the default on the server side).
            const requireClientCert = process.env.GRPC_HELLO_REQUIRE_CLIENT_CERT === "Y";
            const clientKeyPath = path.join(certPath, "private.key");
            const clientCertPath = path.join(certPath, "cert.pem");
            const hasClientKey = fs.existsSync(clientKeyPath);
            const hasClientCert = fs.existsSync(clientCertPath);

            let credentials;
            if (requireClientCert && hasClientKey && hasClientCert) {
                logger.info("Using mTLS (client certificate supplied)");
                credentials = grpc.credentials.createSsl(
                    rootCertContent,
                    fs.readFileSync(clientKeyPath),
                    fs.readFileSync(clientCertPath)
                );
            } else {
                logger.info("Using server-only TLS (no client certificate)");
                credentials = grpc.credentials.createSsl(
                    rootCertContent,
                    null,  // No client private key
                    null   // No client certificate
                );
            }
            
            // Configure channel options
            const options = {
                "grpc.ssl_target_name_override": serverName,
                "grpc.default_authority": serverName,
                "grpc.enable_http_proxy": 0,
                "grpc.ssl_check_call_host": 0,
                ...RESILIENCE_OPTIONS
            };
            
            logger.info("TLS connection configured with server name: %s", serverName);
            return new LandingServiceClient(address, credentials, options);
        } catch (error) {
            if (process.env.GRPC_HELLO_INSECURE_FALLBACK === "Y") {
                logger.error("TLS connection failed: %s. GRPC_HELLO_INSECURE_FALLBACK=Y - falling back to insecure.", error.message);
                return new LandingServiceClient(address, grpc.credentials.createInsecure(), RESILIENCE_OPTIONS);
            }
            logger.error("TLS connection failed: %s. Set GRPC_HELLO_INSECURE_FALLBACK=Y to explicitly allow an insecure connection.", error.message);
            throw error;
        }
    } else {
        logger.info("Connect With InSecure to %s", address);
        return new LandingServiceClient(address, grpc.credentials.createInsecure(), RESILIENCE_OPTIONS);
    }
}

function grpcServerHost() {
    return process.env.GRPC_SERVER || "localhost";
}

exports.logger = logger;
exports.getClient = getClient;
exports.grpcServerHost = grpcServerHost;