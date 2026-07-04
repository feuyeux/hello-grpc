<?php declare(strict_types=1);
namespace Tests;

use PHPUnit\Framework\TestCase;

require_once __DIR__ . '/../vendor/autoload.php';
require_once __DIR__ . '/../conn/EtcdDiscovery.php';

final class EtcdDiscoveryTest extends TestCase
{
    private string $origDiscovery;

    protected function setUp(): void
    {
        $this->origDiscovery = getenv('GRPC_HELLO_DISCOVERY') ?: '';
        putenv('GRPC_HELLO_DISCOVERY');
    }

    protected function tearDown(): void
    {
        if ($this->origDiscovery !== '') {
            putenv("GRPC_HELLO_DISCOVERY={$this->origDiscovery}");
        }
    }

    public function testIsEtcdDiscoveryDefaultFalse(): void
    {
        $this->assertFalse(\EtcdDiscovery::isEtcdDiscovery());
    }

    public function testIsEtcdDiscoveryTrueWhenSet(): void
    {
        putenv('GRPC_HELLO_DISCOVERY=etcd');
        $this->assertTrue(\EtcdDiscovery::isEtcdDiscovery());
    }

    public function testIsEtcdDiscoveryFalseWhenOtherValue(): void
    {
        putenv('GRPC_HELLO_DISCOVERY=dns');
        $this->assertFalse(\EtcdDiscovery::isEtcdDiscovery());
    }

    public function testConstants(): void
    {
        $this->assertSame('hello-grpc', \EtcdDiscovery::SVC_DISC_NAME);
        $this->assertSame('/etcd/hello-grpc', \EtcdDiscovery::ETCD_KEY);
        $this->assertSame(5, \EtcdDiscovery::DEFAULT_TTL);
    }
}
