package org.feuyeux.grpc;

import lombok.extern.slf4j.Slf4j;
import org.junit.Test;

@Slf4j
public class RandomTest {

  @Test
  public void test() {
    for (int i = 0; i < 20; i++) {
      log.info(
          HelloUtils.getRandomId());
    }
  }
}
