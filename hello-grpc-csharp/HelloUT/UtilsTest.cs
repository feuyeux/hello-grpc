using Microsoft.VisualBasic.CompilerServices;

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
}