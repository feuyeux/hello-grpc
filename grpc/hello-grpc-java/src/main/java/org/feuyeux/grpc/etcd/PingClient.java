package org.feuyeux.grpc.etcd;

import io.grpc.ManagedChannel;
import io.grpc.ManagedChannelBuilder;
import io.grpc.StatusRuntimeException;
import lombok.extern.slf4j.Slf4j;
import org.feuyeux.grpc.PingGrpc;
import org.feuyeux.grpc.PingOuterClass;

import java.net.URI;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.TimeUnit;

import static org.feuyeux.grpc.common.Connection.PING_TARGET;

@Slf4j
public class PingClient {
    private static final String ENDPOINT = "http://127.0.0.1:2379";

    private final ManagedChannel channel;
    private final PingGrpc.PingBlockingStub blockingStub;

    public PingClient() {
        List<URI> endpoints = new ArrayList<>();
        endpoints.add(URI.create(ENDPOINT));
        this.channel = ManagedChannelBuilder.forTarget(PING_TARGET)
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
        log.info("trying to PING ");
        PingOuterClass.PingRequest request = PingOuterClass.PingRequest.newBuilder().setPing("PING").build();
        PingOuterClass.PingResponse response;
        try {
            response = blockingStub.ping(request);
        } catch (StatusRuntimeException e) {
            log.warn("RPC failed: {}", e.getStatus());
            return;
        }
        log.info("got response: " + response.getPong());
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
