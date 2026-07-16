import unittest
from unittest.mock import MagicMock

import grpc

from conn import error_mapper


class FakeRpcError(grpc.RpcError):
    def code(self):
        return grpc.StatusCode.UNAVAILABLE

    def details(self):
        return "backend unavailable"


class ErrorMapperTests(unittest.TestCase):
    def test_set_error_status_preserves_rpc_error(self):
        context = MagicMock()

        error_mapper.set_error_status(context, FakeRpcError(), "request-1")

        context.set_code.assert_called_once_with(grpc.StatusCode.UNAVAILABLE)
        context.set_details.assert_called_once_with("backend unavailable")

    def test_abort_with_error_maps_plain_exception_to_internal(self):
        context = MagicMock()

        error_mapper.abort_with_error(context, ValueError("broken"), "request-2")

        context.abort.assert_called_once_with(grpc.StatusCode.INTERNAL, "broken")


if __name__ == "__main__":
    unittest.main()
