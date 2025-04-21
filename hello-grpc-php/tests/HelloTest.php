<?php declare(strict_types=1);
use PHPUnit\Framework\TestCase;
require __DIR__ . '/vendor/autoload.php';

final class HelloTest extends TestCase
{
    public function testUpper(): void
    {
        $log = Logger::getLogger("HelloTest");
        Logger::configure("log4php_config.xml");

        $a1 = "Hello";
        $a2 = strtoupper($a1);
        $log->info("a1=$a1,a2=$a2");
        $this->assertSame($a2, "HELLO");
    }
}
