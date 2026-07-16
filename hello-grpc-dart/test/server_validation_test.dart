import 'package:grpc/grpc.dart';
import 'package:hello_grpc_dart/server.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

void main() {
  test('LandingService rejects invalid data with INVALID_ARGUMENT', () {
    final service = LandingService(logger: Logger('test'));

    for (final invalid in ['', 'not-a-number', '-1', '99']) {
      expect(
        () => service.createResponse(invalid),
        throwsA(
          isA<GrpcError>().having(
            (error) => error.code,
            'code',
            StatusCode.invalidArgument,
          ),
        ),
      );
    }
  });
}
