using System;
using System.Collections.Generic;
using Org.Feuyeux.Grpc;

namespace Common;

public class Utils
{
    public static readonly Random HelloRandom = new();

    public static readonly List<string> HelloList = new()
    {
        "Hello", "Bonjour", "Hola", "こんにちは", "Ciao", "안녕하세요"
    };

    public static readonly Dictionary<string, string> AnsMap = new()
    {
        { "你好", "非常感谢" },
        { "Hello", "Thank you very much" },
        { "Bonjour", "Merci beaucoup" },
        { "Hola", "Muchas Gracias" },
        { "こんにちは", "どうも ありがとう ございます" },
        { "Ciao", "Mille Grazie" },
        { "안녕하세요", "대단히 감사합니다" }
    };

    public static LinkedList<TalkRequest> BuildLinkRequests()
    {
        LinkedList<TalkRequest> list = new();
        for (var i = 0; i < 3; ++i)
        {
            var request = new TalkRequest
            {
                Data = HelloRandom.Next(5).ToString(),
                Meta = "C#"
            };
            list.AddFirst(request);
        }
        return list;
    }
}