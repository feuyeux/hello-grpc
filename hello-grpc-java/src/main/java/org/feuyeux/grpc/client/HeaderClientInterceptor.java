package org.feuyeux.grpc.client;

import static org.feuyeux.grpc.Constants.contextKeys;
import static org.feuyeux.grpc.Constants.tracingKeys;

import io.grpc.CallOptions;
import io.grpc.Channel;
import io.grpc.ClientCall;
import io.grpc.ClientInterceptor;
import io.grpc.Context.Key;
import io.grpc.ForwardingClientCall;
import io.grpc.ForwardingClientCallListener;
import io.grpc.Metadata;
import io.grpc.MethodDescriptor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class HeaderClientInterceptor implements ClientInterceptor {
  private static final Logger log = LoggerFactory.getLogger("LandingServiceImpl");

  @Override
  public <ReqT, RespT> ClientCall<ReqT, RespT> interceptCall(
      MethodDescriptor<ReqT, RespT> method, CallOptions callOptions, Channel next) {
    return new ForwardingClientCall.SimpleForwardingClientCall<>(
        next.newCall(method, callOptions)) {
      @Override
      public void start(Listener<RespT> responseListener, Metadata headers) {
        for (int i = 0; i < tracingKeys.size(); i++) {
          Key<String> k = contextKeys.get(i);
          if (k != null) {
            String metadata = k.get();
            if (metadata != null) {
              Metadata.Key<String> key = tracingKeys.get(i);
              log.info("<-T {}:{}", key, metadata);
              headers.put(key, metadata);
            }
          }
        }

        super.start(
            new ForwardingClientCallListener.SimpleForwardingClientCallListener<>(
                responseListener) {
              @Override
              public void onHeaders(Metadata headers) {
                log.info("<-H {}", headers);
                super.onHeaders(headers);
              }
            },
            headers);
      }
    };
  }
}
