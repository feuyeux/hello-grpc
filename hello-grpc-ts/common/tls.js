"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
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
exports.getCertBasePath = getCertBasePath;
exports.getCertificatePaths = getCertificatePaths;
exports.loadCertificates = loadCertificates;
exports.createServerCredentials = createServerCredentials;
exports.createClientCredentials = createClientCredentials;
exports.testTlsCertificates = testTlsCertificates;
const fs = __importStar(require("fs"));
const path = __importStar(require("path"));
const os = __importStar(require("os"));
const grpc = __importStar(require("@grpc/grpc-js"));
const conn_1 = require("./conn");
/**
 * Gets the certificate base path for server or client certificates
 * @param isServer Whether to get server or client certificate path
 * @returns The path to the certificate directory
 */
function getCertBasePath(isServer = false) {
    const certType = isServer ? 'server_certs' : 'client_certs';
    // First try environment variable
    if (process.env.CERT_BASE_PATH) {
        return process.env.CERT_BASE_PATH;
    }
    // Then try relative path in project
    const localCertPath = path.join(__dirname, '..', 'certs', certType);
    if (fs.existsSync(localCertPath)) {
        return localCertPath;
    }
    // Finally use default system path
    const platform = os.platform();
    if (platform === 'win32') {
        // Windows path
        return `d:\\garden\\var\\hello_grpc\\${certType}`;
    }
    else if (platform === 'darwin') {
        // macOS path
        return `/var/hello_grpc/${certType}`;
    }
    else {
        // Linux/Unix path
        return `/var/hello_grpc/${certType}`;
    }
}
/**
 * Gets the paths to the certificate files
 * @param isServer Whether to get server or client certificate paths
 * @returns An object containing the certificate file paths
 */
function getCertificatePaths(isServer = false) {
    const basePath = getCertBasePath(isServer);
    return {
        certPath: path.join(basePath, "cert.pem"),
        keyPath: path.join(basePath, "private.key"),
        chainPath: path.join(basePath, "full_chain.pem"),
        rootCertPath: path.join(basePath, "myssl_root.cer")
    };
}
/**
 * Loads certificate files from the specified paths
 * @param certPaths The paths to the certificate files
 * @returns An object containing the loaded certificate contents or null if file doesn't exist
 */
function loadCertificates(certPaths) {
    // Check and log certificate existence
    conn_1.logger.info("Loading certificates from paths: cert=%s, key=%s, chain=%s, root=%s", certPaths.certPath, certPaths.keyPath, certPaths.chainPath, certPaths.rootCertPath);
    // Helper function to safely read a file
    const safeReadFile = (filePath) => {
        try {
            if (fs.existsSync(filePath)) {
                const content = fs.readFileSync(filePath);
                fs.accessSync(filePath, fs.constants.R_OK);
                return content;
            }
        }
        catch (err) {
            conn_1.logger.warn("Could not read certificate file %s: %s", filePath, err instanceof Error ? err.message : String(err));
        }
        return null;
    };
    // Load all certificate files
    const cert = safeReadFile(certPaths.certPath);
    let key = safeReadFile(certPaths.keyPath);
    // Try PKCS8 format if regular key not found
    if (!key) {
        const pkcs8KeyPath = certPaths.keyPath.replace('private.key', 'private.pkcs8.key');
        key = safeReadFile(pkcs8KeyPath);
        if (key) {
            conn_1.logger.info("Using PKCS8 key format: %s", pkcs8KeyPath);
        }
    }
    const chain = safeReadFile(certPaths.chainPath);
    const rootCert = safeReadFile(certPaths.rootCertPath);
    // Log result of certificate loading
    conn_1.logger.info("Certificate loading results: cert=%s, key=%s, chain=%s, root=%s", cert ? "loaded" : "missing", key ? "loaded" : "missing", chain ? "loaded" : "missing", rootCert ? "loaded" : "missing");
    return { cert, key, chain, rootCert };
}
/**
 * Creates gRPC server credentials for secure communication
 * @returns The server credentials object
 */
function createServerCredentials() {
    const certPaths = getCertificatePaths(true);
    const certs = loadCertificates(certPaths);
    if (!certs.rootCert) {
        throw new Error(`Root certificate file not found: ${certPaths.rootCertPath}`);
    }
    if (!certs.chain) {
        throw new Error(`Certificate chain file not found: ${certPaths.chainPath}`);
    }
    if (!certs.key) {
        throw new Error(`Neither private.key nor private.pkcs8.key found in ${getCertBasePath(true)}`);
    }
    conn_1.logger.info("Creating server TLS credentials");
    // Don't require client certificate
    const checkClientCertificate = false;
    // Create key cert pairs in the format required by gRPC
    const keyCertPairs = [{
            private_key: certs.key,
            cert_chain: certs.cert || certs.chain // Use cert if available, otherwise chain
        }];
    return grpc.ServerCredentials.createSsl(certs.rootCert, keyCertPairs, checkClientCertificate);
}
/**
 * Creates gRPC client credentials for secure communication
 * @param serverName The server name to use for verification
 * @returns The client credentials object
 */
function createClientCredentials(serverName = "hello.grpc.io") {
    const certPaths = getCertificatePaths(false);
    const certs = loadCertificates(certPaths);
    if (!certs.rootCert) {
        throw new Error(`Root certificate file not found: ${certPaths.rootCertPath}`);
    }
    conn_1.logger.info("Creating client TLS credentials");
    // Create credentials with root cert only for simplicity
    const credentials = grpc.credentials.createSsl(certs.rootCert);
    // Channel options for the client
    const options = {
        "grpc.ssl_target_name_override": serverName,
        "grpc.default_authority": serverName,
        "grpc.keepalive_time_ms": 120000,
        "grpc.keepalive_timeout_ms": 20000,
        "grpc.keepalive_permit_without_calls": 1,
        "grpc.http2.min_time_between_pings_ms": 120000,
        "grpc.http2.max_pings_without_data": 0,
        "grpc.ssl_verification_mode": process.env.NO_SSL_VERIFY === "Y" ? 0 : 1
    };
    return { credentials, options };
}
/**
 * Simple test function to check if TLS certificates are loaded correctly
 * @param isServer Whether to test server or client certificates
 * @returns true if all required certificates are found, false otherwise
 */
function testTlsCertificates(isServer = false) {
    try {
        const certPaths = getCertificatePaths(isServer);
        const certs = loadCertificates(certPaths);
        const requiredCerts = isServer
            ? ['rootCert', 'key', 'chain']
            : ['rootCert'];
        for (const cert of requiredCerts) {
            if (!certs[cert]) {
                conn_1.logger.error(`Required certificate missing: ${cert}`);
                return false;
            }
        }
        conn_1.logger.info("TLS certificate test passed for %s certificates", isServer ? "server" : "client");
        return true;
    }
    catch (error) {
        conn_1.logger.error("TLS certificate test failed: %s", error instanceof Error ? error.message : String(error));
        return false;
    }
}
