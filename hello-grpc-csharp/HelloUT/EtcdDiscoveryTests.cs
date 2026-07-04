using NUnit.Framework;
using System;

namespace HelloUT;

public class EtcdDiscoveryTests
{
    [TearDown]
    public void TearDown()
    {
        Environment.SetEnvironmentVariable("GRPC_HELLO_DISCOVERY", null);
    }

    [Test]
    public void IsEtcdDiscovery_DefaultFalse()
    {
        Environment.SetEnvironmentVariable("GRPC_HELLO_DISCOVERY", null);
        Assert.That(Common.EtcdDiscovery.IsEtcdDiscovery(), Is.False);
    }

    [Test]
    public void IsEtcdDiscovery_TrueWhenSet()
    {
        Environment.SetEnvironmentVariable("GRPC_HELLO_DISCOVERY", "etcd");
        Assert.That(Common.EtcdDiscovery.IsEtcdDiscovery(), Is.True);
    }

    [Test]
    public void IsEtcdDiscovery_FalseWhenOtherValue()
    {
        Environment.SetEnvironmentVariable("GRPC_HELLO_DISCOVERY", "dns");
        Assert.That(Common.EtcdDiscovery.IsEtcdDiscovery(), Is.False);
    }
}
