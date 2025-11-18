# encoding: utf-8
"""
Utility functions for gRPC client and server implementations.

This module provides common utility functions for the Hello gRPC Python implementation,
including functions for building test data, generating random IDs, managing greeting
messages in multiple languages, and retrieving version information.

The module supports all four gRPC communication patterns:
- Unary RPC
- Server streaming RPC
- Client streaming RPC
- Bidirectional streaming RPC

Example:
    Basic usage of utility functions::

        from conn.utils import get_hello_list, build_link_requests, get_version

        # Get greeting messages
        greetings = get_hello_list()
        print(greetings[0])  # Output: "Hello"

        # Build test requests
        requests = build_link_requests()
        
        # Get gRPC version
        version = get_version()
        print(version)  # Output: "grpc.version=1.50.0"

Attributes:
    hellos (list): Greeting messages in multiple languages (English, French, Spanish,
                   Japanese, Italian, Korean).
    ans (dict): Mapping of greetings to their corresponding thank you messages in
                multiple languages.

Author:
    Hello gRPC Team

Version:
    1.0
"""

from collections import deque
import random
import grpc

from conn.landing_pb2 import TalkRequest

# Greeting messages in different languages used for testing gRPC communication
hellos = ["Hello", "Bonjour", "Hola", "こんにちは", "Ciao", "안녕하세요"]

# Mapping of greetings to their corresponding thank you messages
# Used by the server to respond with appropriate thank you messages
ans = {
    "你好": "非常感谢",
    "Hello": "Thank you very much",
    "Bonjour": "Merci beaucoup",
    "Hola": "Muchas Gracias",
    "こんにちは": "どうも ありがとう ございます",
    "Ciao": "Mille Grazie",
    "안녕하세요": "대단히 감사합니다"
}


def get_hello_list():
    """
    Get the list of greeting messages in different languages.
    
    These greetings are used for testing unary and streaming RPC calls across
    different language implementations.
    
    Returns:
        list: A list containing greetings in English, French, Spanish, Japanese,
              Italian, and Korean.
    
    Example:
        >>> greetings = get_hello_list()
        >>> print(greetings[0])
        'Hello'
        >>> print(len(greetings))
        6
    """
    return hellos


def get_answer_map():
    """
    Get the map of greetings to their corresponding thank you messages.
    
    This map is used by the server to respond with appropriate thank you messages
    based on the greeting received from the client. It supports multiple languages
    to demonstrate internationalization in gRPC services.
    
    Returns:
        dict: A dictionary where keys are greeting strings and values are
              corresponding thank you messages in the same language.
    
    Example:
        >>> answers = get_answer_map()
        >>> print(answers["Hello"])
        'Thank you very much'
        >>> print(answers["Bonjour"])
        'Merci beaucoup'
    """
    return ans


def build_link_requests():
    """
    Create a deque of TalkRequest objects for testing streaming RPCs.
    
    This function generates a collection of TalkRequest protocol buffer messages
    with random IDs and Python metadata. The requests are stored in a deque for
    efficient addition and removal from both ends.
    
    Each request contains:
        - data: A random ID string (0-4)
        - meta: The string "PYTHON" identifying the implementation
    
    Returns:
        deque: A deque containing 3 TalkRequest objects with random IDs.
    
    Example:
        >>> requests = build_link_requests()
        >>> len(requests)
        3
        >>> first_request = requests[0]
        >>> print(first_request.meta)
        'PYTHON'
    
    See Also:
        random_ids: Function used to generate random ID strings
        TalkRequest: Protocol buffer message type
    """
    ids = random_ids(5, 3)
    requests = deque()
    for i in range(0, 3):
        request = TalkRequest(data=ids[i], meta="PYTHON")
        requests.appendleft(request)
    return requests


def random_ids(end, n):
    """
    Generate a list of unique random ID strings.
    
    Args:
        end: Maximum value for random IDs (exclusive)
        n: Number of unique IDs to generate
        
    Returns:
        list: List of unique random ID strings
    """
    ids = []
    while len(ids) < n:
        req_id = random_id(end)
        if req_id not in ids:
            ids.append(req_id)
    return ids


def random_id(end):
    """
    Generate a random ID string between 0 and end-1.
    
    Args:
        end: Maximum value (exclusive)
        
    Returns:
        str: Random ID as a string
    """
    return str(random.randint(0, end))


def get_version():
    """
    Get the gRPC version string.
    
    Returns:
        str: Version string in format "grpc.version=X.Y.Z"
    """
    return f"grpc.version={grpc.__version__}"
