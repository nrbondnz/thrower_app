import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/camera/live_camera.dart';
import 'package:thrower_app/providers.dart';
import 'package:thrower_app/ui/camera_view.dart';

void main() {
  Future<void> pumpWithCamera(WidgetTester tester, Future<LiveCamera> Function() open) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [liveCameraProvider.overrideWith((ref) => open())],
      child: const MaterialApp(home: Scaffold(body: CameraView())),
    ));
    await tester.pump();
  }

  testWidgets('shows a spinner while the camera starts', (tester) async {
    await pumpWithCamera(tester, () => Completer<LiveCamera>().future);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  const cases = <(CameraFailure, bool)>[
    (CameraFailure.denied, true),
    (CameraFailure.deniedPermanently, false),
    (CameraFailure.restricted, false),
    (CameraFailure.noCamera, false),
    (CameraFailure.unknown, true),
  ];
  for (final (failure, canRetry) in cases) {
    testWidgets('$failure shows its message${canRetry ? ' and a retry button' : ''}', (tester) async {
      await pumpWithCamera(tester, () async => throw CameraStartException(failure));
      expect(find.text(CameraErrorView.messageFor(failure)), findsOneWidget);
      expect(find.text('Try again'), canRetry ? findsOneWidget : findsNothing);
    });
  }

  testWidgets('Try again asks for the camera again', (tester) async {
    var attempts = 0;
    await pumpWithCamera(tester, () async {
      attempts++;
      throw const CameraStartException(CameraFailure.denied);
    });
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump();
    expect(attempts, 2);
  });
}
