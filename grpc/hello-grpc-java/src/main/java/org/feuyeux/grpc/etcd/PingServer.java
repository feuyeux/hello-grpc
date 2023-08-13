package org.feuyeux.grpc.etcd;

import com.google.common.base.Charsets;
import io.etcd.jetcd.ByteSequence;
import io.etcd.jetcd.Client;
import io.etcd.jetcd.lease.LeaseKeepAliveResponse;
import io.etcd.jetcd.options.PutOption;
import io.grpc.Server;
import io.grpc.ServerBuilder;
import io.grpc.stub.StreamObserver;
import lombok.extern.slf4j.Slf4j;
import org.feuyeux.grpc.PingGrpc;
import org.feuyeux.grpc.PingOuterClass;

import java.io.IOException;
import java.net.URI;
import java.util.concurrent.ExecutionException;

import static org.feuyeux.grpc.common.Connection.PING_DIR;

@Slf4j
public class PingServer {
    private static final String ENDPOINT = "http://127.0.0.1:2379";
    private static final long TTL = 5L;

    private final int port;
    private Server server;
    private Client etcd;

    private PingServer(int port) {
        this.port = port;
    }

    private void start() throws IOException, ExecutionException, InterruptedException {
        server = ServerBuilder.forPort(port)
                .addService(new PingImpl())
                .build()
                .start();
        log.info("Server started on port:" + port);

        final URI uri = URI.create("http://localhost:" + port);
        this.etcd = Client.builder()
                .endpoints(URI.create(ENDPOINT))
                .build();
        long leaseId = etcd.getLeaseClient().grant(TTL).get().getID();
        ByteSequence key = ByteSequence.from(PING_DIR + uri.toASCIIString(), Charsets.US_ASCII);
        ByteSequence value = ByteSequence.from(Long.toString(leaseId), Charsets.US_ASCII);
        PutOption option = PutOption.builder().withLeaseId(leaseId).build();
        etcd.getKVClient().put(key, value, option);
        etcd.getLeaseClient().keepAlive(leaseId, new EtcdServiceRegisterer());

        Runtime.getRuntime().addShutdownHook(new Thread(() -> {
            System.err.println("Shutting down server on port: " + port);
            PingServer.this.stop();
        }));
    }

    private void stop() {
        etcd.close();
        server.shutdown();
    }

    private void blockUntilShutdown() throws InterruptedException {
        server.awaitTermination();
    }

    /**
     * Main launches the server from the command line.
     */
    public static void main(String[] args) throws IOException, InterruptedException, ExecutionException {
        final PingServer server = new PingServer(Integer.parseInt(args[0]));
        server.start();
        server.blockUntilShutdown();
    }

    class PingImpl extends PingGrpc.PingImplBase {

        @Override
        public void ping(PingOuterClass.PingRequest request, StreamObserver<PingOuterClass.PingResponse> responseObserver) {
            log.info(request.getPing());
            responseObserver.onNext(PingOuterClass.PingResponse.newBuilder()
                    .setPong("PONG from port: " + port)
                    .build());
            responseObserver.onCompleted();
        }
    }

    static class EtcdServiceRegisterer implements StreamObserver<LeaseKeepAliveResponse> {

        @Override
        public void onNext(LeaseKeepAliveResponse value) {
            log.info("got renewal for lease: " + value.getID());
        }

        @Override
        public void onError(Throwable t) {
        }

        @Override
        public void onCompleted() {
        }
    }
}
