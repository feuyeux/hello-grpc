using System;
using System.Collections.Generic;
using Grpc.Core;
using Hello;

namespace Common
{
    /// <summary>
    /// Utility functions and constants for the gRPC client and server.
    /// </summary>
    public static class Utils
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

        /// <summary>
        /// Builds a linked list of TalkRequest objects for testing streaming RPCs.
        /// </summary>
        /// <returns>A linked list containing 3 random TalkRequest objects</returns>
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

        /// <summary>
        /// Gets the version information for the gRPC implementation.
        /// </summary>
        /// <returns>Version string</returns>
        public static string GetVersion()
        {
            return $"grpc.version={VersionInfo.CurrentVersion}";
        }
    }
}