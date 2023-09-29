<?php

use Grpc\ChannelCredentials;
use Hello\LandingServiceClient;
use Hello\TalkRequest;
use Hello\TalkResponse;
use Hello\TalkResult;

require dirname(__FILE__) . '/vendor/autoload.php';

$host = getenv('GRPC_SERVER');
if (empty($host)) {
    $host = 'localhost:9666';
} else {
    $host = $host . ':9666';
}
echo sprintf("Connect to:%s\n", $host);
$client = new LandingServiceClient($host, [
    'credentials' => ChannelCredentials::createInsecure(),
]);

function main()
{
    $request = new TalkRequest();
    $request->setData("0");
    $request->setMeta("PHP");
    talk($request);

    $request->setData("0,1,2");
    talkOneAnswerMore($request);

    talkMoreAnswerOne(buildLinkRequests());
    talkBidirectional(buildLinkRequests());
}

function talk(TalkRequest $request): void
{
    global $client;
    printRequest("[Unary RPC] Talk->", $request);
    list($response, $status) = $client->Talk($request)->wait();
    if (!is_null($response)) {
        printResponse("Talk<-", $response);
    }
}

function talkOneAnswerMore(TalkRequest $request): void
{
    global $client;
    printRequest("[Server streaming RPC] TalkOneAnswerMore->", $request);
    $call = $client->TalkOneAnswerMore($request);
    // an iterator over the server streaming responses
    $responses = $call->responses();
    foreach ($responses as $response) {
        if (!is_null($response)) {
            printResponse("TalkOneAnswerMore<-", $response);
        }
    }
}

function talkMoreAnswerOne(array $talkRequests): void
{
    global $client;
    echo "Client streaming RPC\n";
    $call = $client->TalkMoreAnswerOne();
    $count = count($talkRequests);
    for ($i = 0; $i < $count; ++$i) {
        usleep(rand(1000, 3000));
        printRequest("TalkMoreAnswerOne->", $talkRequests[$i]);
        $call->write($talkRequests[$i]);
    }
    list($response, $status) = $call->wait();
    if (!is_null($response)) {
        printResponse("TalkMoreAnswerOne<-", $response);
    }
}

function talkBidirectional(array $talkRequests): void
{
    global $client;
    echo "Bidirectional streaming RPC\n";
    $call = $client->TalkBidirectional();
    $count = count($talkRequests);
    for ($i = 0; $i < $count; ++$i) {
        usleep(rand(1000, 3000));
        printRequest("TalkBidirectional->", $talkRequests[$i]);
        $call->write($talkRequests[$i]);
    }
    $call->writesDone();
    while ($response = $call->read()) {
        if (!is_null($response)) {
            printResponse("TalkBidirectional<-", $response);
        }
    }
}


/**
 * @return TalkRequest[]
 */
function buildLinkRequests(): iterable
{
    $requests = array();
    for ($i = 0; $i < 3; $i++) {
        $request = new TalkRequest();
        $request->setData(randomId(5));
        $request->setMeta("PHP");
        $requests[$i] = $request;
    }
    return $requests;
}

function randomId(int $num): string
{
    return sprintf("%d", rand(0, $num));
}

/**
 * print request
 * @param string $callName
 * @param TalkRequest $request
 * @return void
 */
function printRequest(string $callName, TalkRequest $request): void
{
    echo sprintf("%s(%s,%s)\n", $callName, $request->getData(), $request->getMeta());
}

function printResponse(string $callName, TalkResponse $response): void
{
    $resultsList = $response->getResults();
    $prefix = $callName . "[" . $response->getStatus() . "]";
    $length = count($resultsList);
    for ($i = 0; $i < $length; $i++) {
        printResult($prefix, $resultsList[$i]);
    }
}

function printResult(string $prefix, TalkResult $result): void
{
    $kv = $result->getKv();
    echo sprintf("%s: %d [%s %s %s,%s:%s]\n",
        $prefix, $result->getId(), $kv["meta"], $result->getType(), $kv["id"], $kv["idx"], $kv["data"]);
}

main();