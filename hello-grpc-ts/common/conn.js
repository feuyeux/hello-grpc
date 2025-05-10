"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function (o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
        desc = { enumerable: true, get: function () { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function (o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function (o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function (o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function (o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.logger = exports.port = void 0;
exports.grpcServerHost = grpcServerHost;
exports.getServerPort = getServerPort;
exports.createClient = createClient;
const grpc = __importStar(require("@grpc/grpc-js"));
const winston_1 = require("winston");
const fs = __importStar(require("fs"));
const path = __importStar(require("path"));
const os = __importStar(require("os"));
const landing_grpc_pb_1 = require("./landing_grpc_pb");
// Define default port
exports.port = "9996";
function getCertBasePath() {
    // If the specified path doesn't exist, still try through environment variables
    if (process.env.CERT_BASE_PATH) {
        return process.env.CERT_BASE_PATH;
    }
    // Local project certificate directory (relative path)
    const localCertPath = path.join(__dirname, '..', 'certs', 'client_certs');
    if (fs.existsSync(localCertPath)) {
        return localCertPath;
    }
    // If the local path doesn't exist, use the default system path
    const platform = os.platform();
    if (platform === 'win32') {
        // Windows path
        return "d:\\garden\\var\\hello_grpc\\client_certs";
    }
    else if (platform === 'darwin') {
        // macOS path
        return "/var/hello_grpc/client_certs";
    }
    else {
        // Linux/Unix path
        return "/var/hello_grpc/client_certs";
    }
}
const certBasePath = getCertBasePath();
const cert = path.join(certBasePath, "cert.pem");
// Try using the PKCS8 format key which might be compatible with gRPC's requirements
const certKey = path.join(certBasePath, "private.pkcs8.key");
const certChain = path.join(certBasePath, "full_chain.pem");
const rootCert = path.join(certBasePath, "myssl_root.cer");
const serverName = "hello.grpc.io";
// Ensure the log directory exists
try {
    fs.mkdirSync('log', { recursive: true });
}
catch (e) {
    // Directory already exists or cannot be created
}
// Create custom log format
const consoleFormat = winston_1.format.printf(({ timestamp, message }) => {
    return `${timestamp} ${message}`;
});
const fileFormat = winston_1.format.printf(({ timestamp, level, message }) => {
    return `${timestamp} [${process.pid}] ${level.toUpperCase()} Server - ${message}`;
});
exports.logger = (0, winston_1.createLogger)({
    level: 'info',
    format: winston_1.format.combine(winston_1.format.splat(), winston_1.format.timestamp({
        format: 'YYYY-MM-DD HH:mm:ss,SSS'
    }), fileFormat),
    transports: [
        // Console output
        new winston_1.transports.Console({
            format: winston_1.format.combine(winston_1.format.colorize(), winston_1.format.timestamp({
                format: 'HH:mm:ss.SSS'
            }), consoleFormat)
        }),
        // File output
        new winston_1.transports.File({
            filename: path.join('log', 'hello-grpc.log'),
            maxsize: 19500 * 1024,
            maxFiles: 5
        })
    ]
});
/**
 * Gets the gRPC server host from environment or defaults to localhost
 */
function grpcServerHost() {
    const server = process.env.GRPC_SERVER;
    return typeof server !== 'undefined' && server !== null ? server : "localhost";
}
/**
 * Gets the gRPC server port from environment or defaults to 9996
 */
function getServerPort() {
    const serverPort = process.env.GRPC_SERVER_PORT;
    return typeof serverPort !== 'undefined' && serverPort !== null ? serverPort : "9996";
}
/**
 * Creates a gRPC client with proper connection settings
 * @returns {LandingServiceClient} The configured gRPC client
 */
function createClient() {
    // Determine server to connect to
    const backend = process.env.GRPC_HELLO_BACKEND;
    const connectTo = typeof backend !== 'undefined' && backend !== null ? backend : grpcServerHost();
    // Determine port to connect to
    const backPort = process.env.GRPC_HELLO_BACKEND_PORT;
    let port;
    if (typeof backPort !== 'undefined' && backPort !== null) {
        port = backPort;
    }
    else {
        port = getServerPort();
    }
    const address = `${connectTo}:${port}`;
    const secure = process.env.GRPC_HELLO_SECURE;
    if (typeof secure !== 'undefined' && secure !== null && secure === "Y") {
        try {
            exports.logger.info("Connect With TLS to %s", address);
            exports.logger.info("Using certificate path: %s", certBasePath);
            exports.logger.info("Looking for certificates: root=%s, chain=%s, key=%s", rootCert, certChain, certKey);
            // Check if certificate files exist
            if (!fs.existsSync(rootCert)) {
                throw new Error(`Root certificate file not found: ${rootCert}`);
            }
            if (!fs.existsSync(certChain)) {
                exports.logger.warn("Certificate chain file not found: %s, proceeding without it", certChain);
            }
            if (!fs.existsSync(certKey)) {
                exports.logger.warn("Private key file not found: %s, proceeding without it", certKey);
            }
            // Check file permissions
            try {
                fs.accessSync(rootCert, fs.constants.R_OK);
                if (fs.existsSync(certChain))
                    fs.accessSync(certChain, fs.constants.R_OK);
                if (fs.existsSync(certKey))
                    fs.accessSync(certKey, fs.constants.R_OK);
                exports.logger.info("All certificate files are readable");
            }
            catch (err) {
                exports.logger.error("Certificate file permission error: %s", err instanceof Error ? err.message : String(err));
                throw new Error("Certificate file permission error");
            }
            // Read certificate files
            const rootCertContent = fs.readFileSync(rootCert);
            let certChainContent = fs.existsSync(certChain) ? fs.readFileSync(certChain) : null;
            let privateKeyContent = fs.existsSync(certKey) ? fs.readFileSync(certKey) : null;
            exports.logger.info("Successfully loaded certificates: root=%d bytes, chain=%d bytes, key=%d bytes", rootCertContent.length, certChainContent ? certChainContent.length : 0, privateKeyContent ? privateKeyContent.length : 0);
            // Create TLS credentials - try different configurations
            let credentials;
            try {
                // Use a simpler way to create TLS credentials, only using the root certificate
                // This skips client certificate verification, only verifying the server certificate
                credentials = grpc.credentials.createSsl(rootCertContent);
                exports.logger.info("Created TLS credentials with root certificate only (simplified)");
            }
            catch (error) {
                exports.logger.error("Failed to create credentials: %s", error instanceof Error ? error.message : String(error));
                throw error;
            }
            // Configure channel options - add more options to increase compatibility
            const options = {
                "grpc.ssl_target_name_override": serverName,
                "grpc.default_authority": serverName,
                "grpc.keepalive_time_ms": 120000,
                "grpc.keepalive_timeout_ms": 20000,
                "grpc.keepalive_permit_without_calls": 1,
                "grpc.http2.min_time_between_pings_ms": 120000,
                "grpc.http2.max_pings_without_data": 0,
                // Add option to skip certificate validation for testing
                "grpc.ssl_verification_mode": process.env.NO_SSL_VERIFY === "Y" ? 0 : 1
            };
            exports.logger.info("TLS credentials created successfully");
            return new landing_grpc_pb_1.LandingServiceClient(address, credentials, options);
        }
        catch (error) {
            exports.logger.error("TLS connection failed: %s. Falling back to insecure.", error instanceof Error ? error.message : String(error));
            exports.logger.info("Connect With InSecure fallback to %s", address);
            return new landing_grpc_pb_1.LandingServiceClient(address, grpc.credentials.createInsecure());
        }
    }
    else {
        exports.logger.info("Connect With InSecure to %s", address);
        return new landing_grpc_pb_1.LandingServiceClient(address, grpc.credentials.createInsecure());
    }
}
