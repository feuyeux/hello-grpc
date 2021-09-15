package org.feuyeux.grpc;

import io.grpc.Context;
import io.grpc.Metadata;
import java.util.ArrayList;
import java.util.List;

public class Constants {

  public static final Metadata.Key<String> x_request_id = Metadata.Key.of("x-request-id",
      Metadata.ASCII_STRING_MARSHALLER);
  public static final Metadata.Key<String> x_b3_traceid = Metadata.Key.of("x-b3-traceid",
      Metadata.ASCII_STRING_MARSHALLER);
  public static final Metadata.Key<String> x_b3_spanid = Metadata.Key.of("x-b3-spanid",
      Metadata.ASCII_STRING_MARSHALLER);
  public static final Metadata.Key<String> x_b3_parentspanid = Metadata.Key.of("x-b3-parentspanid",
      Metadata.ASCII_STRING_MARSHALLER);
  public static final Metadata.Key<String> x_b3_sampled = Metadata.Key.of("x-b3-sampled",
      Metadata.ASCII_STRING_MARSHALLER);
  public static final Metadata.Key<String> x_b3_flags = Metadata.Key.of("x-b3-flags",
      Metadata.ASCII_STRING_MARSHALLER);
  public static final Metadata.Key<String> x_ot_span_context = Metadata.Key.of("x-ot-span-context",
      Metadata.ASCII_STRING_MARSHALLER);


  public static final Context.Key<String> context_x_request_id = Context.key("x-request-id");
  public static final Context.Key<String> context_x_b3_traceid = Context.key("x-b3-traceid");
  public static final Context.Key<String> context_x_b3_spanid = Context.key("x-b3-spanid");
  public static final Context.Key<String> context_x_b3_parentspanid = Context.key(
      "x-b3-parentspanid");
  public static final Context.Key<String> context_x_b3_sampled = Context.key("x-b3-sampled");
  public static final Context.Key<String> context_x_b3_flags = Context.key("x-b3-flags");
  public static final Context.Key<String> context_x_ot_span_context = Context.key(
      "x-ot-span-context");

  public static final List<Metadata.Key<String>> tracingKeys;
  public static final List<Context.Key<String>> contextKeys;

  static {
    tracingKeys = new ArrayList<>();
    tracingKeys.add(x_request_id);
    tracingKeys.add(x_b3_traceid);
    tracingKeys.add(x_b3_spanid);
    tracingKeys.add(x_b3_parentspanid);
    tracingKeys.add(x_b3_sampled);
    tracingKeys.add(x_b3_flags);
    tracingKeys.add(x_ot_span_context);

    contextKeys = new ArrayList<>();
    contextKeys.add(context_x_request_id);
    contextKeys.add(context_x_b3_traceid);
    contextKeys.add(context_x_b3_spanid);
    contextKeys.add(context_x_b3_parentspanid);
    contextKeys.add(context_x_b3_sampled);
    contextKeys.add(context_x_b3_flags);
    contextKeys.add(context_x_ot_span_context);
  }
}
