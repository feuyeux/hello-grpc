# Generated by the gRPC Python protocol compiler plugin. DO NOT EDIT!
"""Client and server classes corresponding to protobuf-defined services."""
import grpc
import warnings

import conn.landing_pb2 as landing__pb2

GRPC_GENERATED_VERSION = '1.66.2'
GRPC_VERSION = grpc.__version__
_version_not_supported = False

try:
    from grpc._utilities import first_version_is_lower
    _version_not_supported = first_version_is_lower(GRPC_VERSION, GRPC_GENERATED_VERSION)
except ImportError:
    _version_not_supported = True

if _version_not_supported:
    raise RuntimeError(
        f'The grpc package installed is at version {GRPC_VERSION},'
        + f' but the generated code in conn.landing_pb2_grpc.py depends on'
        + f' grpcio>={GRPC_GENERATED_VERSION}.'
        + f' Please upgrade your grpc module to grpcio>={GRPC_GENERATED_VERSION}'
        + f' or downgrade your generated code using grpcio-tools<={GRPC_VERSION}.'
    )


class LandingServiceStub(object):
    """Missing associated documentation comment in .proto file."""

    def __init__(self, channel):
        """Constructor.

        Args:
            channel: A grpc.Channel.
        """
        self.Talk = channel.unary_unary(
                '/org.feuyeux.grpc.LandingService/Talk',
                request_serializer=landing__pb2.TalkRequest.SerializeToString,
                response_deserializer=landing__pb2.TalkResponse.FromString,
                _registered_method=True)
        self.TalkOneAnswerMore = channel.unary_stream(
                '/org.feuyeux.grpc.LandingService/TalkOneAnswerMore',
                request_serializer=landing__pb2.TalkRequest.SerializeToString,
                response_deserializer=landing__pb2.TalkResponse.FromString,
                _registered_method=True)
        self.TalkMoreAnswerOne = channel.stream_unary(
                '/org.feuyeux.grpc.LandingService/TalkMoreAnswerOne',
                request_serializer=landing__pb2.TalkRequest.SerializeToString,
                response_deserializer=landing__pb2.TalkResponse.FromString,
                _registered_method=True)
        self.TalkBidirectional = channel.stream_stream(
                '/org.feuyeux.grpc.LandingService/TalkBidirectional',
                request_serializer=landing__pb2.TalkRequest.SerializeToString,
                response_deserializer=landing__pb2.TalkResponse.FromString,
                _registered_method=True)


class LandingServiceServicer(object):
    """Missing associated documentation comment in .proto file."""

    def Talk(self, request, context):
        """Unary RPC
        """
        context.set_code(grpc.StatusCode.UNIMPLEMENTED)
        context.set_details('Method not implemented!')
        raise NotImplementedError('Method not implemented!')

    def TalkOneAnswerMore(self, request, context):
        """Server streaming RPC
        """
        context.set_code(grpc.StatusCode.UNIMPLEMENTED)
        context.set_details('Method not implemented!')
        raise NotImplementedError('Method not implemented!')

    def TalkMoreAnswerOne(self, request_iterator, context):
        """Client streaming RPC with random & sleep
        """
        context.set_code(grpc.StatusCode.UNIMPLEMENTED)
        context.set_details('Method not implemented!')
        raise NotImplementedError('Method not implemented!')

    def TalkBidirectional(self, request_iterator, context):
        """Bidirectional streaming RPC
        """
        context.set_code(grpc.StatusCode.UNIMPLEMENTED)
        context.set_details('Method not implemented!')
        raise NotImplementedError('Method not implemented!')


def add_LandingServiceServicer_to_server(servicer, server):
    rpc_method_handlers = {
            'Talk': grpc.unary_unary_rpc_method_handler(
                    servicer.Talk,
                    request_deserializer=landing__pb2.TalkRequest.FromString,
                    response_serializer=landing__pb2.TalkResponse.SerializeToString,
            ),
            'TalkOneAnswerMore': grpc.unary_stream_rpc_method_handler(
                    servicer.TalkOneAnswerMore,
                    request_deserializer=landing__pb2.TalkRequest.FromString,
                    response_serializer=landing__pb2.TalkResponse.SerializeToString,
            ),
            'TalkMoreAnswerOne': grpc.stream_unary_rpc_method_handler(
                    servicer.TalkMoreAnswerOne,
                    request_deserializer=landing__pb2.TalkRequest.FromString,
                    response_serializer=landing__pb2.TalkResponse.SerializeToString,
            ),
            'TalkBidirectional': grpc.stream_stream_rpc_method_handler(
                    servicer.TalkBidirectional,
                    request_deserializer=landing__pb2.TalkRequest.FromString,
                    response_serializer=landing__pb2.TalkResponse.SerializeToString,
            ),
    }
    generic_handler = grpc.method_handlers_generic_handler(
            'org.feuyeux.grpc.LandingService', rpc_method_handlers)
    server.add_generic_rpc_handlers((generic_handler,))
    server.add_registered_method_handlers('org.feuyeux.grpc.LandingService', rpc_method_handlers)


 # This class is part of an EXPERIMENTAL API.
class LandingService(object):
    """Missing associated documentation comment in .proto file."""

    @staticmethod
    def Talk(request,
            target,
            options=(),
            channel_credentials=None,
            call_credentials=None,
            insecure=False,
            compression=None,
            wait_for_ready=None,
            timeout=None,
            metadata=None):
        return grpc.experimental.unary_unary(
            request,
            target,
            '/org.feuyeux.grpc.LandingService/Talk',
            landing__pb2.TalkRequest.SerializeToString,
            landing__pb2.TalkResponse.FromString,
            options,
            channel_credentials,
            insecure,
            call_credentials,
            compression,
            wait_for_ready,
            timeout,
            metadata,
            _registered_method=True)

    @staticmethod
    def TalkOneAnswerMore(request,
            target,
            options=(),
            channel_credentials=None,
            call_credentials=None,
            insecure=False,
            compression=None,
            wait_for_ready=None,
            timeout=None,
            metadata=None):
        return grpc.experimental.unary_stream(
            request,
            target,
            '/org.feuyeux.grpc.LandingService/TalkOneAnswerMore',
            landing__pb2.TalkRequest.SerializeToString,
            landing__pb2.TalkResponse.FromString,
            options,
            channel_credentials,
            insecure,
            call_credentials,
            compression,
            wait_for_ready,
            timeout,
            metadata,
            _registered_method=True)

    @staticmethod
    def TalkMoreAnswerOne(request_iterator,
            target,
            options=(),
            channel_credentials=None,
            call_credentials=None,
            insecure=False,
            compression=None,
            wait_for_ready=None,
            timeout=None,
            metadata=None):
        return grpc.experimental.stream_unary(
            request_iterator,
            target,
            '/org.feuyeux.grpc.LandingService/TalkMoreAnswerOne',
            landing__pb2.TalkRequest.SerializeToString,
            landing__pb2.TalkResponse.FromString,
            options,
            channel_credentials,
            insecure,
            call_credentials,
            compression,
            wait_for_ready,
            timeout,
            metadata,
            _registered_method=True)

    @staticmethod
    def TalkBidirectional(request_iterator,
            target,
            options=(),
            channel_credentials=None,
            call_credentials=None,
            insecure=False,
            compression=None,
            wait_for_ready=None,
            timeout=None,
            metadata=None):
        return grpc.experimental.stream_stream(
            request_iterator,
            target,
            '/org.feuyeux.grpc.LandingService/TalkBidirectional',
            landing__pb2.TalkRequest.SerializeToString,
            landing__pb2.TalkResponse.FromString,
            options,
            channel_credentials,
            insecure,
            call_credentials,
            compression,
            wait_for_ready,
            timeout,
            metadata,
            _registered_method=True)