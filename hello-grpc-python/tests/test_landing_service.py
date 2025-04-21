import unittest
import uuid
from unittest.mock import MagicMock, patch

import grpc
import grpc_testing

from conn import landing_pb2, landing_pb2_grpc
from server.protoServer import LandingServiceServer, build_result


class TestLandingServiceServer(unittest.TestCase):
    """Unit tests for the Python LandingService gRPC implementation."""

    def setUp(self):
        """Set up test environment before each test."""
        # Create a server with no next service (standalone)
        self.servicer = LandingServiceServer(None)
        
        # Create a test server with our service
        self.test_server = grpc_testing.server_from_dictionary(
            {landing_pb2.DESCRIPTOR.services_by_name['LandingService']: self.servicer},
            grpc_testing.strict_real_time()
        )

    def test_talk_unary(self):
        """Test the Unary RPC 'Talk' method."""
        # Create a request
        request = landing_pb2.TalkRequest(data="1", meta="PYTHON_TEST")
        
        # Invoke the method
        method = self.test_server.invoke_unary_unary(
            method_descriptor=(landing_pb2.DESCRIPTOR
                              .services_by_name['LandingService']
                              .methods_by_name['Talk']),
            invocation_metadata={},
            request=request, 
            timeout=None
        )
        
        # Wait for response
        response, metadata, code, details = method.termination()
        
        # Validate the response
        self.assertEqual(grpc.StatusCode.OK, code)
        self.assertEqual(200, response.status)
        self.assertEqual(1, len(response.results))
        
        result = response.results[0]
        self.assertEqual("1", result.kv["idx"])
        self.assertEqual("PYTHON", result.kv["meta"])
        self.assertIn("id", result.kv)
        self.assertIn("data", result.kv)

    def test_talk_server_streaming(self):
        """Test the Server Streaming RPC 'TalkOneAnswerMore' method."""
        # Create a request with comma-separated values
        request = landing_pb2.TalkRequest(data="1,2", meta="PYTHON_TEST")
        
        # Invoke the method
        method = self.test_server.invoke_unary_stream(
            method_descriptor=(landing_pb2.DESCRIPTOR
                              .services_by_name['LandingService']
                              .methods_by_name['TalkOneAnswerMore']),
            invocation_metadata={},
            request=request,
            timeout=None
        )
        
        # Collect responses
        responses = []
        for response in method:
            responses.append(response)
        
        # Validate the responses
        self.assertEqual(2, len(responses))
        
        # Check each response
        for i, response in enumerate(responses):
            self.assertEqual(200, response.status)
            self.assertEqual(1, len(response.results))
            
            result = response.results[0]
            # Index should be the right value from the comma-separated input
            expected_idx = request.data.split(",")[i]
            self.assertEqual(expected_idx, result.kv["idx"])
            self.assertEqual("PYTHON", result.kv["meta"])
            self.assertIn("id", result.kv)
            self.assertIn("data", result.kv)

    def test_talk_client_streaming(self):
        """Test the Client Streaming RPC 'TalkMoreAnswerOne' method."""
        # Create the requests
        requests = [
            landing_pb2.TalkRequest(data="1", meta="PYTHON_TEST"),
            landing_pb2.TalkRequest(data="2", meta="PYTHON_TEST"),
            landing_pb2.TalkRequest(data="3", meta="PYTHON_TEST")
        ]
        
        # Invoke the method
        method = self.test_server.invoke_stream_unary(
            method_descriptor=(landing_pb2.DESCRIPTOR
                              .services_by_name['LandingService']
                              .methods_by_name['TalkMoreAnswerOne']),
            invocation_metadata={},
            timeout=None
        )
        
        # Send all requests
        for request in requests:
            method.send_request(request)
        method.requests_closed()
        
        # Wait for the response
        response, metadata, code, details = method.termination()
        
        # Validate the response
        self.assertEqual(grpc.StatusCode.OK, code)
        self.assertEqual(200, response.status)
        self.assertEqual(len(requests), len(response.results))
        
        # Check that all request indices are present in the results
        idx_values = set()
        for result in response.results:
            idx_values.add(result.kv["idx"])
            self.assertEqual("PYTHON", result.kv["meta"])
            self.assertIn("id", result.kv)
            self.assertIn("data", result.kv)
            
        # Verify all requests were processed
        for request in requests:
            self.assertIn(request.data, idx_values)

    def test_talk_bidirectional(self):
        """Test the Bidirectional Streaming RPC 'TalkBidirectional' method."""
        # Create the requests
        requests = [
            landing_pb2.TalkRequest(data="1", meta="PYTHON_TEST"),
            landing_pb2.TalkRequest(data="2", meta="PYTHON_TEST")
        ]
        
        # Invoke the method
        method = self.test_server.invoke_stream_stream(
            method_descriptor=(landing_pb2.DESCRIPTOR
                              .services_by_name['LandingService']
                              .methods_by_name['TalkBidirectional']),
            invocation_metadata={},
            timeout=None
        )
        
        # Send all requests
        for request in requests:
            method.send_request(request)
        method.requests_closed()
        
        # Collect responses
        responses = []
        for i in range(len(requests)):
            responses.append(method.take_response())
        
        # Validate the responses
        self.assertEqual(len(requests), len(responses))
        
        # Check each response corresponds to a request
        for i, response in enumerate(responses):
            self.assertEqual(200, response.status)
            self.assertEqual(1, len(response.results))
            
            result = response.results[0]
            # Verify the idx corresponds to the request
            self.assertEqual(requests[i].data, result.kv["idx"])
            self.assertEqual("PYTHON", result.kv["meta"])
            self.assertIn("id", result.kv)
            self.assertIn("data", result.kv)

    def test_build_result(self):
        """Test the build_result function."""
        # Test with a valid index
        result = build_result("1")
        
        # Validate the result
        self.assertIsNotNone(result)
        self.assertEqual(landing_pb2.OK, result.type)
        self.assertIn("id", result.kv)
        self.assertIn("idx", result.kv)
        self.assertIn("data", result.kv)
        self.assertEqual("1", result.kv["idx"])
        self.assertEqual("PYTHON", result.kv["meta"])
        
    def test_next_service_proxying(self):
        """Test that requests are correctly proxied to the next service."""
        # Create a mock next service
        mock_next_service = MagicMock()
        mock_response = landing_pb2.TalkResponse(status=200)
        mock_next_service.Talk.return_value = mock_response
        
        # Create a servicer with the mock next service
        servicer = LandingServiceServer(mock_next_service)
        
        # Create a mock context
        mock_context = MagicMock()
        metadata = [('key1', 'value1'), ('x-request-id', 'test-id')]
        mock_context.invocation_metadata.return_value = metadata
        
        # Create a request
        request = landing_pb2.TalkRequest(data="1", meta="PYTHON_TEST")
        
        # Call the method
        response = servicer.Talk(request, mock_context)
        
        # Verify the next service was called with the right arguments
        mock_next_service.Talk.assert_called_once()
        call_args = mock_next_service.Talk.call_args
        self.assertEqual(request, call_args[1]['request'])
        
        # Verify the response from the next service was returned
        self.assertEqual(mock_response, response)


if __name__ == '__main__':
    unittest.main()