using Microsoft.VisualBasic.CompilerServices;
using Grpc.Core;
using NUnit.Framework;
using System;

namespace HelloUT;

public class Tests
{
    [SetUp]
    public void Setup()
    {
    }

    [Test]
    public void TestThanks()
    {
        var hello = Common.Utils.HelloList[1];
        var thanks = Common.Utils.AnsMap[hello];
        Assert.That(thanks, Is.EqualTo("Merci beaucoup"));
    }

    [Test]
    public void TestGetVersion()
    {
        // Get the version string
        var version = Common.Utils.GetVersion();

        // Test that the string starts with the expected prefix
        Assert.That(version, Does.StartWith("grpc.version="));

        // Check that the version is not just the prefix
        Assert.That(version.Length, Is.GreaterThan("grpc.version=".Length));

        // Check that the version matches Grpc.Core.VersionInfo.CurrentVersion
        Assert.That(version, Is.EqualTo($"grpc.version={VersionInfo.CurrentVersion}"));
    }

    [Test]
    public void OutputVersionInfo()
    {
        // Get the version string and output to console
        var version = Common.Utils.GetVersion();
        Console.WriteLine($"Version Info: {version}");

        // Also output the raw VersionInfo.CurrentVersion for comparison
        Console.WriteLine($"Raw gRPC Version: {VersionInfo.CurrentVersion}");

        // This assertion always passes - just to make the test complete
        Assert.Pass($"Version output complete: {version}");
    }
}