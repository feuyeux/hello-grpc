package org.feuyeux.grpc;

import static java.util.stream.Collectors.toList;

import java.util.List;
import java.util.random.RandomGenerator;
import java.util.stream.IntStream;

public class HelloUtils {

  private static final RandomGenerator random = RandomGenerator.getDefault();

  public static List<String> getRandomIds(int max) {
    return IntStream.range(0, max)
        .mapToObj(i -> getRandomId())
        .collect(toList());
  }

  public static String getRandomId() {
    return String.valueOf(random.nextInt(5));
  }
}
