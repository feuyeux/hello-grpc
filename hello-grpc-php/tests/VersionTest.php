<?php declare(strict_types=1);
namespace Tests;

use PHPUnit\Framework\TestCase;
use Monolog\Logger;
use Monolog\Handler\StreamHandler;
use Common\Utils\VersionUtils;

require_once __DIR__ . '/../vendor/autoload.php';
require_once __DIR__ . '/../common/utils/VersionUtils.php';

final class VersionTest extends TestCase
{
    public function testGetVersion(): void
    {
        // Create a logger
        $log = new Logger('VersionTest');
        $consoleHandler = new StreamHandler('php://stdout', Logger::INFO);
        $log->pushHandler($consoleHandler);
        
        // Call the getVersion function from VersionUtils
        $version = VersionUtils::getVersion();
        $log->info("gRPC version: $version");
        // Don't echo to avoid "risky test" warning
        // echo "gRPC version: $version\n";
        
        // Test that the version string starts with the expected prefix
        $this->assertStringStartsWith('grpc.version=', $version);
        
        // Test that the version is not empty (beyond the prefix)
        $this->assertGreaterThan(13, strlen($version), 'Version string should be longer than just the prefix');
        
        // Check that it returns a valid version format or "unknown"
        $this->assertMatchesRegularExpression('/^grpc\.version=(\d+\.\d+\.\d+|unknown.*)$/', $version);
    }
}