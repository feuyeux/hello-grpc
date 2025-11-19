import * as grpc from '@grpc/grpc-js';
import {createLogger, format, transports} from "winston";
import * as fs from "fs";
import * as path from "path";
import * as os from "os";
import {LandingServiceClient} from "../generated/landing_grpc_pb";

// 定义默认端口
export const port = "9996";

function getCertBasePath() {
    
    // 如果指定路径不存在，仍然尝试通过环境变量
    if (process.env.CERT_BASE_PATH) {
        return process.env.CERT_BASE_PATH;
    }
    
    // 本地项目证书目录（相对路径）
    const localCertPath = path.join(__dirname, '..', 'certs', 'client_certs');
    if (fs.existsSync(localCertPath)) {
        return localCertPath;
    }
    
    // 如果本地路径不存在，则使用默认系统路径
    const platform = os.platform()
    if (platform === 'win32') {
        // Windows path
        return "d:\\garden\\var\\hello_grpc\\client_certs"
    } else if (platform === 'darwin') {
        // macOS path
        return "/var/hello_grpc/client_certs"
    } else {
        // Linux/Unix path
        return "/var/hello_grpc/client_certs"
    }
}

const certBasePath = getCertBasePath()
const cert = path.join(certBasePath, "cert.pem")
// Try using the PKCS8 format key which might be compatible with gRPC's requirements
const certKey = path.join(certBasePath, "private.pkcs8.key")
const certChain = path.join(certBasePath, "full_chain.pem") 
const rootCert = path.join(certBasePath, "myssl_root.cer")
const serverName = "hello.grpc.io"

// 确保日志目录存在
try {
  fs.mkdirSync('log', { recursive: true });
} catch (e) {
  // 目录已存在或无法创建
}

// 创建自定义日志格式
const consoleFormat = format.printf(({ timestamp, message }) => {
  return `${timestamp} ${message}`;
});

const fileFormat = format.printf(({ timestamp, level, message }) => {
  return `${timestamp} [${process.pid}] ${level.toUpperCase()} Server - ${message}`;
});

export const logger = createLogger({
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
});

/**
 * Gets the gRPC server host from environment or defaults to localhost
 */
export function grpcServerHost(): string {
  const server = process.env.GRPC_SERVER;
  return typeof server !== 'undefined' && server !== null ? server : "localhost";
}

/**
 * Gets the gRPC server port from environment or defaults to 9996
 */
export function getServerPort(): string {
  const serverPort = process.env.GRPC_SERVER_PORT;
  return typeof serverPort !== 'undefined' && serverPort !== null ? serverPort : "9996";
}

/**
 * Creates a gRPC client with proper connection settings
 * @returns {LandingServiceClient} The configured gRPC client
 */
export function createClient(): LandingServiceClient {
  // Determine server to connect to
  const backend = process.env.GRPC_HELLO_BACKEND;
  const connectTo = typeof backend !== 'undefined' && backend !== null ? backend : grpcServerHost();

  // Determine port to connect to
  const backPort = process.env.GRPC_HELLO_BACKEND_PORT;
  let port: string;
  if (typeof backPort !== 'undefined' && backPort !== null) {
    port = backPort;
  } else {
    port = getServerPort();
  }

  const address = `${connectTo}:${port}`;
  const secure = process.env.GRPC_HELLO_SECURE;

  if (typeof secure !== 'undefined' && secure !== null && secure === "Y") {
    try {
      logger.info("Connect With TLS to %s", address);
      logger.info("Using certificate path: %s", certBasePath);
      logger.info("Looking for certificates: root=%s, chain=%s, key=%s", 
                  rootCert, certChain, certKey);
      
      // 检查证书文件是否存在
      if (!fs.existsSync(rootCert)) {
        throw new Error(`Root certificate file not found: ${rootCert}`);
      }
      
      if (!fs.existsSync(certChain)) {
        logger.warn("Certificate chain file not found: %s, proceeding without it", certChain);
      }
      
      if (!fs.existsSync(certKey)) {
        logger.warn("Private key file not found: %s, proceeding without it", certKey);
      }
      
      // 检查文件权限
      try {
        fs.accessSync(rootCert, fs.constants.R_OK);
        if (fs.existsSync(certChain)) fs.accessSync(certChain, fs.constants.R_OK);
        if (fs.existsSync(certKey)) fs.accessSync(certKey, fs.constants.R_OK);
        logger.info("All certificate files are readable");
      } catch (err) {
        logger.error("Certificate file permission error: %s", 
                   err instanceof Error ? err.message : String(err));
        throw new Error("Certificate file permission error");
      }
      
      // 读取证书文件
      const rootCertContent = fs.readFileSync(rootCert);
      let certChainContent = fs.existsSync(certChain) ? fs.readFileSync(certChain) : null;
      let privateKeyContent = fs.existsSync(certKey) ? fs.readFileSync(certKey) : null;
      
      logger.info("Successfully loaded certificates: root=%d bytes, chain=%d bytes, key=%d bytes", 
                 rootCertContent.length, 
                 certChainContent ? certChainContent.length : 0, 
                 privateKeyContent ? privateKeyContent.length : 0);
      
      // 创建TLS凭据 - 尝试不同的配置
      let credentials;
      try {
        // 使用更简单的方式创建TLS凭据，只使用根证书
        // 这会跳过客户端证书验证，只验证服务器证书
        credentials = grpc.credentials.createSsl(rootCertContent);
        logger.info("Created TLS credentials with root certificate only (simplified)");
      } catch (error) {
        logger.error("Failed to create credentials: %s", 
                    error instanceof Error ? error.message : String(error));
        throw error;
      }
      
      // 配置通道选项 - 添加更多选项增加兼容性
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
      
      logger.info("TLS credentials created successfully");
      return new LandingServiceClient(address, credentials, options);
    } catch (error: unknown) {
      logger.error("TLS connection failed: %s. Falling back to insecure.", 
                 error instanceof Error ? error.message : String(error));
      logger.info("Connect With InSecure fallback to %s", address);
      return new LandingServiceClient(address, grpc.credentials.createInsecure());
    }
  } else {
    logger.info("Connect With InSecure to %s", address);
    return new LandingServiceClient(address, grpc.credentials.createInsecure());
  }
}