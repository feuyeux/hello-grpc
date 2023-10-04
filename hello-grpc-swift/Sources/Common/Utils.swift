import Foundation
import Logging

#if compiler(>=5.6)

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    public enum Utils {
        public static let helloList: [String] = ["Hello", "Bonjour", "Hola", "こんにちは", "Ciao", "안녕하세요"]
        public static let ansMap: [String: String] = ["你好": "非常感谢",
                                                      "Hello": "Thank you very much",
                                                      "Bonjour": "Merci beaucoup",
                                                      "Hola": "Muchas Gracias",
                                                      "こんにちは": "どうも ありがとう ございます",
                                                      "Ciao": "Mille Grazie",
                                                      "안녕하세요": "대단히 감사합니다"]
    }
#endif // compiler(>=5.6)
