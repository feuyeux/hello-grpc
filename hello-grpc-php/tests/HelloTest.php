<?php declare(strict_types=1);
namespace Tests;

use PHPUnit\Framework\TestCase;
use Monolog\Logger;
use Monolog\Handler\StreamHandler;

require_once __DIR__ . '/../vendor/autoload.php';

final class HelloTest extends TestCase
{
    public function testUpper(): void
    {
        // Create a logger
        $log = new Logger('HelloTest');
        $consoleHandler = new StreamHandler('php://stdout', Logger::INFO);
        $log->pushHandler($consoleHandler);

        $a1 = "Hello";
        $a2 = strtoupper($a1);
        $log->info("a1=$a1,a2=$a2");
        $this->assertSame($a2, "HELLO");
    }
}
