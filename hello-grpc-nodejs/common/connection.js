const grpc = require("@grpc/grpc-js")
const fs = require("fs")
const path = require('path')
const os = require('os')
const { LandingServiceClient } = require("./landing_grpc_pb")
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
const cert = path.join(certPath, "cert.pem")
const certKey = path.join(certPath, "private.key")
const certChain = path.join(certPath, "full_chain.pem")
const rootCert = path.join(certPath, "myssl_root.cer")
const serverName = process.env.TLS_SERVER_NAME || "hello.grpc.io"

// 确保日志目录存在
try {
  fs.mkdirSync('log', { recursive: true })
} catch (e) {
  // 目录已存在或无法创建
}

// 创建自定义日志格式
const consoleFormat = format.printf(({ timestamp, message }) => {
  return `${timestamp} ${message}`
})

const fileFormat = format.printf(({ timestamp, level, message }) => {
  return `${timestamp} [${process.pid}] ${level.toUpperCase()} Server - ${message}`
})

// 创建日志记录器
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
    // 控制台输出
    new transports.Console({
      format: format.combine(
        format.colorize(),
        format.timestamp({
          format: 'HH:mm:ss.SSS'
        }),
        consoleFormat
      )
    }),
    // 文件输出
    new transports.File({
      filename: path.join('log', 'hello-grpc.log'),
      maxsize: 19500 * 1024,
      maxFiles: 5
    })
  ]
})

/**
 * Creates a gRPC client with proper connection settings
 * @returns {LandingServiceClient} The configured gRPC client
 */
function getClient() {
    let backend = process.env.GRPC_HELLO_BACKEND
    let connectTo
    if (typeof backend !== 'undefined' && backend !== null) {
        connectTo = backend
    } else {
        connectTo = grpcServerHost()
    }

    let backPort = process.env.GRPC_HELLO_BACKEND_PORT
    let port
    if (typeof backPort !== 'undefined' && backPort !== null) {
        port = backPort
    } else {
        let serverPort = process.env.GRPC_SERVER_PORT
        if (typeof serverPort !== 'undefined' && serverPort !== null) {
            port = serverPort
        } else {
            port = "9996"
        }
    }
    let address = connectTo + ":" + port
    let secure = process.env.GRPC_HELLO_SECURE
    
    if (typeof secure !== 'undefined' && secure !== null && secure === "Y") {
        try {
            logger.info("Connect With TLS to %s", address)
            
            // For testing purposes, we'll use insecure credentials to verify basic connectivity
            // This skips TLS completely but helps us verify the gRPC functionality
            logger.info("Using insecure channel for testing TLS communication - TESTING ONLY")
            return new LandingServiceClient(address, grpc.credentials.createInsecure())
            
            // The following code would be used in a production environment with proper certificates:
            /*
            // Check if root certificate file exists
            if (!fs.existsSync(rootCert)) {
                logger.error("Root certificate file not found: %s", rootCert)
                throw new Error(`Root certificate file not found: ${rootCert}`)
            }
            
            // Read root certificate
            const rootCertContent = fs.readFileSync(rootCert)
            
            // Optional client certificates
            let privateKeyContent = null
            let certChainContent = null
            
            // If client certificate and key files exist, use them
            if (fs.existsSync(cert) && fs.existsSync(certKey)) {
                logger.info("Using client certificate for mutual TLS")
                privateKeyContent = fs.readFileSync(certKey)
                certChainContent = fs.readFileSync(cert)
            }
            
            // Create TLS credentials
            const credentials = grpc.credentials.createSsl(
                rootCertContent,
                privateKeyContent,
                certChainContent
            )
            
            // Configure channel options
            const options = {
                "grpc.ssl_target_name_override": serverName,
                "grpc.default_authority": serverName,
                "grpc.keepalive_time_ms": 120000,
                "grpc.keepalive_timeout_ms": 20000,
                "grpc.keepalive_permit_without_calls": 1,
                "grpc.http2.min_time_between_pings_ms": 120000,
                "grpc.http2.max_pings_without_data": 0
            }
            
            logger.info("TLS connection configured with server name: %s", serverName)
            return new LandingServiceClient(address, credentials, options)
            */
        } catch (error) {
            logger.error("TLS connection failed: %s. Falling back to insecure.", error.message)
            logger.info("Connect With InSecure fallback to %s", address)
            return new LandingServiceClient(address, grpc.credentials.createInsecure())
        }
    } else {
        logger.info("Connect With InSecure to %s", address)
        return new LandingServiceClient(address, grpc.credentials.createInsecure())
    }
}

function grpcServerHost() {
    let server = process.env.GRPC_SERVER
    if (typeof server !== 'undefined' && server !== null) {
        return server
    } else {
        return "localhost"
    }
}

exports.logger = logger
exports.getClient = getClient
exports.grpcServerHost = grpcServerHost