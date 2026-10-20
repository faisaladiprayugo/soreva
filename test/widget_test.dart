// Stage 0A spike smoke test. Stage 0B replaces this with real domain tests.
import 'package:flutter_test/flutter_test.dart';
import 'package:soreva/main.dart';

void main() {
  testWidgets('spike app builds', (tester) async {
    await tester.pumpWidget(const SpikeApp());
    expect(find.text('Stage 0A — Capture Spike'), findsOneWidget);
  });
}
