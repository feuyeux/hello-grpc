package org.feuyeux.grpc.server;

import static org.feuyeux.grpc.Constants.contextKeys;
import static org.feuyeux.grpc.Constants.tracingKeys;

import io.grpc.Context;
import io.grpc.Contexts;
import io.grpc.Metadata;
import io.grpc.ServerCall;
import io.grpc.ServerCallHandler;
import io.grpc.ServerInterceptor;
import lombok.extern.slf4j.Slf4j;

@Slf4j
public class HeaderServerInterceptor implements ServerInterceptor {

  @Override
  public <ReqT, RespT> ServerCall.Listener<ReqT> interceptCall(
      ServerCall<ReqT, RespT> call,
      final Metadata requestHeaders,
      ServerCallHandler<ReqT, RespT> serverCallHandler) {
    Context current = Context.current();
    for (int i = 0; i < tracingKeys.size(); i++) {
      Metadata.Key<String> tracingKey = tracingKeys.get(i);
      String metadata = requestHeaders.get(tracingKey);
      if (metadata != null) {
        Context.Key<String> key = contextKeys.get(i);
        log.info("->T {}:{}", key, metadata);
        current = current.withValue(key, metadata);
      }
    }
    for (String keyName : requestHeaders.keys()) {
      Metadata.Key<String> key = Metadata.Key.of(keyName, Metadata.ASCII_STRING_MARSHALLER);
      String metadata = requestHeaders.get(key);
      log.info("->H {}:{}", key, metadata);
    }
    return Contexts.interceptCall(current, call, requestHeaders, serverCallHandler);
  }
}