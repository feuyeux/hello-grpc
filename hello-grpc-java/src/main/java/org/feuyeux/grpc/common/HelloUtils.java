package org.feuyeux.grpc.common;

import static java.util.stream.Collectors.toList;

import io.grpc.internal.GrpcUtil;
import java.util.Arrays;
import java.util.LinkedList;
import java.util.List;
import java.util.Map;
import java.util.random.RandomGenerator;
import java.util.stream.IntStream;
import org.feuyeux.grpc.proto.TalkRequest;

/**
 * Utility class providing helper functions for gRPC client and server implementations. This class
 * contains methods for building test data, generating random IDs, and managing greeting messages in
 * multiple languages.
 *
 * <p>All methods in this class are static and the class cannot be instantiated.
 *
 * <p>Example usage:
 *
 * <pre>{@code
 * List<String> greetings = HelloUtils.getHelloList();
 * String randomId = HelloUtils.getRandomId();
 * LinkedList<TalkRequest> requests = HelloUtils.buildLinkRequests();
 * }</pre>
 *
 * @author Hello gRPC Team
 * @version 1.0
 * @since 1.0
 */
public class HelloUtils {

  /** Random number generator for creating random IDs. */
  private static final RandomGenerator random = RandomGenerator.getDefault();

  /**
   * List of greeting messages in multiple languages used for testing gRPC communication. Includes
   * greetings in English, French, Spanish, Japanese, Italian, and Korean.
   */
  private static final List<String> HELLO_LIST =
      Arrays.asList("Hello", "Bonjour", "Hola", "こんにちは", "Ciao", "안녕하세요");

  /**
   * Map of greetings to their corresponding thank you messages in multiple languages. Used by the
   * server to respond with appropriate thank you messages based on the greeting received from the
   * client.
   */
  private static final Map<String, String> ANS_MAP =
      Map.of(
          "你好", "非常感谢",
          "Hello", "Thank you very much",
          "Bonjour", "Merci beaucoup",
          "Hola", "Muchas Gracias",
          "こんにちは", "どうも ありがとう ございます",
          "Ciao", "Mille Grazie",
          "안녕하세요", "대단히 감사합니다");

  /** Private constructor to prevent instantiation of this utility class. */
  private HelloUtils() {
    throw new UnsupportedOperationException("Utility class cannot be instantiated");
  }

  /**
   * Returns an immutable list of greeting messages in different languages. These greetings are used
   * for testing unary and streaming RPC calls.
   *
   * @return an immutable list containing greetings in English, French, Spanish, Japanese, Italian,
   *     and Korean
   */
  public static List<String> getHelloList() {
    return HELLO_LIST;
  }

  /**
   * Returns an immutable map of greetings to their corresponding thank you messages. This map is
   * used by the server to respond with appropriate thank you messages based on the greeting
   * received from the client.
   *
   * @return an immutable map where keys are greetings and values are thank you messages
   */
  public static Map<String, String> getAnswerMap() {
    return ANS_MAP;
  }

  /**
   * Builds a linked list of TalkRequest objects for testing streaming RPCs. Each request contains a
   * random ID and metadata identifying the Java implementation.
   *
   * <p>The method creates 3 TalkRequest objects, each with:
   *
   * <ul>
   *   <li>A random ID between 0 and 4
   *   <li>Metadata set to "JAVA"
   * </ul>
   *
   * @return a LinkedList containing 3 TalkRequest objects with random IDs
   */
  public static LinkedList<TalkRequest> buildLinkRequests() {
    LinkedList<TalkRequest> requests = new LinkedList<>();
    for (int i = 0; i < 3; i++) {
      requests.addFirst(TalkRequest.newBuilder().setMeta("JAVA").setData(getRandomId()).build());
    }
    return requests;
  }

  /**
   * Generates a list of random ID strings.
   *
   * @param max the number of random IDs to generate
   * @return a list of random ID strings, each between 0 and 4
   */
  public static List<String> getRandomIds(int max) {
    return IntStream.range(0, max).mapToObj(i -> getRandomId()).collect(toList());
  }

  /**
   * Generates a random ID string between 0 and 4. This method uses a thread-safe random number
   * generator.
   *
   * @return a string representation of a random integer between 0 and 4 (inclusive)
   */
  public static String getRandomId() {
    return String.valueOf(random.nextInt(5));
  }

  /**
   * Returns the gRPC library version string. This is useful for debugging and ensuring version
   * compatibility across implementations.
   *
   * @return a formatted string containing the gRPC version (e.g., "grpc.version=1.50.0"), or an
   *     empty string if the version cannot be determined
   */
  public static String getVersion() {
    try {
      return String.format("grpc.version=%s", GrpcUtil.IMPLEMENTATION_VERSION);
    } catch (Exception e) {
      return "";
    }
  }
}
