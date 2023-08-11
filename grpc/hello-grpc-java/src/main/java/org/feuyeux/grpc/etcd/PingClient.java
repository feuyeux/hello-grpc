package org.feuyeux.grpc.etcd;

import io.grpc.ManagedChannel;
import io.grpc.ManagedChannelBuilder;
import io.grpc.StatusRuntimeException;
import org.feuyeux.grpc.PingGrpc;
import org.feuyeux.grpc.PingOuterClass;

import java.net.URI;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.TimeUnit;
import java.util.logging.Level;
import java.util.logging.Logger;

public class PingClient {
    private static final Logger logger = Logger.getLogger(PingClient.class.getName());
    private static final String ENDPOINT = "http://127.0.0.1:2379";
    private static final String TARGET = "etcd:///pingsvc";

    private final ManagedChannel channel;
    private final PingGrpc.PingBlockingStub blockingStub;

    public PingClient() {
        List<URI> endpoints = new ArrayList<>();
        endpoints.add(URI.create(ENDPOINT));
        this.channel = ManagedChannelBuilder.forTarget(TARGET)
                .nameResolverFactory(
                        EtcdNameResolverProvider
                                .forEndpoints(endpoints)
                )
                .defaultLoadBalancingPolicy("round_robin")
                //.loadBalancerFactory(RoundRobinLoadBalancerFactory.getInstance())
                .usePlaintext()
                .build();
        blockingStub = PingGrpc.newBlockingStub(channel);
    }

    public void shutdown() throws InterruptedException {
        channel.shutdown().awaitTermination(5, TimeUnit.SECONDS);
    }

    public void ping() {
        logger.info("trying to PING ");
        PingOuterClass.PingRequest request = PingOuterClass.PingRequest.newBuilder().setPing("PING").build();
        PingOuterClass.PingResponse response;
        try {
            response = blockingStub.ping(request);
        } catch (StatusRuntimeException e) {
            logger.log(Level.WARNING, "RPC failed: {0}", e.getStatus());
            return;
        }
        logger.info("got response: " + response.getPong());
    }

    /**
     * Greet server. If provided, the first element of {@code args} is the name to use in the
     * greeting.
     */
    public static void main(String[] args) throws Exception {
        PingClient client = new PingClient();
        try {
            while (true) {
                client.ping();
                Thread.sleep(5000L);
            }
        } finally {
            client.shutdown();
        }
    }
}
