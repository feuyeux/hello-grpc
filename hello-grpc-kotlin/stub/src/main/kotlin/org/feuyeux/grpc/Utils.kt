package org.feuyeux.grpc

import java.util.Map

object Utils {
    val helloList = listOf("Hello", "Bonjour", "Hola", "こんにちは", "Ciao", "안녕하세요")

    val ansMap: kotlin.collections.Map<String, String> = Map.of(
        "你好", "非常感谢",
        "Hello", "Thank you very much",
        "Bonjour", "Merci beaucoup",
        "Hola", "Muchas Gracias",
        "こんにちは", "どうも ありがとう ございます",
        "Ciao", "Mille Grazie",
        "안녕하세요", "대단히 감사합니다"
    )

    fun match(k:String) :String{
        return ansMap[k].orEmpty()
    }

}
