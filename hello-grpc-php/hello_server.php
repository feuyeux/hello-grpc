<?php

use Grpc\RpcServer;

require dirname(__FILE__) . '/vendor/autoload.php';
require dirname(__FILE__) . '/LandingService.php';

$port = 9666;
$server = new RpcServer();
$server->addHttp2Port('0.0.0.0:'.$port);
$server->handle(new LandingService());
echo sprintf("Start GRPC Server[%s]\n", $port);
$server->run();