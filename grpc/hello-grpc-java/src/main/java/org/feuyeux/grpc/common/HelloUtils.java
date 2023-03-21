package org.feuyeux.grpc.common;

import static java.util.stream.Collectors.toList;

import java.util.Arrays;
import java.util.LinkedList;
import java.util.List;
import java.util.Map;
import java.util.random.RandomGenerator;
import java.util.stream.IntStream;
import org.feuyeux.grpc.proto.TalkRequest;

public class HelloUtils {

  private static final RandomGenerator random = RandomGenerator.getDefault();
  private static final List<String> HELLO_LIST = Arrays.asList("Hello", "Bonjour", "Hola", "こんにちは",
      "Ciao",
      "안녕하세요");
  private static final Map<String, String> ANS_MAP = Map.of(
      "你好", "非常感谢",
      "Hello", "Thank you very much",
      "Bonjour", "Merci beaucoup",
      "Hola", "Muchas Gracias",
      "こんにちは", "どうも ありがとう ございます",
      "Ciao", "Mille Grazie",
      "안녕하세요", "대단히 감사합니다"
  );

  public static List<String> getHelloList() {
    return HELLO_LIST;
  }

  public static Map<String, String> getAnswerMap() {
    return ANS_MAP;
  }

  public static LinkedList<TalkRequest> buildLinkRequests() {
    LinkedList<TalkRequest> requests = new LinkedList<>();
    for (int i = 0; i < 3; i++) {
      requests.addFirst(TalkRequest.newBuilder()
          .setMeta("JAVA")
          .setData(HelloUtils.getRandomId())
          .build());
    }
    return requests;
  }

  public static List<String> getRandomIds(int max) {
    return IntStream.range(0, max)
        .mapToObj(i -> getRandomId())
        .collect(toList());
  }

  public static String getRandomId() {
    return String.valueOf(random.nextInt(5));
  }
}
