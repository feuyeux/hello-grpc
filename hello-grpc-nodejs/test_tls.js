// filepath: /Users/hanl5/coding/feuyeux/hello-grpc/hello-grpc-nodejs/test_tls.js
const connectionModule = require('./common/connection');
const logger = connectionModule.logger;

// Set environment variable to trigger TLS connection
process.env.GRPC_HELLO_SECURE = 'Y';

// Optionally customize certificate paths if needed
// process.env.CERT_PATH = '/path/to/your/certs';
// process.env.TLS_SERVER_NAME = 'custom.server.name';

// Attempt to create a client with TLS
try {
    logger.info("Creating a client with TLS enabled...");
    const client = connectionModule.getClient();
    logger.info("TLS client created successfully. Testing connection...");
    
    // Create a simple unary call to test connection
    const { TalkRequest } = require('./common/landing_pb');
    const request = new TalkRequest();
    request.setData("TLS-TEST");
    request.setMeta("NODEJS-TLS-TEST");
    
    client.talk(request, (err, response) => {
        if (err) {
            logger.error("TLS connection test failed with error:");
            logger.error(err);
            process.exit(1);
        } else {
            logger.info("TLS connection test succeeded!");
            logger.info("Response received: %j", response.toObject());
            process.exit(0);
        }
    });
} catch (error) {
    logger.error("Error creating TLS client:");
    logger.error(error);
    process.exit(1);
}