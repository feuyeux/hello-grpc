# encoding: utf-8
import logging
import random

import time

from conn import connection, utils, landing_pb2_grpc,landing_pb2

logger = logging.getLogger('grpc-client')
logger.setLevel(logging.INFO)
console = logging.StreamHandler()
console.setLevel(logging.INFO)
formatter = logging.Formatter('%(asctime)s [%(levelname)s] - %(message)s')
console.setFormatter(formatter)
logger.addHandler(console)


def talk(stub):
    request = landing_pb2.TalkRequest(data="0", meta="PYTHON")
    logger.info("Talk data:%s,meta:%s", request.data, request.meta)
    metadata = (("k1", "v1"),
                ("k2", "v2"),)
    response = stub.Talk(request=request, metadata=metadata)
    print_response("Talk", response)


def talk_one_answer_more(stub):
    request = landing_pb2.TalkRequest(data="0,1,2", meta="PYTHON")
    logger.info("TalkOneAnswerMore data:%s,meta:%s", request.data, request.meta)
    metadata = (("k1", "v1"),
                ("k2", "v2"),)
    responses = stub.TalkOneAnswerMore(request=request, metadata=metadata)
    for response in responses:
        print_response("TalkOneAnswerMore", response)


def talk_more_answer_one(stub):
    request_iterator = generate_request("TalkMoreAnswerOne")
    metadata = (("k1", "v1"),
                ("k2", "v2"),)
    response_summary = stub.TalkMoreAnswerOne(request_iterator=request_iterator, metadata=metadata)
    print_response("TalkMoreAnswerOne", response_summary)


def talk_bidirectional(stub):
    request_iterator = generate_request("TalkBidirectional")
    metadata = (("k1", "v1"),
                ("k2", "v2"),)
    responses = stub.TalkBidirectional(request_iterator=request_iterator, metadata=metadata)
    for response in responses:
        print_response("TalkBidirectional", response)


def generate_request(method_name):
    requests = utils.build_link_requests()
    while len(requests) > 0:
        request = requests.pop()
        logger.info("%s data:%s,meta:%s", method_name, request.data, request.meta)
        yield request
        time.sleep(random.uniform(0.5, 1.5))


def print_response(method_name, response):
    for result in response.results:
        kv = result.kv
        logger.info("%s [%d] %d [%s %s %s,%s:%s]", method_name,
                    response.status, result.id, kv["meta"], result.type, kv["id"], kv["idx"], kv["data"])


def run():
    channel = connection.build_channel()
    stub = landing_pb2_grpc.LandingServiceStub(channel)
    logger.info("Unary RPC")
    talk(stub)
    logger.info("Server streaming RPC")
    talk_one_answer_more(stub)
    logger.info("Client streaming RPC")
    talk_more_answer_one(stub)
    logger.info("Bidirectional streaming RPC")
    talk_bidirectional(stub)


if __name__ == '__main__':
    run()
