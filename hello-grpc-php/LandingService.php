<?php

use Grpc\ServerCallReader;
use Grpc\ServerCallWriter;
use Grpc\ServerContext;
use Hello\TalkRequest;
use Hello\TalkResponse;
use Hello\TalkResult;
use Ramsey\Uuid\Uuid;

$ans = [
    "你好" => "非常感谢",
    "Hello" => "Thank you very much",
    "Bonjour" => "Merci beaucoup",
    "Hola" => "Muchas Gracias",
    "こんにちは" => "どうも ありがとう ございます",
    "Ciao" => "Mille Grazie",
    "안녕하세요" => "대단히 감사합니다",
];

$hellos = array("Hello", "Bonjour", "Hola", "こんにちは", "Ciao", "안녕하세요");

class LandingService extends Hello\LandingServiceStub
{
    /**
     * Unary RPC
     * @param TalkRequest $request client request
     * @param ServerContext $context server request context
     * @return TalkResponse|null for response data, null if if error occurred
     *     initial metadata (if any) and status (if not ok) should be set to $context
     */
    public function Talk(TalkRequest $request, ServerContext $context): ?TalkResponse
    {
        $data = $request->getData();
        $meta = $request->getMeta();
        echo sprintf("TALK REQUEST: data=%s,meta=%s\n", $data, $meta);
        $clientMetadata = $context->clientMetadata();
        $response = new TalkResponse();
        $response->setStatus(200);
        $talkResult = $this->buildResult($data);
        $response->setResults([$talkResult]);
        return $response;
    }

    /**
     * Server streaming RPC
     * @param TalkRequest $request client request
     * @param ServerCallWriter $writer write response data of \Hello\TalkResponse
     * @param ServerContext $context server request context
     * @return void
     */
    public function TalkOneAnswerMore(TalkRequest $request, ServerCallWriter $writer, ServerContext $context): void
    {
        $data = $request->getData();
        $meta = $request->getMeta();
        echo sprintf("TalkOneAnswerMore REQUEST: data=%s,meta=%s\n", $data, $meta);
        $datas = explode(",", $data);
        for ($i = 0; $i < count($datas); $i++) {
            $response = new TalkResponse();
            $response->setStatus(200);
            $talkResult = $this->buildResult($datas[$i]);
            $response->setResults([$talkResult]);
            $writer->write($response);
        }
        $writer->finish();
    }

    /**
     * Client streaming RPC with random & sleep
     * @param ServerCallReader $reader read client request data of \Hello\TalkRequest
     * @param ServerContext $context server request context
     * @return TalkResponse for response data, null if if error occured
     *     initial metadata (if any) and status (if not ok) should be set to $context
     */
    public function TalkMoreAnswerOne(ServerCallReader $reader, ServerContext $context): ?TalkResponse
    {
        $response = new TalkResponse();
        $response->setStatus(200);
        $talkResults = array();
        $i = 0;
        while ($request = $reader->read()) {
            $data = $request->getData();
            $meta = $request->getMeta();
            echo sprintf("TalkMoreAnswerOne REQUEST: data=%s,meta=%s\n", $data, $meta);
            $talkResult = $this->buildResult($data);
            $talkResults[$i++] = $talkResult;
        }
        $response->setResults($talkResults);
        return $response;
    }

    /**
     * Bidirectional streaming RPC
     * @param ServerCallReader $reader read client request data of \Hello\TalkRequest
     * @param ServerCallWriter $writer write response data of \Hello\TalkResponse
     * @param ServerContext $context server request context
     * @return void
     */
    public function TalkBidirectional(ServerCallReader $reader, ServerCallWriter $writer, ServerContext $context): void
    {
        while ($request = $reader->read()) {
            $data = $request->getData();
            $meta = $request->getMeta();
            echo sprintf("TalkBidirectional REQUEST: data=%s,meta=%s\n", $data, $meta);
            $response = new TalkResponse();
            $response->setStatus(200);
            $talkResult = $this->buildResult($data);
            $response->setResults([$talkResult]);
            $writer->write($response);
        }
        $writer->finish();
    }

    private function parseInt(string $data): int
    {
        return (int)$data;
    }

    private function buildResult(string $data): TalkResult
    {
        global $hellos, $ans;
        $result = new TalkResult();
        $index = $this->parseInt($data);
        $hello = $hellos[$index];
        $result->setId(time());
        $result->setType(Hello\ResultType::OK);
        $kv = $result->getKv();
        $kv["id"] = Uuid::uuid4()->toString();
        $kv["idx"] = $data;
        $answer = $hello . "," . $ans[$hello];
        $kv["data"] = $answer;
        $kv["meta"] = "PHP";
        return $result;
    }
}