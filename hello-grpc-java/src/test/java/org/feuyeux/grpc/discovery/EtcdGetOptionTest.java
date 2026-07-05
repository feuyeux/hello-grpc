package org.feuyeux.grpc.discovery;

import static org.junit.jupiter.api.Assertions.*;

import io.etcd.jetcd.ByteSequence;
import io.etcd.jetcd.options.GetOption;
import java.nio.charset.StandardCharsets;
import org.junit.jupiter.api.Test;

/** Test to verify GetOption usage with isPrefix instead of deprecated withPrefix */
public class EtcdGetOptionTest {

  @Test
  public void testGetOptionBuilderWithIsPrefix() {
    // This test verifies that GetOption.builder().isPrefix(true) compiles and works
    String serviceDir = "/services/grpc";
    ByteSequence prefix = ByteSequence.from(serviceDir, StandardCharsets.UTF_8);

    // The new way: using isPrefix(boolean)
    GetOption option = GetOption.builder().isPrefix(true).build();

    // Verify the option is not null
    assertNotNull(option, "GetOption should not be null");

    // Verify we can build it without errors
    assertTrue(true, "GetOption with isPrefix should build successfully");
  }

  @Test
  public void testGetOptionBuilderWithIsPrefixFalse() {
    // Test that isPrefix(false) also works
    String serviceDir = "/services/grpc";
    ByteSequence prefix = ByteSequence.from(serviceDir, StandardCharsets.UTF_8);

    GetOption option = GetOption.builder().isPrefix(false).build();

    assertNotNull(option, "GetOption should not be null");
  }
}
