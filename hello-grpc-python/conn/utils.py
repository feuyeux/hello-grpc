# encoding: utf-8
from collections import deque
import random
import grpc

from conn.landing_pb2 import TalkRequest

hellos = ["Hello", "Bonjour", "Hola", "こんにちは", "Ciao", "안녕하세요"]

ans = {"你好": "非常感谢",
       "Hello": "Thank you very much",
       "Bonjour": "Merci beaucoup",
       "Hola": "Muchas Gracias",
       "こんにちは": "どうも ありがとう ございます",
       "Ciao": "Mille Grazie",
       "안녕하세요": "대단히 감사합니다"}


def build_link_requests():
    ids = random_ids(5, 3)
    requests = deque()
    for i in range(0, 3):
        request = TalkRequest(data=ids[i], meta="PYTHON")
        requests.appendleft(request)
    return requests


def random_ids(end, n):
    ids = []
    while len(ids) < n:
        req_id = random_id(end)
        if req_id not in ids:
            ids.append(req_id)
    return ids


def random_id(end):
    return str(random.randint(0, end))


def get_version():
    """
    Get the gRPC version string
    """
    return f"grpc.version={grpc.__version__}"
