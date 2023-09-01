//https://myssl.com/create_test_cert.html
const grpc = require("@grpc/grpc-js")
const fs = require("fs")
const cert = "/var/hello_grpc/client_certs/cert.pem"
const certKey = "/var/hello_grpc/client_certs/private.key"
const certChain = "/var/hello_grpc/client_certs/full_chain.pem"
const rootCert = "/var/hello_grpc/client_certs/myssl_root.cer"
const serverName = "hello.grpc.io"
const {createLogger, format, transports} = require('winston')
const {LandingServiceClient} = require("./landing_grpc_pb")
const {combine, timestamp, printf} = format
const formatter = printf(({level, message, timestamp}) => {
    return `${timestamp} [${level}] ${message}`
})

const logger = createLogger({
    level: 'info',
    format: combine(
        format.splat(),
        timestamp(),
        formatter
    ),
    transports: [new transports.Console()],
})

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
        logger.info("Connect With TLS(%s)", port)
        let rootCertContent = fs.readFileSync(certChain)
        let privateKeyContent = fs.readFileSync(certKey)
        let certChainContent = fs.readFileSync(certChain)
        const credentials = grpc.credentials.createSsl(rootCertContent, privateKeyContent, certChainContent)
        //https://grpc.github.io/grpc/core/group__grpc__arg__keys.html
        // ChannelOptions ClientOptions
        const options = {
            "grpc.default_authority": serverName,
            "grpc.ssl_target_name_override": serverName
        }
        return new LandingServiceClient(address, credentials, options)
    } else {
        logger.info("Connect With InSecure(%s)", port)
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