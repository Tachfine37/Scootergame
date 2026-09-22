import 'package:ca_passe/data/game_preferences.dart';
import 'package:ca_passe/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('welcome, start, pause and resume work at narrow mobile size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 690);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final prefs = GamePreferences(await SharedPreferences.getInstance());
    await tester.pumpWidget(DeliveryApp(preferences: prefs));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Encore\nun colis ?'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('C’est parti'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('À BORD'), findsOneWidget);
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    expect(find.text('On souffle ?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Reprendre'));
    await tester.pump();
    expect(find.text('On souffle ?'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test('record survives loading a new preferences instance', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await SharedPreferences.getInstance();
    final prefs = GamePreferences(storage);
    await prefs.saveRecord(18);
    await prefs.saveRecord(4);
    expect(GamePreferences(storage).record, 18);
    await prefs.setHaptics(false);
    expect(GamePreferences(storage).haptics, false);
  });
}

