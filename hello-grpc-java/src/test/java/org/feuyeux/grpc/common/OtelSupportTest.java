package org.feuyeux.grpc.common;

import static org.junit.jupiter.api.Assertions.*;

import io.opentelemetry.api.OpenTelemetry;
import io.opentelemetry.api.common.AttributeKey;
import io.opentelemetry.api.common.AttributeType;
import io.opentelemetry.semconv.ServiceAttributes;
import org.junit.jupiter.api.Test;

/** Test to verify OpenTelemetry ServiceAttributes migration from deprecated ResourceAttributes */
public class OtelSupportTest {

  @Test
  public void testServiceNameKeyUsesServiceAttributes() {
    // Verify that serviceNameKey() returns the correct AttributeKey
    AttributeKey<String> serviceNameKey = OtelSupport.serviceNameKey();

    assertNotNull(serviceNameKey, "Service name key should not be null");
    assertEquals(
        ServiceAttributes.SERVICE_NAME,
        serviceNameKey,
        "serviceNameKey() should return ServiceAttributes.SERVICE_NAME");
    assertEquals(
        "service.name",
        serviceNameKey.getKey(),
        "Service name key should have the correct string key");
  }

  @Test
  public void testInitOtelWithoutEnv() {
    // When GRPC_HELLO_OTEL is not set, should return noop
    OpenTelemetry openTelemetry = OtelSupport.initOtel("test-service");

    assertNotNull(openTelemetry, "OpenTelemetry instance should not be null");
    // Noop instance should still be usable
    assertNotNull(openTelemetry.getTracer("test"), "Should return a tracer");
  }

  @Test
  public void testOtelEnabledReturnsFalseByDefault() {
    // Without GRPC_HELLO_OTEL=Y in this JVM, otelEnabled() should return
    // false. surefire forks a new JVM by default, so this only holds when
    // the parent process did not export GRPC_HELLO_OTEL=Y. If your shell
    // has GRPC_HELLO_OTEL=Y exported, run with
    //   mvn test -DGRPC_HELLO_OTEL_UNSET=Y
    // or unset it before invoking Maven.
    boolean enabled = OtelSupport.otelEnabled();

    // The prior version of this assertion was a tautology
    // (assertFalse(enabled || true, ...)) that always failed; the bug
    // hid the fact that the env var was leaking into surefire.
    boolean envLeaked = "Y".equals(System.getenv("GRPC_HELLO_OTEL"));
    assertEquals(envLeaked, enabled, "otelEnabled() must reflect GRPC_HELLO_OTEL exactly");
  }

  @Test
  public void testServiceAttributesImportAvailable() {
    // Verify ServiceAttributes class is available and has SERVICE_NAME
    AttributeKey<String> serviceName = ServiceAttributes.SERVICE_NAME;

    assertNotNull(serviceName, "ServiceAttributes.SERVICE_NAME should be available");
    assertEquals("service.name", serviceName.getKey(), "SERVICE_NAME should have correct key");
    // otel 1.43 changed AttributeKey.getType() from Class<T> to the
    // AttributeType enum; verify the new contract.
    assertEquals(
        AttributeType.STRING,
        serviceName.getType(),
        "SERVICE_NAME should be of STRING AttributeType");
  }
}
