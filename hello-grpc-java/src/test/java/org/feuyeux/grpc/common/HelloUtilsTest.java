package org.feuyeux.grpc.common;

import static org.junit.jupiter.api.Assertions.*;

import io.grpc.internal.GrpcUtil;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

public class HelloUtilsTest {

  @Test
  @DisplayName("测试 getVersion 方法返回正确的 gRPC 版本字符串")
  public void testGetVersion() {
    // 获取 getVersion 方法的返回值
    String version = HelloUtils.getVersion();

    // 打印输出 getVersion 的结果
    System.out.println("HelloUtils.getVersion(): " + version);

    // 测试返回的字符串具有正确的格式前缀
    assertTrue(version.startsWith("grpc.version="), "版本字符串应该以 'grpc.version=' 开头");

    // 测试版本字符串长度超过前缀长度（确保版本号部分不为空）
    assertTrue(version.length() > 13, "版本字符串应该包含实际版本号");

    // 验证版本号与 GrpcUtil.IMPLEMENTATION_VERSION 一致
    String expectedVersion = "grpc.version=" + GrpcUtil.IMPLEMENTATION_VERSION;
    assertEquals(expectedVersion, version, "版本应该与 GrpcUtil.IMPLEMENTATION_VERSION 一致");
  }
}
