package org.feuyeux.grpc;

import org.feuyeux.grpc.common.HelloUtils;
import org.junit.Test;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class RandomTest {
  private static final Logger log = LoggerFactory.getLogger("RandomTest");

  @Test
  public void test() {
    for (int i = 0; i < 20; i++) {
      log.info(HelloUtils.getRandomId());
    }
  }
}
