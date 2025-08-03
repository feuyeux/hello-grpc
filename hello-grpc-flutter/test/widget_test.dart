// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:hello_grpc_flutter/main.dart';

void main() {
  testWidgets('gRPC app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const HelloApp());

    // Verify that our app has the configuration card
    expect(find.textContaining('gRPC Server Configuration'), findsOneWidget);
    expect(find.text('Host'), findsOneWidget);

    // Verify that the ASK button exists
    expect(find.text('ASK gRPC Server From Flutter'), findsOneWidget);
  });
}
